import 'dart:math' as math;

/// 可从习惯卡进入专注计时的目标。
class HabitTimerTarget {
  final String habitKey;
  final String displayName;
  final String markdownLabel;
  final String icon;
  final int colorArgb;
  final DateTime diaryDate;
  final String rawLine;
  final int currentMinutes;
  final int? dailyTargetMinutes;

  const HabitTimerTarget({
    required this.habitKey,
    required this.displayName,
    required this.markdownLabel,
    required this.icon,
    required this.colorArgb,
    required this.diaryDate,
    required this.rawLine,
    required this.currentMinutes,
    this.dailyTargetMinutes,
  });
}

enum FocusTimerState { running, paused }

/// 可恢复的单个专注计时会话。
///
/// runningSince 是最近一次继续计时的时间戳；界面显示的秒数始终由
/// accumulatedSeconds + runningSince 计算，避免依赖 Timer.periodic 的准确性。
class FocusTimerSession {
  final String habitKey;
  final String displayName;
  final String markdownLabel;
  final String icon;
  final int colorArgb;
  final DateTime diaryDate;
  final DateTime startedAt;
  final int accumulatedSeconds;
  final FocusTimerState state;
  final DateTime? runningSince;
  final String rawLine;
  final int currentMinutes;
  final int? dailyTargetMinutes;

  const FocusTimerSession({
    required this.habitKey,
    required this.displayName,
    required this.markdownLabel,
    required this.icon,
    required this.colorArgb,
    required this.diaryDate,
    required this.startedAt,
    required this.accumulatedSeconds,
    required this.state,
    required this.runningSince,
    required this.rawLine,
    required this.currentMinutes,
    this.dailyTargetMinutes,
  });

  bool get isRunning => state == FocusTimerState.running;
  bool get isPaused => state == FocusTimerState.paused;

  int elapsedSeconds([DateTime? now]) {
    if (!isRunning || runningSince == null) return accumulatedSeconds;
    final elapsed = (now ?? DateTime.now()).difference(runningSince!).inSeconds;
    return math.max(0, accumulatedSeconds + elapsed);
  }

  FocusTimerSession pauseAt(DateTime now) {
    return copyWith(
      accumulatedSeconds: elapsedSeconds(now),
      state: FocusTimerState.paused,
      runningSince: null,
      clearRunningSince: true,
    );
  }

  FocusTimerSession resumeAt(DateTime now) {
    return copyWith(state: FocusTimerState.running, runningSince: now);
  }

  FocusTimerSession copyWith({
    int? accumulatedSeconds,
    FocusTimerState? state,
    DateTime? runningSince,
    bool clearRunningSince = false,
  }) {
    return FocusTimerSession(
      habitKey: habitKey,
      displayName: displayName,
      markdownLabel: markdownLabel,
      icon: icon,
      colorArgb: colorArgb,
      diaryDate: diaryDate,
      startedAt: startedAt,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      state: state ?? this.state,
      runningSince: clearRunningSince
          ? null
          : runningSince ?? this.runningSince,
      rawLine: rawLine,
      currentMinutes: currentMinutes,
      dailyTargetMinutes: dailyTargetMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'habitKey': habitKey,
    'displayName': displayName,
    'markdownLabel': markdownLabel,
    'icon': icon,
    'colorArgb': colorArgb,
    'diaryDate': _dateKey(diaryDate),
    'startedAt': startedAt.toIso8601String(),
    'accumulatedSeconds': accumulatedSeconds,
    'state': state.name,
    'runningSince': runningSince?.toIso8601String(),
    'rawLine': rawLine,
    'currentMinutes': currentMinutes,
    'dailyTargetMinutes': dailyTargetMinutes,
  };

  factory FocusTimerSession.fromJson(Map<String, dynamic> json) {
    final habitKey = json['habitKey'];
    final displayName = json['displayName'];
    final markdownLabel = json['markdownLabel'];
    final icon = json['icon'];
    final colorArgb = json['colorArgb'];
    final diaryDate = _parseDate(json['diaryDate']);
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    final accumulatedSeconds = json['accumulatedSeconds'];
    final stateName = json['state'];
    final runningSince = json['runningSince'] == null
        ? null
        : DateTime.tryParse(json['runningSince'] as String? ?? '');
    final rawLine = json['rawLine'];
    final currentMinutes = json['currentMinutes'];
    final dailyTargetMinutes = json['dailyTargetMinutes'];

    if (habitKey is! String ||
        habitKey.trim().isEmpty ||
        displayName is! String ||
        displayName.trim().isEmpty ||
        markdownLabel is! String ||
        markdownLabel.trim().isEmpty ||
        icon is! String ||
        colorArgb is! num ||
        diaryDate == null ||
        startedAt == null ||
        accumulatedSeconds is! num ||
        accumulatedSeconds < 0 ||
        rawLine is! String ||
        currentMinutes is! num ||
        currentMinutes < 0 ||
        stateName is! String ||
        !FocusTimerState.values.any((state) => state.name == stateName) ||
        (stateName == FocusTimerState.running.name && runningSince == null) ||
        (dailyTargetMinutes != null &&
            (dailyTargetMinutes is! num || dailyTargetMinutes <= 0))) {
      throw const FormatException('计时会话格式无效');
    }

    return FocusTimerSession(
      habitKey: habitKey,
      displayName: displayName,
      markdownLabel: markdownLabel,
      icon: icon,
      colorArgb: colorArgb.toInt(),
      diaryDate: diaryDate,
      startedAt: startedAt,
      accumulatedSeconds: accumulatedSeconds.toInt(),
      state: FocusTimerState.values.byName(stateName),
      runningSince: runningSince,
      rawLine: rawLine,
      currentMinutes: currentMinutes.toInt(),
      dailyTargetMinutes: dailyTargetMinutes?.toInt(),
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
