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

  /// 新格式日记中的分钟数；null 表示这是旧的纯 checkbox 记录，时长未知。
  final int? readingMinutes;
  final int? languageMinutes;

  /// 自定义 checkbox 习惯完成状态：customKey → checked。
  /// 空 Map 表示没有或未匹配到自定义习惯。
  final Map<String, bool> customCheckboxes;

  /// 自定义计时习惯的已知分钟数：customKey → minutes。
  final Map<String, int> customDurationMinutes;

  const HabitDayRecord({
    required this.date,
    required this.weekday,
    required this.hasDiary,
    required this.waterMl,
    required this.steps,
    required this.readingDone,
    required this.languageDone,
    required this.supplementDone,
    this.readingMinutes,
    this.languageMinutes,
    this.customCheckboxes = const {},
    this.customDurationMinutes = const {},
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
    'readingMinutes': readingMinutes,
    'languageMinutes': languageMinutes,
    'customCheckboxes': customCheckboxes,
    'customDurationMinutes': customDurationMinutes,
  };

  factory HabitDayRecord.fromJson(Map<String, dynamic> json) {
    final rawCustom = json['customCheckboxes'] is Map
        ? Map<String, dynamic>.from(json['customCheckboxes'] as Map)
        : const <String, dynamic>{};
    final customCheckboxes = <String, bool>{};
    for (final entry in rawCustom.entries) {
      customCheckboxes[entry.key] = entry.value as bool? ?? false;
    }
    final rawDurations = json['customDurationMinutes'] is Map
        ? Map<String, dynamic>.from(json['customDurationMinutes'] as Map)
        : json['customDurations'] is Map
        ? Map<String, dynamic>.from(json['customDurations'] as Map)
        : const <String, dynamic>{};
    final customDurationMinutes = <String, int>{};
    for (final entry in rawDurations.entries) {
      final value = entry.value;
      if (value is num && value >= 0) {
        customDurationMinutes[entry.key] = value.toInt();
      }
    }
    return HabitDayRecord(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime(2000),
      weekday: json['weekday'] as String? ?? '',
      hasDiary: json['hasDiary'] as bool? ?? false,
      waterMl: _parseInt(json['waterMl'] ?? json['water']),
      steps: _parseInt(json['steps']),
      readingDone:
          json['readingDone'] as bool? ?? json['reading'] as bool? ?? false,
      languageDone:
          json['languageDone'] as bool? ?? json['language'] as bool? ?? false,
      supplementDone:
          json['supplementDone'] as bool? ??
          json['supplements'] as bool? ??
          false,
      readingMinutes: _parseOptionalInt(json['readingMinutes']),
      languageMinutes: _parseOptionalInt(json['languageMinutes']),
      customCheckboxes: customCheckboxes,
      customDurationMinutes: customDurationMinutes,
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int? _parseOptionalInt(Object? value) {
    if (value is! num || value < 0 || value != value.toInt()) return null;
    return value.toInt();
  }

  static int _parseInt(Object? value) {
    if (value is! num || value < 0 || value != value.toInt()) return 0;
    return value.toInt();
  }
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

  /// 最近 7/30 天的完成状态，单独保存以兼容“完成但时长未知”的旧 checkbox 记录。
  final List<bool> recent7Completed;
  final List<bool> recent30Completed;
  final int completedDays30;
  final double completionRate30;
  final int longestStreak30;
  final int lifetimeValue;
  final int lifetimeKnownDays;

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
    this.recent7Completed = const [],
    this.recent30Completed = const [],
    this.completedDays30 = 0,
    this.completionRate30 = 0,
    this.longestStreak30 = 0,
    this.lifetimeValue = 0,
    this.lifetimeKnownDays = 0,
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
    'recent7Completed': recent7Completed,
    'recent30Completed': recent30Completed,
    'completedDays30': completedDays30,
    'completionRate30': completionRate30,
    'longestStreak30': longestStreak30,
    'lifetimeValue': lifetimeValue,
    'lifetimeKnownDays': lifetimeKnownDays,
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
      recent7Completed: _parseBoolList(json['recent7Completed']),
      recent30Completed: _parseBoolList(json['recent30Completed']),
      completedDays30: json['completedDays30'] as int? ?? 0,
      completionRate30: (json['completionRate30'] as num?)?.toDouble() ?? 0,
      longestStreak30: json['longestStreak30'] as int? ?? 0,
      lifetimeValue: json['lifetimeValue'] as int? ?? 0,
      lifetimeKnownDays: json['lifetimeKnownDays'] as int? ?? 0,
    );
  }
}

List<bool> _parseBoolList(dynamic list) {
  if (list is! List) return [];
  return list.whereType<bool>().toList();
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
  if (name == 'duration') return HabitStatType.duration;
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

enum HabitStatType { numeric, boolean, duration }
