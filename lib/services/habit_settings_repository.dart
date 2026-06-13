import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/habit_settings.dart';

/// 抽象存储接口，支持测试注入。
abstract class HabitSettingsStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// 习惯设置本地持久化仓储。
///
/// 使用 flutter_secure_storage 存储，存储 key 为 `habit_settings`。
class HabitSettingsRepository {
  static const _key = 'habit_settings';

  final HabitSettingsStorage _storage;

  HabitSettingsRepository({HabitSettingsStorage? storage})
    : _storage = storage ?? _SecureStorageAdapter();

  /// 加载设置。无缓存或解析失败时返回默认值（全部活跃）。
  Future<HabitSettings> load() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null || raw.isEmpty) return HabitSettings.defaults;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return HabitSettings.fromJson(json);
    } catch (_) {
      return HabitSettings.defaults;
    }
  }

  /// 保存设置。
  Future<void> save(HabitSettings settings) async {
    await _storage.write(_key, jsonEncode(settings.toJson()));
  }

  /// 清除缓存（恢复默认）。
  Future<void> clear() async {
    try {
      await _storage.delete(_key);
    } catch (_) {
      // 静默失败
    }
  }
}

class _SecureStorageAdapter implements HabitSettingsStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
