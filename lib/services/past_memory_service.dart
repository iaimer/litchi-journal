import '../models/diary_document.dart';
import '../models/memory_entry.dart';
import '../services/api_client.dart';
import '../services/markdown_parser.dart';

class PastMemoryService {
  final ApiClient _apiClient;

  /// 缓存：key = 'YYYY-MM'，value = 该月有内容的日期列表（已解析的 DiaryDocument）
  final Map<String, _CachedMonth> _monthCache = {};

  /// 缓存：key = 'YYYY-MM-DD'，value = MemoryEntry（已计算的卡片数据）
  final Map<String, MemoryEntry> _entryCache = {};

  PastMemoryService(this._apiClient);

  // ── 公开方法 ──

  /// 获取「今天曾经发生过」的候选记忆。
  /// 候选顺序：去年同月同日 → 上个月同日 → 7 天前。
  /// 返回第一个真实有内容的条目，或 null。
  Future<MemoryEntry?> getTodayHistory() async {
    final now = DateTime.now();
    final candidates = <DateTime>[
      _safeDate(now.year - 1, now.month, now.day),
      _safeDate(now.year, now.month - 1, now.day),
      now.subtract(const Duration(days: 7)),
    ];

    for (final candidate in candidates) {
      if (candidate.isAfter(now)) continue;
      if (_isSameDay(candidate, now)) continue;
      if (_entryCache.containsKey(_dateKey(candidate))) {
        final cached = _entryCache[_dateKey(candidate)]!;
        if (cached.hasAnyContent) return cached;
        continue;
      }
      final entry = await _loadMemoryEntry(candidate);
      if (entry != null && entry.hasAnyContent) return entry;
    }
    return null;
  }

  /// 从最近 2 个月有内容的日期中随机抽取一条记忆。
  /// [excludeDateKeys] 为已显示过的日期 key（'YYYY-MM-DD'），避免重复。
  Future<MemoryEntry?> getRandomMemory({Set<String>? excludeDateKeys}) async {
    final now = DateTime.now();
    final candidates = <DateTime>[];

    // 收集最近 2 个月的有内容日期
    for (var offset = 0; offset >= -1; offset--) {
      final targetMonth = DateTime(now.year, now.month + offset, 1);
      final monthKey = _monthKey(targetMonth);

      if (_monthCache.containsKey(monthKey)) {
        candidates.addAll(_monthCache[monthKey]!.datesWithContent);
      } else {
        await _loadMonth(targetMonth);
        if (_monthCache.containsKey(monthKey)) {
          candidates.addAll(_monthCache[monthKey]!.datesWithContent);
        }
      }
    }

    // 过滤今天和已排除的日期
    final available = candidates
        .where(
          (d) =>
              !_isSameDay(d, now) &&
              (excludeDateKeys == null ||
                  !excludeDateKeys.contains(_dateKey(d))),
        )
        .toList();

    if (available.isEmpty) return null;

    // 随机抽取（使用当前时间戳种子）
    available.shuffle();
    final picked = available.first;

    // 尝试从缓存或加载
    if (_entryCache.containsKey(_dateKey(picked))) {
      return _entryCache[_dateKey(picked)];
    }
    return _loadMemoryEntry(picked);
  }

  // ── 内部方法 ──

  Future<MemoryEntry?> _loadMemoryEntry(DateTime date) async {
    try {
      final diary = await _apiClient.getDiary(date);
      if (diary == null || diary.raw.isEmpty) return null;
      final document = const MarkdownParser().parse(diary.raw);
      final entry = _buildMemoryEntry(date, document);
      _entryCache[_dateKey(date)] = entry;
      return entry;
    } catch (_) {
      return null;
    }
  }

  MemoryEntry _buildMemoryEntry(DateTime date, DiaryDocument document) {
    final imageNames = <String>[];
    String? joyText;
    String? growthText;
    String? coachSummary;

    for (final section in document.sections) {
      switch (section) {
        case MediaSection():
          imageNames.addAll(_parseWikiLinks(section));
        case HappinessSection():
          joyText ??= _firstTimelineText(section);
        case ReviewSection():
          growthText ??= _firstTimelineText(section);
        case QuickNoteSection():
          growthText ??= _firstTimelineTextFromNotes(section);
        case CoachSection():
          coachSummary ??= _firstRealMarkdownText(section);
        default:
          break;
      }
    }

    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final hasAny =
        imageNames.isNotEmpty ||
        joyText != null ||
        growthText != null ||
        coachSummary != null;

    return MemoryEntry(
      date: date,
      displayDate: '${date.month}月${date.day}日',
      weekday: '星期${weekdays[date.weekday - 1]}',
      imageNames: imageNames,
      imageCount: imageNames.length,
      joyText: joyText,
      growthText: growthText,
      coachSummary: hasAny ? coachSummary : null,
      hasAnyContent: hasAny,
    );
  }

  Future<void> _loadMonth(DateTime month) async {
    final key = _monthKey(month);
    if (_monthCache.containsKey(key)) return;

    try {
      final result = await _apiClient.fetchHistoryMonth(
        month.year,
        month.month,
      );
      final datesWithContent = <DateTime>[];
      for (final day in result.diaries) {
        if (day.hasContent) {
          final parts = day.date.split('-');
          if (parts.length == 3) {
            final d = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            datesWithContent.add(d);
          }
        }
      }
      _monthCache[key] = _CachedMonth(datesWithContent: datesWithContent);
    } catch (_) {
      _monthCache[key] = _CachedMonth(datesWithContent: []);
    }
  }

  // ── 辅助 ──

  /// 安全构造日期，处理月底/闰年溢出。
  DateTime _safeDate(int year, int month, int day) {
    // 先用原始值构造，如果 day 被自动调整说明溢出了
    final raw = DateTime(year, month, day);
    if (raw.day != day) {
      // 溢出：使用该月最后一天
      return DateTime(year, month + 1, 0);
    }
    return raw;
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String? _firstTimelineText(DiarySection section) {
    for (final content in section.contents) {
      if (content is TimelineContent && _isRealContent(content.text)) {
        return _cleanForCard(content.text);
      }
    }
    return null;
  }

  static String? _firstTimelineTextFromNotes(QuickNoteSection section) {
    for (final note in section.notes) {
      if (_isRealContent(note.content)) {
        return _cleanForCard(note.content);
      }
    }
    return null;
  }

  static String? _firstRealMarkdownText(DiarySection section) {
    for (final content in section.contents) {
      if (content is MarkdownContent) {
        final text = content.text.trim();
        if (text.isNotEmpty && !text.startsWith('<!--') && text != '-') {
          return _truncate(text, 100);
        }
      }
    }
    return null;
  }

  static List<String> _parseWikiLinks(MediaSection section) {
    final names = <String>[];
    final pattern = RegExp(
      r'!\[\[([^\]\\]+\.(?:jpg|jpeg|png|gif|webp|heic|heif))\]\]',
      caseSensitive: false,
    );
    for (final content in section.contents) {
      if (content is MarkdownContent) {
        for (final match in pattern.allMatches(content.text)) {
          final name = match.group(1);
          if (name != null) names.add(name);
        }
      }
    }
    return names;
  }

  static bool _isRealContent(String text) {
    final trimmed = text.trim();
    return trimmed.isNotEmpty &&
        trimmed != '内容 #标签' &&
        trimmed != '-' &&
        !trimmed.startsWith('<!--');
  }

  static String _cleanForCard(String text) {
    // 去掉时间前缀 **HH:mm**
    var cleaned = text.replaceFirst(RegExp(r'^\*\*\d{2}:\d{2}\*\*\s*'), '');
    // 去掉行首 bullet
    cleaned = cleaned.replaceFirst(RegExp(r'^-\s+'), '');
    // 截断
    return _truncate(cleaned, 80);
  }

  static String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}…';
  }
}

class _CachedMonth {
  final List<DateTime> datesWithContent;
  const _CachedMonth({required this.datesWithContent});
}
