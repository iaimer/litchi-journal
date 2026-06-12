import '../models/diary_document.dart';
import '../models/habit_stats.dart';
import '../models/history_month_result.dart';
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

    // 最近 7 天（不含今天，包含今天共 7 天）
    final recent7 = <DateTime>[];
    for (var i = 6; i >= 0; i--) {
      recent7.add(today.subtract(Duration(days: i)));
    }

    // 获取当月有记录的日期
    HistoryMonthResult monthResult;
    try {
      monthResult = await _apiClient.fetchHistoryMonth(now.year, now.month);
    } catch (_) {
      return _emptyStats(recent7);
    }

    final existingDates = monthResult.diaries
        .where((d) => d.exists || d.hasContent)
        .map((d) => _parseDate(d.date))
        .toSet();

    // 对最近 7 天中有记录的日期加载日记
    final List<HabitDayRecord> dayRecords = [];
    for (final d in recent7) {
      final key = _dateKey(d);
      if (_dayCache.containsKey(key)) {
        dayRecords.add(_dayCache[key]!);
        continue;
      }
      if (existingDates.contains(d)) {
        final record = await _loadDayRecord(d);
        _dayCache[key] = record;
        dayRecords.add(record);
      } else {
        final empty = _emptyDayRecord(d);
        _dayCache[key] = empty;
        dayRecords.add(empty);
      }
    }

    // 当月有记录的日期统计（用于热力图）
    final monthDays = <HabitDayRecord>[];
    for (final d in existingDates) {
      if (_dayCache.containsKey(_dateKey(d))) {
        monthDays.add(_dayCache[_dateKey(d)]!);
      } else {
        final record = await _loadDayRecord(d);
        _dayCache[_dateKey(d)] = record;
        monthDays.add(record);
      }
    }

    // 按习惯维度聚合
    final items = _buildItemStats(dayRecords);
    final overallRate = _calcOverallRate(dayRecords);
    final feedbackText = _buildFeedback(dayRecords, items);

    return HabitStats(
      recentDays: dayRecords,
      monthDays: monthDays,
      items: items,
      overallRate: overallRate,
      feedbackText: feedbackText,
    );
  }

  // ── 数据加载 ──

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

  List<HabitItemStats> _buildItemStats(List<HabitDayRecord> days) {
    return [
      _buildNumericItem('water', '饮水', HabitGroup.body, days,
          (d) => d.waterMl),
      _buildNumericItem('steps', '运动', HabitGroup.body, days,
          (d) => d.steps),
      _buildBooleanItem(
          'reading', '亲子共读', HabitGroup.growth, days, (d) => d.readingDone),
      _buildBooleanItem(
          'language', '学语言', HabitGroup.growth, days, (d) => d.languageDone),
      _buildBooleanItem('supplements', '鱼油 / 植物甾醇', HabitGroup.body, days,
          (d) => d.supplementDone),
    ];
  }

  HabitItemStats _buildNumericItem(
    String key,
    String title,
    HabitGroup group,
    List<HabitDayRecord> days,
    int Function(HabitDayRecord) getter,
  ) {
    final values = <int>[];
    var completed = 0;

    for (var i = days.length - 1; i >= 0; i--) {
      final v = getter(days[i]);
      values.add(v);
      if (v > 0) {
        completed++;
      }
    }

    // 从最早到最晚（正向）
    final reversed = values.reversed.toList();
    var avg = 0.0;
    if (reversed.isNotEmpty) {
      var sum = 0;
      for (final v in reversed) {
        sum += v;
      }
      avg = sum / reversed.length;
    }

    // 计算连续天数（从最近一天往回数）
    var currentStreak = 0;
    for (var i = days.length - 1; i >= 0; i--) {
      if (getter(days[i]) > 0) {
        currentStreak++;
      } else {
        break;
      }
    }

    return HabitItemStats(
      key: key,
      title: title,
      group: group,
      type: HabitStatType.numeric,
      recent7Values: reversed,
      completedDays: completed,
      totalDays: days.length,
      averageValue: avg,
      currentStreak: currentStreak,
    );
  }

  HabitItemStats _buildBooleanItem(
    String key,
    String title,
    HabitGroup group,
    List<HabitDayRecord> days,
    bool Function(HabitDayRecord) getter,
  ) {
    final values = <int>[];
    var completed = 0;

    for (var i = days.length - 1; i >= 0; i--) {
      final done = getter(days[i]);
      values.add(done ? 1 : 0);
      if (done) completed++;
    }

    final reversed = values.reversed.toList();

    // 计算连续天数（从最近一天往回数）
    var currentStreak = 0;
    for (var i = days.length - 1; i >= 0; i--) {
      if (getter(days[i])) {
        currentStreak++;
      } else {
        break;
      }
    }

    return HabitItemStats(
      key: key,
      title: title,
      group: group,
      type: HabitStatType.boolean,
      recent7Values: reversed,
      completedDays: completed,
      totalDays: days.length,
      averageValue: completed.toDouble(),
      currentStreak: currentStreak,
    );
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

  // ── 反馈文案 ──

  String _buildFeedback(
      List<HabitDayRecord> days, List<HabitItemStats> items) {
    final hasAny = days.any((d) => d.hasDiary && d.completedCount > 0);
    if (!hasAny) {
      return '这周还没有太多习惯记录。先从照顾今天开始。';
    }

    // 找到完成最多的习惯
    HabitItemStats? best;
    for (final item in items) {
      if (item.completedDays > 0 &&
          (best == null || item.completedDays > best.completedDays)) {
        best = item;
      }
    }

    // 找到完成最少但不是完全没做过的
    HabitItemStats? worst;
    for (final item in items) {
      if (item.completedDays > 0 &&
          (worst == null || item.completedDays < worst.completedDays)) {
        worst = item;
      }
    }

    final rate = _calcOverallRate(days);

    if (rate >= 0.8) {
      return '这周你把自己照顾得挺稳定，继续保持这种轻轻的节奏。';
    }
    if (rate <= 0.3) {
      return '这周节奏有点松散也没关系，先选一个最容易的小习惯重新开始。';
    }

    var text = '';
    if (best != null) {
      text += '这周你最稳定的是「${best.title}」。';
    }
    if (worst != null && worst.key != best?.key && worst.completedDays <= 3) {
      text += '「${worst.title}」有些起伏，可以从一次很小的行动开始。';
    }

    return text.isNotEmpty ? text : '这周你把自己照顾得不错，继续保持。';
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

  HabitStats _emptyStats(List<DateTime> recent7) {
    final days = recent7.map((d) => _emptyDayRecord(d)).toList();
    return HabitStats(
      recentDays: days,
      monthDays: const [],
      items: _buildItemStats(days),
      overallRate: 0,
      feedbackText: '这周还没有太多习惯记录。先从照顾今天开始。',
    );
  }

  // ── 辅助 ──

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]),
        int.parse(parts[2]));
  }
}
