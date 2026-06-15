import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/image_settings.dart';

/// 图片设置本地持久化接口，支持测试注入。
abstract class ImageSettingsStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// 图片上传设置仓储。
class ImageSettingsRepository {
  static const _key = 'image_settings';

  final ImageSettingsStorage _storage;

  ImageSettingsRepository({ImageSettingsStorage? storage})
    : _storage = storage ?? _SecureStorageAdapter();

  Future<ImageSettings> load() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null || raw.isEmpty) return ImageSettings.defaults();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ImageSettings.fromJson(json);
    } catch (_) {
      return ImageSettings.defaults();
    }
  }

  Future<void> save(ImageSettings settings) async {
    final next = settings.copyWith(updatedAt: DateTime.now());
    await _storage.write(_key, jsonEncode(next.toJson()));
  }

  Future<ImageSettings> resetDefault() async {
    final defaults = ImageSettings.defaults();
    await save(defaults);
    return defaults;
  }
}

class _SecureStorageAdapter implements ImageSettingsStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
