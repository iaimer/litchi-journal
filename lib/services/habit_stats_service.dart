import '../models/diary_document.dart';
import '../models/habit_stats.dart';
import '../models/habit_visual_config.dart';
import '../services/api_client.dart';
import '../services/markdown_parser.dart';

/// 习惯统计服务。只读，不修改任何 Markdown。
class HabitStatsService {
  final ApiClient _apiClient;

  /// 日记录缓存：key = 'YYYY-MM-DD'
  final Map<String, HabitDayRecord> _dayCache = {};

  HabitStatsService(this._apiClient);

  // ── 公开方法 ──

  /// 加载习惯页所需全部统计数据。
  Future<HabitStats> loadStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 最近 7 天
    final recent7 = <DateTime>[];
    for (var i = 6; i >= 0; i--) {
      recent7.add(today.subtract(Duration(days: i)));
    }

    // 最近 30 天
    final recent30 = <DateTime>[];
    for (var i = 29; i >= 0; i--) {
      recent30.add(today.subtract(Duration(days: i)));
    }

    // 收集 30 天涉及的月份，获取 history
    final monthKeys = <String>{};
    for (final d in recent30) {
      monthKeys.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }

    final existingDates = <DateTime>{};
    for (final mk in monthKeys) {
      try {
        final parts = mk.split('-');
        final result = await _apiClient.fetchHistoryMonth(
            int.parse(parts[0]), int.parse(parts[1]));
        for (final d in result.diaries) {
          if (d.exists || d.hasContent) {
            existingDates.add(_parseDate(d.date));
          }
        }
      } catch (_) {
        // 某个月份获取失败，继续处理其他月份
      }
    }

    // 加载最近 7 天数据
    final dayRecords = <HabitDayRecord>[];
    for (final d in recent7) {
      dayRecords.add(await _getOrLoadDay(d, existingDates));
    }

    // 加载最近 30 天数据
    final days30 = <HabitDayRecord>[];
    for (final d in recent30) {
      days30.add(await _getOrLoadDay(d, existingDates));
    }

    // 当月有记录的日期统计（保留兼容）
    final monthDays = days30
        .where(
            (r) => r.date.year == now.year && r.date.month == now.month)
        .toList();

    // 按习惯维度聚合
    final items = _buildItemStats(dayRecords, days30);
    final overallRate = _calcOverallRate(dayRecords);

    // 反馈文案
    final (summary, suggestion) = _buildFeedback(dayRecords, items);
    final feedbackText = summary.isNotEmpty
        ? (suggestion.isNotEmpty ? '$summary\n$suggestion' : summary)
        : (suggestion.isNotEmpty
            ? suggestion
            : '这周还没有太多习惯记录。先从照顾今天开始。');

    return HabitStats(
      recentDays: dayRecords,
      monthDays: monthDays,
      days30: days30,
      items: items,
      overallRate: overallRate,
      feedbackText: feedbackText,
      feedbackSummary: summary,
      feedbackSuggestion: suggestion,
    );
  }

  // ── 数据加载 ──

  Future<HabitDayRecord> _getOrLoadDay(
      DateTime d, Set<DateTime> existingDates) async {
    final key = _dateKey(d);
    if (_dayCache.containsKey(key)) return _dayCache[key]!;
    if (!existingDates.contains(d)) {
      final empty = _emptyDayRecord(d);
      _dayCache[key] = empty;
      return empty;
    }
    final record = await _loadDayRecord(d);
    _dayCache[key] = record;
    return record;
  }

  Future<HabitDayRecord> _loadDayRecord(DateTime date) async {
    try {
      final diary = await _apiClient.getDiary(date);
      if (diary == null || diary.raw.isEmpty) {
        return _emptyDayRecord(date);
      }

      final document = const MarkdownParser().parse(diary.raw);
      HabitSection? habitSection;
      for (final section in document.sections) {
        if (section is HabitSection) {
          habitSection = section;
          break;
        }
      }

      if (habitSection == null) {
        return _emptyDayRecord(date);
      }

      final status = HabitStatus.fromHabitSection(habitSection);

      const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      return HabitDayRecord(
        date: date,
        weekday: '星期${weekdays[date.weekday - 1]}',
        hasDiary: true,
        waterMl: status.water,
        steps: status.steps,
        readingDone: status.reading,
        languageDone: status.language,
        supplementDone: status.supplements,
      );
    } catch (_) {
      return _emptyDayRecord(date);
    }
  }

  // ── 统计计算 ──

  List<HabitItemStats> _buildItemStats(
      List<HabitDayRecord> days7, List<HabitDayRecord> days30) {
    return _habitKeys.map((key) {
      final config = HabitVisualConfig.of(key);
      final type = _habitTypes[key]!;
      final getter = _habitGetters[key]!;

      final values7 = <int>[];
      var completed7 = 0;
      for (var i = days7.length - 1; i >= 0; i--) {
        final v = getter(days7[i]);
        values7.add(v);
        if (_isCompleted(v, type)) completed7++;
      }
      final reversed7 = values7.reversed.toList();

      // 7天当前连续
      var streak7 = 0;
      for (var i = days7.length - 1; i >= 0; i--) {
        if (_isCompleted(getter(days7[i]), type)) {
          streak7++;
        } else {
          break;
        }
      }

      // 30天数据
      final values30 = <int>[];
      var completed30 = 0;
      for (var i = days30.length - 1; i >= 0; i--) {
        final v = getter(days30[i]);
        values30.add(v);
        if (_isCompleted(v, type)) completed30++;
      }
      final reversed30 = values30.reversed.toList();

      // 30天最长连续
      var longest30 = 0;
      var currentRun = 0;
      for (var i = days30.length - 1; i >= 0; i--) {
        if (_isCompleted(getter(days30[i]), type)) {
          currentRun++;
          if (currentRun > longest30) longest30 = currentRun;
        } else {
          currentRun = 0;
        }
      }

      var avg = 0.0;
      if (reversed7.isNotEmpty) {
        var sum = 0;
        for (final v in reversed7) {
          sum += v;
        }
        avg = sum / reversed7.length;
      }

      return HabitItemStats(
        key: key,
        title: config.displayName,
        group: config.group,
        type: type,
        recent7Values: reversed7,
        completedDays: completed7,
        totalDays: days7.length,
        averageValue: avg,
        currentStreak: streak7,
        displayName: config.displayName,
        icon: config.icon,
        color: config.color,
        recent30Values: reversed30,
        completedDays30: completed30,
        completionRate30: days30.isNotEmpty ? completed30 / days30.length : 0,
        longestStreak30: longest30,
      );
    }).toList();
  }

  static bool _isCompleted(int value, HabitStatType type) {
    return type == HabitStatType.boolean ? value == 1 : value > 0;
  }

  double _calcOverallRate(List<HabitDayRecord> days) {
    if (days.isEmpty) return 0;
    var totalCompleted = 0;
    const totalPossible = HabitDayRecord.totalCount;
    for (final d in days) {
      totalCompleted += d.completedCount;
    }
    return totalCompleted / (days.length * totalPossible);
  }

  // ── 反馈文案（分离总结和建议）──

  (String summary, String suggestion) _buildFeedback(
      List<HabitDayRecord> days, List<HabitItemStats> items) {
    final hasAny = days.any((d) => d.hasDiary && d.completedCount > 0);
    if (!hasAny) {
      return ('', '先选一个最容易的小习惯照顾起来就很好。');
    }

    // 找到完成最多的习惯
    HabitItemStats? best;
    for (final item in items) {
      if (item.completedDays > 0 &&
          (best == null || item.completedDays > best.completedDays)) {
        best = item;
      }
    }

    // 找到完成最少但可统计的习惯
    HabitItemStats? improvement;
    for (final item in items) {
      if (item.completedDays >= 0 &&
          (improvement == null ||
              item.completedDays < improvement.completedDays)) {
        improvement = item;
      }
    }

    final rate = _calcOverallRate(days);

    // 整体节奏很好
    if (rate >= 0.8) {
      return (
        '这周你把自己照顾得挺稳定。',
        '接下来只要保持这个轻轻的节奏就好。'
      );
    }

    // 整体节奏松散
    if (rate <= 0.3) {
      return (
        '',
        '这周节奏有点松散也没关系，先选一个最容易的小习惯重新开始。'
      );
    }

    // 总结
    String summary = '';
    if (best != null) {
      summary = '这周你最稳定的是「${best.displayName}」。';
    }

    // 建议
    String suggestion = '';
    if (improvement != null &&
        improvement.key != best?.key &&
        improvement.completedDays <= 3) {
      if (improvement.key == 'water') {
        suggestion = '「${improvement.displayName}」有些少，明天可以先从上午一杯水开始。';
      } else if (improvement.key == 'supplements') {
        suggestion = '「${improvement.displayName}」有些起伏，可以先把它放在早餐旁边，降低记起来的难度。';
      } else {
        suggestion = '「${improvement.displayName}」有些起伏，可以从一次很小的行动开始。';
      }
    }

    return (summary, suggestion);
  }

  // ── 空数据 ──

  HabitDayRecord _emptyDayRecord(DateTime date) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return HabitDayRecord(
      date: date,
      weekday: '星期${weekdays[date.weekday - 1]}',
      hasDiary: false,
      waterMl: 0,
      steps: 0,
      readingDone: false,
      languageDone: false,
      supplementDone: false,
    );
  }

  // ── 习惯键定义 ──

  static const _habitKeys = ['water', 'steps', 'reading', 'language', 'supplements'];

  static final _habitTypes = {
    'water': HabitStatType.numeric,
    'steps': HabitStatType.numeric,
    'reading': HabitStatType.boolean,
    'language': HabitStatType.boolean,
    'supplements': HabitStatType.boolean,
  };

  static final _habitGetters = {
    'water': (HabitDayRecord r) => r.waterMl,
    'steps': (HabitDayRecord r) => r.steps,
    'reading': (HabitDayRecord r) => r.readingDone ? 1 : 0,
    'language': (HabitDayRecord r) => r.languageDone ? 1 : 0,
    'supplements': (HabitDayRecord r) => r.supplementDone ? 1 : 0,
  };

  // ── 辅助 ──

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('-');
    return DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}
