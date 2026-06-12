import 'dart:ui';

/// 习惯页顶级统计数据。
class HabitStats {
  final List<HabitDayRecord> recentDays;
  final List<HabitDayRecord> monthDays;
  final List<HabitDayRecord> days30;
  final List<HabitItemStats> items;
  final double overallRate;
  final String feedbackText;
  final String feedbackSummary;
  final String feedbackSuggestion;

  const HabitStats({
    required this.recentDays,
    required this.monthDays,
    required this.days30,
    required this.items,
    required this.overallRate,
    required this.feedbackText,
    required this.feedbackSummary,
    required this.feedbackSuggestion,
  });

  bool get isEmpty => recentDays.isEmpty && items.isEmpty;
}

/// 单天习惯记录快照。
class HabitDayRecord {
  final DateTime date;
  final String weekday;
  final bool hasDiary;
  final int waterMl;
  final int steps;
  final bool readingDone;
  final bool languageDone;
  final bool supplementDone;

  const HabitDayRecord({
    required this.date,
    required this.weekday,
    required this.hasDiary,
    required this.waterMl,
    required this.steps,
    required this.readingDone,
    required this.languageDone,
    required this.supplementDone,
  });

  int get completedCount {
    var n = 0;
    if (waterMl > 0) n++;
    if (steps > 0) n++;
    if (readingDone) n++;
    if (languageDone) n++;
    if (supplementDone) n++;
    return n;
  }

  static const totalCount = 5;
}

/// 单个习惯的聚合统计。
class HabitItemStats {
  final String key;
  final String title;
  final HabitGroup group;
  final HabitStatType type;
  final List<int> recent7Values;
  final int completedDays;
  final int totalDays;
  final double averageValue;
  final int currentStreak;

  // 视觉配置
  final String displayName;
  final String icon;
  final Color color;

  // 最近 30 天统计
  final List<int> recent30Values;
  final int completedDays30;
  final double completionRate30;
  final int longestStreak30;

  const HabitItemStats({
    required this.key,
    required this.title,
    required this.group,
    required this.type,
    required this.recent7Values,
    required this.completedDays,
    required this.totalDays,
    required this.averageValue,
    required this.currentStreak,
    required this.displayName,
    required this.icon,
    required this.color,
    this.recent30Values = const [],
    this.completedDays30 = 0,
    this.completionRate30 = 0,
    this.longestStreak30 = 0,
  });
}

enum HabitGroup {
  body,
  growth;

  String get label {
    switch (this) {
      case HabitGroup.body:
        return '照顾身体';
      case HabitGroup.growth:
        return '照顾成长';
    }
  }
}

enum HabitStatType {
  numeric,
  boolean;
}
