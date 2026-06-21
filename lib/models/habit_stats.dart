import 'dart:ui';

/// 习惯页顶级统计数据。
class HabitStats {
  static const schemaVersion = 1;

  final List<HabitDayRecord> recentDays;
  final List<HabitDayRecord> monthDays;
  final List<HabitDayRecord> days30;
  final List<HabitItemStats> items;
  final double overallRate;
  final String feedbackText;
  final String feedbackSummary;
  final String feedbackSuggestion;

  /// 缓存写入时间（仅缓存时有值）
  final DateTime? cachedAt;

  const HabitStats({
    required this.recentDays,
    required this.monthDays,
    required this.days30,
    required this.items,
    required this.overallRate,
    required this.feedbackText,
    required this.feedbackSummary,
    required this.feedbackSuggestion,
    this.cachedAt,
  });

  bool get isEmpty => recentDays.every((day) => day.completedCount == 0);

  // ── 序列化 ──

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'cachedAt': (cachedAt ?? DateTime.now()).toIso8601String(),
        'recentDays': recentDays.map((d) => d.toJson()).toList(),
        'monthDays': monthDays.map((d) => d.toJson()).toList(),
        'days30': days30.map((d) => d.toJson()).toList(),
        'items': items.map((i) => i.toJson()).toList(),
        'overallRate': overallRate,
        'feedbackText': feedbackText,
        'feedbackSummary': feedbackSummary,
        'feedbackSuggestion': feedbackSuggestion,
      };

  factory HabitStats.fromJson(Map<String, dynamic> json) {
    return HabitStats(
      recentDays: _parseDayList(json['recentDays']),
      monthDays: _parseDayList(json['monthDays']),
      days30: _parseDayList(json['days30']),
      items: _parseItemList(json['items']),
      overallRate: (json['overallRate'] as num?)?.toDouble() ?? 0,
      feedbackText: json['feedbackText'] as String? ?? '',
      feedbackSummary: json['feedbackSummary'] as String? ?? '',
      feedbackSuggestion: json['feedbackSuggestion'] as String? ?? '',
      cachedAt: DateTime.tryParse(json['cachedAt'] as String? ?? ''),
    );
  }
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

  /// 自定义 checkbox 习惯完成状态：customKey → checked。
  /// 空 Map 表示没有或未匹配到自定义习惯。
  final Map<String, bool> customCheckboxes;

  const HabitDayRecord({
    required this.date,
    required this.weekday,
    required this.hasDiary,
    required this.waterMl,
    required this.steps,
    required this.readingDone,
    required this.languageDone,
    required this.supplementDone,
    this.customCheckboxes = const {},
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

  // ── 序列化 ──

  Map<String, dynamic> toJson() => {
        'date': _formatDate(date),
        'weekday': weekday,
        'hasDiary': hasDiary,
        'waterMl': waterMl,
        'steps': steps,
        'readingDone': readingDone,
        'languageDone': languageDone,
        'supplementDone': supplementDone,
        'customCheckboxes': customCheckboxes,
      };

  factory HabitDayRecord.fromJson(Map<String, dynamic> json) {
    final rawCustom =
        json['customCheckboxes'] as Map<String, dynamic>? ?? const {};
    final customCheckboxes = <String, bool>{};
    for (final entry in rawCustom.entries) {
      customCheckboxes[entry.key] = entry.value as bool? ?? false;
    }
    return HabitDayRecord(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime(2000),
      weekday: json['weekday'] as String? ?? '',
      hasDiary: json['hasDiary'] as bool? ?? false,
      waterMl: json['waterMl'] as int? ?? 0,
      steps: json['steps'] as int? ?? 0,
      readingDone: json['readingDone'] as bool? ?? false,
      languageDone: json['languageDone'] as bool? ?? false,
      supplementDone: json['supplementDone'] as bool? ?? false,
      customCheckboxes: customCheckboxes,
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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

  // ── 序列化 ──

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'group': group.name,
        'type': type.name,
        'recent7Values': recent7Values,
        'completedDays': completedDays,
        'totalDays': totalDays,
        'averageValue': averageValue,
        'currentStreak': currentStreak,
        'displayName': displayName,
        'icon': icon,
        'color': color.toARGB32(),
        'recent30Values': recent30Values,
        'completedDays30': completedDays30,
        'completionRate30': completionRate30,
        'longestStreak30': longestStreak30,
      };

  factory HabitItemStats.fromJson(Map<String, dynamic> json) {
    return HabitItemStats(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      group: _parseGroup(json['group'] as String?),
      type: _parseType(json['type'] as String?),
      recent7Values: (json['recent7Values'] as List?)?.cast<int>() ?? [],
      completedDays: json['completedDays'] as int? ?? 0,
      totalDays: json['totalDays'] as int? ?? 0,
      averageValue: (json['averageValue'] as num?)?.toDouble() ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      displayName: json['displayName'] as String? ?? '',
      icon: json['icon'] as String? ?? '✅',
      color: Color(json['color'] as int? ?? 0xFF8A8278),
      recent30Values: (json['recent30Values'] as List?)?.cast<int>() ?? [],
      completedDays30: json['completedDays30'] as int? ?? 0,
      completionRate30: (json['completionRate30'] as num?)?.toDouble() ?? 0,
      longestStreak30: json['longestStreak30'] as int? ?? 0,
    );
  }
}

// ── 辅助 ──

List<HabitDayRecord> _parseDayList(dynamic list) {
  if (list is! List) return [];
  return list
      .map((j) => HabitDayRecord.fromJson(j as Map<String, dynamic>))
      .toList();
}

List<HabitItemStats> _parseItemList(dynamic list) {
  if (list is! List) return [];
  return list
      .map((j) => HabitItemStats.fromJson(j as Map<String, dynamic>))
      .toList();
}

HabitGroup _parseGroup(String? name) {
  if (name == 'growth') return HabitGroup.growth;
  return HabitGroup.body;
}

HabitStatType _parseType(String? name) {
  if (name == 'boolean') return HabitStatType.boolean;
  return HabitStatType.numeric;
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

enum HabitStatType { numeric, boolean }
