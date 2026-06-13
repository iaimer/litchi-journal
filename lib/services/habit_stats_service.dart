import 'dart:ui';

import '../models/diary_document.dart';
import '../models/habit_settings.dart';
import '../models/habit_stats.dart';
import '../models/habit_visual_config.dart';
import '../models/history_month_result.dart';
import '../services/api_client.dart';
import '../services/concurrent.dart';
import '../services/markdown_parser.dart';

/// 习惯统计服务。只读，不修改任何 Markdown。
///
/// 分阶段加载 + 静态缓存，优化真机打开速度：
/// - 阶段 1：[loadRecent7] 优先加载最近 7 天
/// - 阶段 2：[loadRecent30] 后台加载剩余 23 天，复用阶段 1 缓存
/// - 静态缓存让 tab 切换回来无需重新请求
class HabitStatsService {
  final ApiClient _apiClient;

  /// 单日记录缓存：key = 'YYYY-MM-DD'，静态跨实例复用
  static final Map<String, HabitDayRecord> _dayCache = {};

  /// history month 结果缓存：key = 'YYYY-MM'
  static final Map<String, HistoryMonthResult> _historyMonthCache = {};

  /// 最近 7 天统计（loadRecent7 填充，loadRecent30 更新）
  HabitStats? _cachedStats;
  String? _cachedActiveKeySignature;

  /// 最近 30 天日期列表（loadRecent7 填充）
  List<DateTime>? _recent30Dates;

  HabitStatsService(this._apiClient);

  /// 重置实例级缓存，确保下次加载重新构建全部统计。
  void resetInstanceCache() {
    _cachedStats = null;
    _cachedActiveKeySignature = null;
    _recent30Dates = null;
  }

  String get _cacheNamespace => identityHashCode(_apiClient).toString();

  String _dayCacheKey(DateTime date) => '$_cacheNamespace:${_dateKey(date)}';

  String _monthCacheKey(String monthKey) => '$_cacheNamespace:$monthKey';

  String _activeKeySignature(
    List<String>? activeHabitKeys, {
    HabitSettings? habitSettings,
  }) {
    if (activeHabitKeys == null) return '*';
    final keys = activeHabitKeys.join('|');
    if (habitSettings == null) return keys;
    // 包含视觉配置签名，使名称/图标/颜色变更触发缓存失效
    final visual = activeHabitKeys
        .map(
          (k) =>
              '${habitSettings.displayNameFor(k)}|${habitSettings.iconFor(k)}|${habitSettings.colorFor(k)}',
        )
        .join('||');
    return '$keys||$visual';
  }

  // ── 公开方法：分阶段加载 ──

  /// 阶段 1：优先加载最近 7 天。
  /// 返回部分 HabitStats（30 天字段为空），UI 先显示反馈卡 + 节奏谱。
  /// [activeHabitKeys] 可选，用于过滤只统计活跃习惯。null 表示统计全部 5 个。
  /// [habitSettings] 可选，用于自定义显示名称/图标/颜色。
  Future<HabitStats> loadRecent7({
    List<String>? activeHabitKeys,
    HabitSettings? habitSettings,
  }) async {
    final activeSignature = _activeKeySignature(
      activeHabitKeys,
      habitSettings: habitSettings,
    );

    // 如果有完整缓存（30 天已加载），直接返回
    if (_cachedStats != null &&
        _cachedStats!.days30.isNotEmpty &&
        _cachedActiveKeySignature == activeSignature) {
      return _cachedStats!;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 最近 7 天日期
    final recent7 = <DateTime>[];
    for (var i = 6; i >= 0; i--) {
      recent7.add(today.subtract(Duration(days: i)));
    }

    // 最近 30 天日期（保存下来给阶段 2 用）
    final recent30 = <DateTime>[];
    for (var i = 29; i >= 0; i--) {
      recent30.add(today.subtract(Duration(days: i)));
    }
    _recent30Dates = recent30;

    // 获取 30 天涉及的月份 history（缓存命中则跳过网络请求）
    final existingDates = await _loadHistoryMonths(recent30);

    // 并发加载最近 7 天
    final records = await mapWithConcurrency<HabitDayRecord, DateTime>(
      items: recent7,
      concurrency: 4,
      mapper: (d) => _getOrLoadDay(d, existingDates),
    );
    final dayRecords = records.where((r) => r.date != DateTime(0)).toList();
    if (dayRecords.length != recent7.length) {
      // 补全失败的情况
      final loaded = dayRecords.map((r) => _dateKey(r.date)).toSet();
      for (final d in recent7) {
        if (!loaded.contains(_dateKey(d))) {
          dayRecords.add(_emptyDayRecord(d));
        }
      }
    }
    dayRecords.sort((a, b) => a.date.compareTo(b.date));

    final items = _buildItemStats(
      dayRecords,
      [],
      activeHabitKeys: activeHabitKeys,
      habitSettings: habitSettings,
    );

    final (summary, suggestion) = _buildFeedback(dayRecords, items);
    final feedbackText = summary.isNotEmpty
        ? (suggestion.isNotEmpty ? '$summary\n$suggestion' : summary)
        : (suggestion.isNotEmpty ? suggestion : '这周还没有太多习惯记录。先从照顾今天开始。');

    final stats = HabitStats(
      recentDays: dayRecords,
      monthDays: const [],
      days30: const [],
      items: items,
      overallRate: _calcOverallRate(dayRecords),
      feedbackText: feedbackText,
      feedbackSummary: summary,
      feedbackSuggestion: suggestion,
    );
    _cachedStats = stats;
    _cachedActiveKeySignature = activeSignature;
    return stats;
  }

  /// 阶段 2：后台加载剩余 23 天，更新完整统计。
  /// 调用前必须已调用 [loadRecent7]。
  /// [activeHabitKeys] 可选，用于过滤只统计活跃习惯。
  /// [habitSettings] 可选，用于自定义显示名称/图标/颜色。
  Future<HabitStats> loadRecent30({
    List<String>? activeHabitKeys,
    HabitSettings? habitSettings,
  }) async {
    final activeSignature = _activeKeySignature(
      activeHabitKeys,
      habitSettings: habitSettings,
    );
    final stats7 = _cachedStats;
    final all30Dates = _recent30Dates;
    if (stats7 == null || all30Dates == null) {
      // 未调用 loadRecent7，fallback
      return loadStats(
        activeHabitKeys: activeHabitKeys,
        habitSettings: habitSettings,
      );
    }

    // 找出未缓存的日期
    final missing = all30Dates
        .where((d) => !_dayCache.containsKey(_dayCacheKey(d)))
        .toList();

    final existingDates = await _loadHistoryMonths(all30Dates);

    if (missing.isNotEmpty) {
      await mapWithConcurrency<HabitDayRecord, DateTime>(
        items: missing,
        concurrency: 4,
        mapper: (d) => _getOrLoadDay(d, existingDates),
      );
    }

    // 组装完整 30 天
    final days30 = <HabitDayRecord>[];
    for (final d in all30Dates) {
      final key = _dayCacheKey(d);
      days30.add(_dayCache[key] ?? _emptyDayRecord(d));
    }

    final now = DateTime.now();
    final monthDays = days30
        .where((r) => r.date.year == now.year && r.date.month == now.month)
        .toList();

    // 复用已缓存的 7 天 records
    final dayRecords7 = stats7.recentDays;

    // 重新计算完整 items
    final items = _buildItemStats(
      dayRecords7,
      days30,
      activeHabitKeys: activeHabitKeys,
      habitSettings: habitSettings,
    );

    final (summary, suggestion) = _buildFeedback(dayRecords7, items);
    final feedbackText = summary.isNotEmpty
        ? (suggestion.isNotEmpty ? '$summary\n$suggestion' : summary)
        : (suggestion.isNotEmpty ? suggestion : '这周还没有太多习惯记录。先从照顾今天开始。');

    final stats = HabitStats(
      recentDays: dayRecords7,
      monthDays: monthDays,
      days30: days30,
      items: items,
      overallRate: _calcOverallRate(dayRecords7),
      feedbackText: feedbackText,
      feedbackSummary: summary,
      feedbackSuggestion: suggestion,
    );
    _cachedStats = stats;
    _cachedActiveKeySignature = activeSignature;
    return stats;
  }

  /// 一次性加载全部统计（保留向后兼容，内部调用分阶段方法）。
  /// [activeHabitKeys] 可选，用于过滤只统计活跃习惯。
  /// [habitSettings] 可选，用于自定义显示名称/图标/颜色。
  Future<HabitStats> loadStats({
    List<String>? activeHabitKeys,
    HabitSettings? habitSettings,
  }) async {
    // 先加载 7 天，然后加载 30 天
    await loadRecent7(
      activeHabitKeys: activeHabitKeys,
      habitSettings: habitSettings,
    );
    return loadRecent30(
      activeHabitKeys: activeHabitKeys,
      habitSettings: habitSettings,
    );
  }

  // ── 缓存管理 ──

  /// 清除所有静态缓存（例如下拉刷新时）。
  static void clearCache() {
    _dayCache.clear();
    _historyMonthCache.clear();
  }

  /// 只清除单日缓存，保留 history month 缓存。
  static void clearDayCache() {
    _dayCache.clear();
  }

  // ── 数据加载 ──

  /// 加载 30 天涉及的所有月份 history（带缓存）。
  Future<Set<DateTime>> _loadHistoryMonths(List<DateTime> dates) async {
    final monthKeys = <String>{};
    for (final d in dates) {
      monthKeys.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }

    final existingDates = <DateTime>{};
    for (final mk in monthKeys) {
      try {
        HistoryMonthResult result;
        final cacheKey = _monthCacheKey(mk);
        if (_historyMonthCache.containsKey(cacheKey)) {
          result = _historyMonthCache[cacheKey]!;
        } else {
          final parts = mk.split('-');
          result = await _apiClient.fetchHistoryMonth(
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
          _historyMonthCache[cacheKey] = result;
        }
        for (final d in result.diaries) {
          if (d.exists || d.hasContent) {
            existingDates.add(_parseDate(d.date));
          }
        }
      } catch (_) {
        // 某个月份获取失败，不影响其他
      }
    }
    return existingDates;
  }

  Future<HabitDayRecord> _getOrLoadDay(
    DateTime d,
    Set<DateTime> existingDates,
  ) async {
    final key = _dayCacheKey(d);
    if (_dayCache.containsKey(key)) return _dayCache[key]!;
    if (!existingDates.contains(d)) {
      final empty = _emptyDayRecord(d);
      _dayCache[key] = empty;
      return empty;
    }
    try {
      final record = await _loadDayRecord(d);
      _dayCache[key] = record;
      return record;
    } catch (_) {
      final empty = _emptyDayRecord(d);
      _dayCache[key] = empty;
      return empty;
    }
  }

  Future<HabitDayRecord> _loadDayRecord(DateTime date) async {
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
  }

  // ── 统计计算 ──

  List<HabitItemStats> _buildItemStats(
    List<HabitDayRecord> days7,
    List<HabitDayRecord> days30, {
    List<String>? activeHabitKeys,
    HabitSettings? habitSettings,
  }) {
    final has30 = days30.isNotEmpty;

    // 按活跃状态过滤
    final filteredKeys = activeHabitKeys != null
        ? _habitKeys.where((k) => activeHabitKeys.contains(k)).toList()
        : _habitKeys.toList();

    final settings = habitSettings ?? HabitSettings.defaults;

    return filteredKeys.map((key) {
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
      var streakStart = days7.lastIndexWhere((day) => day.hasDiary);
      if (streakStart == -1) streakStart = days7.length - 1;
      for (var i = streakStart; i >= 0; i--) {
        if (_isCompleted(getter(days7[i]), type)) {
          streak7++;
        } else {
          break;
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

      // 30 天数据（如果有）
      List<int> reversed30 = const [];
      var completed30 = 0;
      var completionRate30 = 0.0;
      var longestStreak30 = 0;

      if (has30) {
        final values30 = <int>[];
        for (var i = days30.length - 1; i >= 0; i--) {
          final v = getter(days30[i]);
          values30.add(v);
          if (_isCompleted(v, type)) completed30++;
        }
        reversed30 = values30.reversed.toList();

        var longest = 0;
        var currentRun = 0;
        for (var i = days30.length - 1; i >= 0; i--) {
          if (_isCompleted(getter(days30[i]), type)) {
            currentRun++;
            if (currentRun > longest) longest = currentRun;
          } else {
            currentRun = 0;
          }
        }
        longestStreak30 = longest;
        completionRate30 = days30.isNotEmpty ? completed30 / days30.length : 0;
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
        displayName: settings.displayNameFor(key),
        icon: settings.iconFor(key),
        color: Color(settings.colorFor(key)),
        recent30Values: reversed30,
        completedDays30: completed30,
        completionRate30: completionRate30,
        longestStreak30: longestStreak30,
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
    List<HabitDayRecord> days,
    List<HabitItemStats> items,
  ) {
    final hasAny = days.any((d) => d.hasDiary && d.completedCount > 0);
    if (!hasAny) {
      return ('', '先选一个最容易的小习惯照顾起来就很好。');
    }

    HabitItemStats? best;
    for (final item in items) {
      if (item.completedDays > 0 &&
          (best == null || item.completedDays > best.completedDays)) {
        best = item;
      }
    }

    HabitItemStats? improvement;
    for (final item in items) {
      if (item.completedDays >= 0 &&
          (improvement == null ||
              item.completedDays < improvement.completedDays)) {
        improvement = item;
      }
    }

    final rate = _calcOverallRate(days);

    if (rate >= 0.8) {
      return ('这周你把自己照顾得挺稳定。', '接下来只要保持这个轻轻的节奏就好。');
    }

    if (rate <= 0.3) {
      return ('', '这周节奏有点松散也没关系，先选一个最容易的小习惯重新开始。');
    }

    String summary = '';
    if (best != null) {
      summary = '这周你最稳定的是「${best.displayName}」。';
    }

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

  static const _habitKeys = [
    'water',
    'steps',
    'reading',
    'language',
    'supplements',
  ];

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
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
