import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/habit_trend.dart';

/// 趋势页缓存存储抽象，测试时可注入内存实现。
abstract class HabitTrendCacheStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _SecureHabitTrendStorage implements HabitTrendCacheStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// 习惯趋势页的当前周期缓存。
class HabitTrendCacheRepository {
  static const _keyPrefix = 'habit_trend_cache:';
  static final Map<String, Future<void>> _queues = {};
  static final Map<String, int> _generations = {};
  static final Map<String, Set<String>> _knownKeys = {};
  static final Set<String> _invalidatedNamespaces = {};
  static final Set<String> _writtenKeysAfterInvalidation = {};

  static Future<void> _serial(
    String namespace,
    Future<void> Function() action,
  ) {
    final next = (_queues[namespace] ?? Future.value()).then((_) => action());
    late final Future<void> tail;
    void release() {
      if (identical(_queues[namespace], tail)) _queues.remove(namespace);
    }

    tail = next.then<void>((_) => release(), onError: (Object _) => release());
    _queues[namespace] = tail;
    return next;
  }

  static Future<void> invalidateNamespace(
    String namespace, {
    HabitTrendCacheStorage? storage,
  }) {
    final encoded = Uri.encodeComponent(namespace);
    _generations[encoded] = (_generations[encoded] ?? 0) + 1;
    _invalidatedNamespaces.add(encoded);
    _writtenKeysAfterInvalidation.removeWhere(
      (key) => key.startsWith('$_keyPrefix$encoded:'),
    );
    // 清理排在已开始的写入之后，禁止旧 save 在删除之后重新落盘。
    return _serial(encoded, () async {
      try {
        final keys = {...?_knownKeys[encoded]};
        if (storage == null) {
          final stored = await const FlutterSecureStorage().readAll();
          keys.addAll(
            stored.keys.where((key) => key.startsWith('$_keyPrefix$encoded:')),
          );
        }
        final target = storage ?? _SecureHabitTrendStorage();
        for (final key in keys) {
          await target.delete(key);
        }
      } catch (_) {
        // 统计缓存清理不能影响已经成功的日记写入。
      }
    });
  }

  final HabitTrendCacheStorage _storage;
  final String _namespace;

  HabitTrendCacheRepository({
    HabitTrendCacheStorage? storage,
    String namespace = 'default',
  }) : _storage = storage ?? _SecureHabitTrendStorage(),
       _namespace = Uri.encodeComponent(
         namespace.trim().isEmpty ? 'default' : namespace.trim(),
       );

  Future<void> save(HabitTrendStats stats) async {
    final generation = _generations[_namespace] ?? 0;
    final key = _cacheKey(stats.period);
    (_knownKeys[_namespace] ??= {}).add(key);
    try {
      await _serial(_namespace, () async {
        if (generation != (_generations[_namespace] ?? 0)) return;
        await _storage.write(key, jsonEncode(stats.toJson()));
        if (generation == (_generations[_namespace] ?? 0)) {
          _writtenKeysAfterInvalidation.add(key);
        }
      });
    } catch (_) {
      // 缓存失败不能影响趋势页展示。
    }
  }

  Future<HabitTrendStats?> load(HabitTrendPeriod period) async {
    final key = _cacheKey(period);
    if (_invalidatedNamespaces.contains(_namespace) &&
        !_writtenKeysAfterInvalidation.contains(key)) {
      return null;
    }
    final generation = _generations[_namespace] ?? 0;
    try {
      final raw = await _storage.read(key);
      if (generation != (_generations[_namespace] ?? 0)) return null;
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['schemaVersion'] != HabitTrendStats.schemaVersion) {
        await _storage.delete(key);
        return null;
      }
      final stats = HabitTrendStats.fromJson(json);
      return stats.period.cacheKey == period.cacheKey ? stats : null;
    } catch (_) {
      try {
        await _storage.delete(key);
      } catch (_) {
        // 损坏缓存清理失败时，下一次读取仍会重新尝试网络数据。
      }
      return null;
    }
  }

  Future<void> clear(HabitTrendPeriod period) async {
    try {
      await _storage.delete(_cacheKey(period));
    } catch (_) {
      // 清理失败不影响下一次网络刷新。
    }
  }

  String _cacheKey(HabitTrendPeriod period) =>
      '$_keyPrefix$_namespace:${period.cacheKey}';
}
