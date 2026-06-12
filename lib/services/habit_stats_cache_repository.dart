import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/habit_stats.dart';

/// 缓存存储抽象接口，支持测试注入。
abstract class HabitStatsCacheStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _SecureStorageAdapter implements HabitStatsCacheStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// 习惯统计持久化缓存仓库。
///
/// 使用 flutter_secure_storage 存储最近一次完整统计结果。
/// 冷启动时先读缓存立即显示，后台刷新后覆盖。
///
/// 缓存策略：
/// - 24 小时内可直接展示
/// - 超过 24 小时仍先展示旧缓存，再后台刷新
/// - schema version 不匹配时安全忽略
/// - JSON 损坏不崩溃，走无缓存加载
class HabitStatsCacheRepository {
  static const _key = 'habit_stats_cache';

  final HabitStatsCacheStorage _storage;

  HabitStatsCacheRepository({HabitStatsCacheStorage? storage})
      : _storage = storage ?? _SecureStorageAdapter();

  /// 保存缓存。
  Future<void> save(HabitStats stats) async {
    try {
      final cached = HabitStats(
        recentDays: stats.recentDays,
        monthDays: stats.monthDays,
        days30: stats.days30,
        items: stats.items,
        overallRate: stats.overallRate,
        feedbackText: stats.feedbackText,
        feedbackSummary: stats.feedbackSummary,
        feedbackSuggestion: stats.feedbackSuggestion,
        cachedAt: DateTime.now(),
      );
      await _storage.write(_key, jsonEncode(cached.toJson()));
    } catch (_) {
      // 写入失败静默忽略
    }
  }

  /// 读取缓存。
  ///
  /// 返回 null 的情况：
  /// - 无缓存
  /// - schema version 不匹配
  /// - JSON 解析失败
  Future<HabitStats?> load() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null || raw.isEmpty) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final version = json['schemaVersion'] as int? ?? 0;
      if (version != HabitStats.schemaVersion) {
        await clear();
        return null;
      }

      return HabitStats.fromJson(json);
    } catch (_) {
      // JSON 损坏或解析失败，清除无效缓存
      await clear();
      return null;
    }
  }

  /// 清除缓存。
  Future<void> clear() async {
    try {
      await _storage.delete(_key);
    } catch (_) {
      // 静默失败
    }
  }
}
