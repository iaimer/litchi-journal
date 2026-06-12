/// 习惯页顶级统计数据。
class HabitStats {
  final List<HabitDayRecord> recentDays;
  final List<HabitDayRecord> monthDays;
  final List<HabitItemStats> items;
  final double overallRate;
  final String feedbackText;

  const HabitStats({
    required this.recentDays,
    required this.monthDays,
    required this.items,
    required this.overallRate,
    required this.feedbackText,
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
