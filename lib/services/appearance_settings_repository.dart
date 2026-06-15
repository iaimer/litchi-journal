import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'appearance_settings.dart';
import 'ai_config_repository.dart';

/// 外观设置本地持久化仓库。
class AppearanceSettingsRepository {
  static const _key = 'appearance_settings';

  final AIConfigStorage _storage;

  AppearanceSettingsRepository({AIConfigStorage? storage})
      : _storage = storage ?? _DefaultStorage();

  Future<AppearanceSettings> load() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null || raw.isEmpty) {
        return AppearanceSettings();
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final settings = AppearanceSettings.fromJson(json);
      if (settings.schemaVersion < 1) {
        return AppearanceSettings();
      }
      return settings;
    } catch (_) {
      return AppearanceSettings();
    }
  }

  Future<void> save(AppearanceSettings settings) async {
    await _storage.write(_key, jsonEncode(settings.toJson()));
  }
}

class _DefaultStorage implements AIConfigStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
