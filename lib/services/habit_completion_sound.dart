import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// 为短促的正向习惯操作提供低延迟完成音效。
class HabitCompletionSound {
  static final _source = AssetSource('sounds/habit_complete.wav');
  // 使用平台上下文表达「遵守静音且不抢占其他音频」；通用配置在 iOS
  // 上不能同时声明 respectSilence 和 mixWithOthers。
  static final _audioContext = AudioContext(
    android: AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.notificationRingtone,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  AudioPool? _pool;
  Future<AudioPool>? _poolFuture;
  bool _disposed = false;

  /// 在首页显示时预加载，避免第一次完成操作出现明显延迟。
  void preload() {
    unawaited(_preload());
  }

  Future<void> _preload() async {
    try {
      await _ensurePool();
    } catch (_) {
      // 预加载失败时在首次播放时再尝试，不能影响首页加载。
    }
  }

  /// 播放一次完成音效。音频失败不会影响习惯保存结果。
  void play() {
    if (_disposed) return;
    unawaited(_play());
  }

  Future<void> _play() async {
    try {
      final pool = await _ensurePool();
      if (_disposed) return;
      await pool.start(volume: 0.55);
    } catch (_) {
      // 完成音效是附加反馈，不能把已经成功的保存变成失败。
    }
  }

  Future<AudioPool> _ensurePool() {
    final pool = _pool;
    if (pool != null) return Future.value(pool);

    final pending = _poolFuture;
    if (pending != null) return pending;

    final future = _createPool();
    _poolFuture = future;
    return future;
  }

  Future<AudioPool> _createPool() async {
    try {
      final pool = await AudioPool.create(
        source: _source,
        minPlayers: 1,
        maxPlayers: 1,
        audioContext: _audioContext,
      );
      if (_disposed) {
        await pool.dispose();
        throw StateError('habit completion sound disposed');
      }
      _pool = pool;
      return pool;
    } catch (_) {
      _poolFuture = null;
      rethrow;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    final pool = _pool;
    _pool = null;
    _poolFuture = null;
    if (pool != null) await pool.dispose();
  }
}
