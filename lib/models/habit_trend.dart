import 'dart:ui';

import 'habit_stats.dart';

/// 习惯趋势页的时间粒度。
enum HabitTrendRange { week, month, year }

extension HabitTrendRangeLabel on HabitTrendRange {
  String get label {
    switch (this) {
      case HabitTrendRange.week:
        return '周';
      case HabitTrendRange.month:
        return '月';
      case HabitTrendRange.year:
        return '年';
    }
  }
}

/// 当前趋势页正在查看的日期区间。
class HabitTrendPeriod {
  static const yearHeatmapWeeks = 26;

  final HabitTrendRange range;
  final DateTime start;
  final DateTime end;

  /// 创建该周期时的本地日期，保证请求、未来槽位和缓存口径一致。
  final DateTime? referenceDate;

  const HabitTrendPeriod({
    required this.range,
    required this.start,
    required this.end,
    this.referenceDate,
  });

  factory HabitTrendPeriod.forAnchor(
    HabitTrendRange range,
    DateTime anchor, {
    DateTime? referenceDate,
  }) {
    final date = DateTime(anchor.year, anchor.month, anchor.day);
    final asOfDate = _dateOnly(referenceDate ?? DateTime.now());
    switch (range) {
      case HabitTrendRange.week:
        final monday = date.subtract(Duration(days: date.weekday - 1));
        return HabitTrendPeriod(
          range: range,
          start: monday,
          end: monday.add(const Duration(days: 6)),
          referenceDate: asOfDate,
        );
      case HabitTrendRange.month:
        return HabitTrendPeriod(
          range: range,
          start: DateTime(date.year, date.month),
          end: DateTime(date.year, date.month + 1, 0),
          referenceDate: asOfDate,
        );
      case HabitTrendRange.year:
        return HabitTrendPeriod(
          range: range,
          start: DateTime(date.year),
          end: DateTime(date.year, 12, 31),
          referenceDate: asOfDate,
        );
    }
  }

  int get dayCount => end.difference(start).inDays + 1;

  DateTime get asOfDate => _dateOnly(referenceDate ?? DateTime.now());

  /// 年档位的指标只使用当前自然年内、截至今天的日期。
  DateTime get metricEnd {
    return end.isBefore(asOfDate) ? end : asOfDate;
  }

  /// 热力图实际绘制的日期范围。年档位固定为最近 26 个自然周。
  DateTime get heatmapStart {
    if (range != HabitTrendRange.year) return start;
    return heatmapEnd.subtract(const Duration(days: yearHeatmapWeeks * 7 - 1));
  }

  DateTime get heatmapEnd {
    if (range != HabitTrendRange.year) return end;
    final visibleEnd = metricEnd;
    final endOfWeek = visibleEnd.add(Duration(days: 7 - visibleEnd.weekday));
    if (endOfWeek.isAfter(end) && end.isBefore(asOfDate)) {
      return end.subtract(Duration(days: end.weekday % 7));
    }
    return endOfWeek;
  }

  /// 为指标和热力图合并后的最早请求日期。
  DateTime get queryStart {
    if (range != HabitTrendRange.year) return start;
    return heatmapStart.isBefore(start) ? heatmapStart : start;
  }

  /// 为指标和热力图合并后的最晚展示日期，包含本周尚未到来的槽位。
  DateTime get queryEnd => range == HabitTrendRange.year ? heatmapEnd : end;

  /// 接口实际请求到今天为止，未来槽位由客户端补齐。
  DateTime get fetchEnd {
    return queryEnd.isBefore(asOfDate) ? queryEnd : asOfDate;
  }

  String get cacheKey {
    final base =
        '${range.name}:${_formatDate(start)}:${_formatDate(end)}:'
        '${_formatDate(asOfDate)}';
    if (range != HabitTrendRange.year) return base;
    return '$base:${_formatDate(heatmapStart)}:${_formatDate(heatmapEnd)}';
  }

  HabitTrendPeriod shift(int amount) {
    switch (range) {
      case HabitTrendRange.week:
        final nextStart = start.add(Duration(days: amount * 7));
        return HabitTrendPeriod(
          range: range,
          start: nextStart,
          end: nextStart.add(const Duration(days: 6)),
          referenceDate: referenceDate,
        );
      case HabitTrendRange.month:
        return HabitTrendPeriod.forAnchor(
          range,
          DateTime(start.year, start.month + amount, 1),
          referenceDate: asOfDate,
        );
      case HabitTrendRange.year:
        return HabitTrendPeriod.forAnchor(
          range,
          DateTime(start.year + amount),
          referenceDate: asOfDate,
        );
    }
  }

  bool canMoveForward(DateTime today) {
    return !shift(
      1,
    ).start.isAfter(DateTime(today.year, today.month, today.day));
  }

  Map<String, dynamic> toJson() => {
    'range': range.name,
    'start': _formatDate(start),
    'end': _formatDate(end),
    'referenceDate': _formatDate(asOfDate),
  };

  factory HabitTrendPeriod.fromJson(Map<String, dynamic> json) {
    final rangeName = json['range'] as String?;
    final range = HabitTrendRange.values.firstWhere(
      (value) => value.name == rangeName,
      orElse: () => HabitTrendRange.month,
    );
    final start = DateTime.tryParse(json['start'] as String? ?? '');
    final end = DateTime.tryParse(json['end'] as String? ?? '');
    if (start == null || end == null) {
      throw const FormatException('习惯趋势日期范围无效');
    }
    final referenceDate = DateTime.tryParse(
      json['referenceDate'] as String? ?? '',
    );
    return HabitTrendPeriod(
      range: range,
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day),
      referenceDate: referenceDate == null ? null : _dateOnly(referenceDate),
    );
  }
}

/// 一个习惯在周期内某一天的绘图数据。
class HabitTrendDay {
  final DateTime date;
  final int value;
  final bool completed;
  final bool known;
  final bool hasDiary;
  final bool future;

  const HabitTrendDay({
    required this.date,
    required this.value,
    required this.completed,
    required this.known,
    required this.hasDiary,
    required this.future,
  });

  Map<String, dynamic> toJson() => {
    'date': _formatDate(date),
    'value': value,
    'completed': completed,
    'known': known,
    'hasDiary': hasDiary,
    'future': future,
  };

  factory HabitTrendDay.fromJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.tryParse(json['date'] as String? ?? '');
    return HabitTrendDay(
      date: parsedDate == null
          ? DateTime(2000)
          : DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      value: (json['value'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      known: json['known'] as bool? ?? false,
      hasDiary: json['hasDiary'] as bool? ?? false,
      future: json['future'] as bool? ?? false,
    );
  }
}

/// 趋势页顶部仪表盘和热力图共用的单习惯聚合结果。
class HabitTrendItem {
  final String key;
  final String displayName;
  final String icon;
  final Color color;
  final HabitStatType type;
  final int? dailyTarget;
  final List<HabitTrendDay> days;
  final int totalDurationMinutes;
  final int longestStreak;

  const HabitTrendItem({
    required this.key,
    required this.displayName,
    required this.icon,
    required this.color,
    required this.type,
    required this.dailyTarget,
    required this.days,
    required this.totalDurationMinutes,
    required this.longestStreak,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'displayName': displayName,
    'icon': icon,
    'color': color.toARGB32(),
    'type': type.name,
    'dailyTarget': dailyTarget,
    'days': days.map((day) => day.toJson()).toList(),
    'totalDurationMinutes': totalDurationMinutes,
    'longestStreak': longestStreak,
  };

  factory HabitTrendItem.fromJson(Map<String, dynamic> json) {
    final type = HabitStatType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => HabitStatType.boolean,
    );
    final rawDays = json['days'];
    return HabitTrendItem(
      key: json['key'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      icon: json['icon'] as String? ?? 'check',
      color: Color(json['color'] as int? ?? 0xFF8A8278),
      type: type,
      dailyTarget: (json['dailyTarget'] as num?)?.toInt(),
      days: rawDays is List
          ? rawDays
                .whereType<Map<String, dynamic>>()
                .map(HabitTrendDay.fromJson)
                .toList()
          : const [],
      totalDurationMinutes:
          (json['totalDurationMinutes'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 习惯趋势页的完整数据，可持久化为缓存。
class HabitTrendStats {
  static const schemaVersion = 1;

  final HabitTrendPeriod period;
  final List<HabitDayRecord> sourceDays;
  final List<HabitTrendItem> items;
  final String settingsSignature;
  final DateTime? cachedAt;

  const HabitTrendStats({
    required this.period,
    required this.sourceDays,
    required this.items,
    required this.settingsSignature,
    this.cachedAt,
  });

  bool get isEmpty => items.isEmpty;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'period': period.toJson(),
    'sourceDays': sourceDays.map((day) => day.toJson()).toList(),
    'items': items.map((item) => item.toJson()).toList(),
    'settingsSignature': settingsSignature,
    'cachedAt': (cachedAt ?? DateTime.now()).toIso8601String(),
  };

  factory HabitTrendStats.fromJson(Map<String, dynamic> json) {
    final rawPeriod = json['period'];
    final rawSourceDays = json['sourceDays'];
    final rawItems = json['items'];
    if (rawPeriod is! Map<String, dynamic>) {
      throw const FormatException('习惯趋势缓存范围无效');
    }
    return HabitTrendStats(
      period: HabitTrendPeriod.fromJson(rawPeriod),
      sourceDays: rawSourceDays is List
          ? rawSourceDays
                .whereType<Map<String, dynamic>>()
                .map(HabitDayRecord.fromJson)
                .toList()
          : const [],
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(HabitTrendItem.fromJson)
                .toList()
          : const [],
      settingsSignature: json['settingsSignature'] as String? ?? '',
      cachedAt: DateTime.tryParse(json['cachedAt'] as String? ?? ''),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
