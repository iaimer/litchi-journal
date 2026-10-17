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
