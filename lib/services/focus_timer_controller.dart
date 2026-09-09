import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/focus_timer.dart';
import 'focus_timer_repository.dart';

/// App 内唯一的专注计时状态源。
class FocusTimerController extends ChangeNotifier {
  final FocusTimerRepository _repository;
  final DateTime Function() _now;

  FocusTimerSession? _session;
  Timer? _ticker;
  bool _busy = false;
  bool _disposed = false;
  Future<void>? _loadFuture;

  FocusTimerController({
    FocusTimerRepository? repository,
    DateTime Function()? now,
  }) : _repository = repository ?? FocusTimerRepository(),
       _now = now ?? DateTime.now;

  FocusTimerSession? get session => _session;
  bool get hasSession => _session != null;
  bool get isBusy => _busy;

  Future<void> load() {
    final pending = _loadFuture;
    if (pending != null) return pending;
    final future = _loadInternal();
    _loadFuture = future;
    return future.whenComplete(() {
      if (identical(_loadFuture, future)) _loadFuture = null;
    });
  }

  int elapsedSeconds([DateTime? now]) =>
      _session?.elapsedSeconds(now ?? _now()) ?? 0;

  Future<bool> start(HabitTimerTarget target) async {
    await load();
    if (_disposed) return false;
    if (_session != null || _busy) return false;
    final now = _now();
    final next = FocusTimerSession(
      habitKey: target.habitKey,
      displayName: target.displayName,
      markdownLabel: target.markdownLabel,
      icon: target.icon,
      colorArgb: target.colorArgb,
      diaryDate: DateTime(
        target.diaryDate.year,
        target.diaryDate.month,
        target.diaryDate.day,
      ),
      startedAt: now,
      accumulatedSeconds: 0,
      state: FocusTimerState.running,
      runningSince: now,
      rawLine: target.rawLine,
      currentMinutes: target.currentMinutes,
      dailyTargetMinutes: target.dailyTargetMinutes,
    );
    return _persist(next, startTicker: true);
  }

  Future<bool> pause() async {
    if (_disposed) return false;
    final current = _session;
    if (current == null || !current.isRunning || _busy) return false;
    return _persist(current.pauseAt(_now()), startTicker: false);
  }

  Future<bool> resume() async {
    if (_disposed) return false;
    final current = _session;
    if (current == null || !current.isPaused || _busy) return false;
    return _persist(current.resumeAt(_now()), startTicker: true);
  }

  Future<bool> discard() async {
    if (_disposed) return false;
    if (_session == null || _busy) return false;
    _busy = true;
    _notify();
    try {
      await _repository.clear();
      _session = null;
      _stopTicker();
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<bool> clearAfterSave() async {
    if (_disposed) return false;
    if (_session == null) return true;
    if (_busy) return false;
    _busy = true;
    _notify();
    var cleared = false;
    try {
      cleared = await _repository.clearAfterSave();
      return cleared;
    } finally {
      // 服务端已经成功写入时，当前内存会话必须停止，不能让用户再次提交。
      _session = null;
      _stopTicker();
      _busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTicker();
    super.dispose();
  }

  Future<void> _loadInternal() async {
    FocusTimerSession? loaded;
    try {
      loaded = await _repository.load();
    } catch (_) {
      loaded = null;
    }
    if (_disposed) return;
    // 启动期间若用户已经开始新会话，不能被较晚返回的旧存储结果覆盖。
    if (_session == null) {
      _session = loaded;
      if (_session?.isRunning == true) _startTicker();
    }
    _notify();
  }

  Future<bool> _persist(
    FocusTimerSession next, {
    required bool startTicker,
  }) async {
    if (_disposed) return false;
    _busy = true;
    _notify();
    try {
      await _repository.save(next);
      if (_disposed) return false;
      _session = next;
      if (startTicker) {
        _startTicker();
      } else {
        _stopTicker();
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _notify());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }
}
