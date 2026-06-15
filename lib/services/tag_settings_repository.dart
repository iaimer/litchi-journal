import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import 'ai_config_repository.dart';

/// 标签设置本地持久化仓库。
/// 复用 AIConfigStorage 接口（与 AIConfigRepository 相同模式）。
class TagSettingsRepository {
  static const _key = 'tag_settings';

  final AIConfigStorage _storage;

  TagSettingsRepository({AIConfigStorage? storage})
      : _storage = storage ?? _DefaultStorage();

  /// 加载标签设置。
  /// - 首次无配置时从 TagConfig 生成默认设置
  /// - schemaVersion 不匹配或 JSON 损坏时回退默认
  /// - 已保存配置不会被默认值覆盖（除非损坏/版本不匹配）
  Future<TagSettings> loadTagSettings(TagConfig defaultConfig) async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null || raw.isEmpty) {
        return TagSettings.fromTagConfig(defaultConfig);
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final settings = TagSettings.fromJson(json);
      if (settings.schemaVersion < 1) {
        return TagSettings.fromTagConfig(defaultConfig);
      }
      return settings;
    } catch (_) {
      return TagSettings.fromTagConfig(defaultConfig);
    }
  }

  Future<void> saveTagSettings(TagSettings settings) async {
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
