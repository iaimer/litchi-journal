import 'dart:ui';

import '../models/habit_settings.dart';
import '../models/habit_stats.dart';
import '../models/habit_trend.dart';
import 'api_client.dart';

/// 为习惯趋势页构建周/月/年聚合数据。
///
/// 服务只读服务端快照，所有完成状态、连续天数和颜色等级均在客户端计算。
class HabitTrendService {
  final ApiClient _apiClient;

  HabitTrendService(this._apiClient);

  Future<HabitTrendStats> load({
    required HabitTrendPeriod period,
    required HabitSettings settings,
  }) async {
    final queryEnd = period.fetchEnd;
    final fetched = queryEnd.isBefore(period.queryStart)
        ? const <HabitDayRecord>[]
        : await _apiClient.fetchHabitStatsRange(
            start: period.queryStart,
            end: queryEnd,
          );
    final days = _fillPeriodDays(
      start: period.queryStart,
      end: period.queryEnd,
      fetched: fetched,
    );
    return build(period: period, sourceDays: days, settings: settings);
  }

  HabitTrendStats build({
    required HabitTrendPeriod period,
    required List<HabitDayRecord> sourceDays,
    required HabitSettings settings,
  }) {
    final items = settings.activeKeys
        .map((key) => _buildItem(key, sourceDays, settings, period))
        .toList();
    return HabitTrendStats(
      period: period,
      sourceDays: sourceDays,
      items: items,
      settingsSignature: settingsSignature(settings),
    );
  }

  String settingsSignature(HabitSettings settings) {
    return settings.activeKeys
        .map((key) {
          final aliases = [...?settings.customHabitAliases[key]]..sort();
          return [
            key,
            settings.displayNameFor(key),
            settings.iconFor(key),
            settings.colorFor(key).toString(),
            settings.trackingTypeFor(key).name,
            settings.targetFor(key)?.toString() ?? '',
            settings.durationDailyTargetFor(key)?.toString() ?? '',
            aliases.join(','),
          ].join('|');
        })
        .join('||');
  }

  HabitTrendItem _buildItem(
    String key,
    List<HabitDayRecord> sourceDays,
    HabitSettings settings,
    HabitTrendPeriod period,
  ) {
    final type = _statType(key, settings);
    final target = _targetFor(key, type, settings);
    final days = sourceDays.map((source) {
      final value = _valueFor(key, source, type, settings);
      final known = _valueKnown(key, source, type, settings);
      final completed = _isCompleted(
        key: key,
        value: value,
        known: known,
        source: source,
        type: type,
        target: target,
        settings: settings,
      );
      return HabitTrendDay(
        date: source.date,
        value: value,
        completed: completed,
        known: known,
        hasDiary: source.hasDiary,
        future: source.date.isAfter(period.asOfDate),
      );
    }).toList();

    final metricDays = days
        .where((day) => _isInMetricRange(period, day.date) && !day.future)
        .toList();
    final totalDuration = type == HabitStatType.duration
        ? metricDays
              .where((day) => day.known)
              .fold<int>(0, (sum, day) => sum + day.value)
        : 0;

    return HabitTrendItem(
      key: key,
      displayName: settings.displayNameFor(key),
      icon: settings.iconFor(key),
      color: Color(settings.colorFor(key)),
      type: type,
      dailyTarget: target,
      days: days,
      totalDurationMinutes: totalDuration,
      longestStreak: _longestStreak(metricDays),
    );
  }

  List<HabitDayRecord> _fillPeriodDays({
    required DateTime start,
    required DateTime end,
    required List<HabitDayRecord> fetched,
  }) {
    final byDate = <String, HabitDayRecord>{
      for (final day in fetched) _dateKey(day.date): day,
    };
    final dayCount = end.difference(start).inDays + 1;
    return List.generate(dayCount, (index) {
      final date = start.add(Duration(days: index));
      return byDate[_dateKey(date)] ?? _emptyDay(date);
    });
  }

  bool _isInMetricRange(HabitTrendPeriod period, DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(period.start) &&
        !normalized.isAfter(period.metricEnd);
  }

  HabitStatType _statType(String key, HabitSettings settings) {
    final tracking = settings.trackingTypeFor(key);
    if (tracking == HabitTrackingType.duration) {
      return HabitStatType.duration;
    }
    if (tracking == HabitTrackingType.counter) {
      return HabitStatType.numeric;
    }
    return HabitStatType.boolean;
  }

  int? _targetFor(String key, HabitStatType type, HabitSettings settings) {
    if (type == HabitStatType.numeric) return settings.targetFor(key);
    if (type == HabitStatType.duration) {
      return settings.durationDailyTargetFor(key);
    }
    return null;
  }

  int _valueFor(
    String key,
    HabitDayRecord day,
    HabitStatType type,
    HabitSettings settings,
  ) {
    if (type == HabitStatType.numeric) {
      if (key == 'water') return day.waterMl;
      if (key == 'steps') return day.steps;
    }
    if (type == HabitStatType.duration) {
      if (key == 'reading') return day.readingMinutes ?? 0;
      if (key == 'language') return day.languageMinutes ?? 0;
      return _customDurationFor(key, day, settings) ?? 0;
    }
    switch (key) {
      case 'reading':
        return day.readingDone ? 1 : 0;
      case 'language':
        return day.languageDone ? 1 : 0;
      case 'supplements':
        return day.supplementDone ? 1 : 0;
      default:
        return _customCheckboxFor(key, day, settings) ? 1 : 0;
    }
  }

  bool _valueKnown(
    String key,
    HabitDayRecord day,
    HabitStatType type,
    HabitSettings settings,
  ) {
    if (type != HabitStatType.duration) return true;
    if (key == 'reading') return day.readingMinutes != null;
    if (key == 'language') return day.languageMinutes != null;
    return _customDurationFor(key, day, settings) != null;
  }

  bool _isCompleted({
    required String key,
    required int value,
    required bool known,
    required HabitDayRecord source,
    required HabitStatType type,
    required int? target,
    required HabitSettings settings,
  }) {
    if (type == HabitStatType.boolean) return value == 1;
    if (type == HabitStatType.numeric) return target != null && value >= target;
    if (!known) {
      if (key == 'reading') return source.readingDone;
      if (key == 'language') return source.languageDone;
      return _customCheckboxFor(key, source, settings);
    }
    return target == null ? value > 0 : value >= target;
  }

  int? _customDurationFor(
    String key,
    HabitDayRecord day,
    HabitSettings settings,
  ) {
    final direct = day.customDurationMinutes[key];
    if (direct != null) return direct;
    for (final entry in day.customDurationMinutes.entries) {
      if (settings.customHabitKeyForLabel(entry.key) == key) {
        return entry.value;
      }
    }
    return null;
  }

  bool _customCheckboxFor(
    String key,
    HabitDayRecord day,
    HabitSettings settings,
  ) {
    if (day.customCheckboxes.containsKey(key)) {
      return day.customCheckboxes[key] == true;
    }
    for (final entry in day.customCheckboxes.entries) {
      if (settings.customHabitKeyForLabel(entry.key) == key) {
        return entry.value;
      }
    }
    return false;
  }

  int _longestStreak(List<HabitTrendDay> days) {
    var longest = 0;
    var current = 0;
    for (final day in days) {
      if (day.future) break;
      if (day.completed) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }

  HabitDayRecord _emptyDay(DateTime date) {
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
      readingMinutes: null,
      languageMinutes: null,
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
