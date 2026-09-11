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
    try {
      await _storage.write(_cacheKey(stats.period), jsonEncode(stats.toJson()));
    } catch (_) {
      // 缓存失败不能影响趋势页展示。
    }
  }

  Future<HabitTrendStats?> load(HabitTrendPeriod period) async {
    final key = _cacheKey(period);
    try {
      final raw = await _storage.read(key);
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
