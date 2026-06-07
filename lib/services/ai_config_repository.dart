import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/ai_config.dart';

abstract class AIConfigStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class AIConfigRepository {
  static const _key = 'ai_config';

  final AIConfigStorage _storage;

  AIConfigRepository({AIConfigStorage? storage})
      : _storage = storage ?? _SecureStorageAdapter();
  Future<AIConfig> loadAIConfig() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null || raw.isEmpty) return const AIConfig();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AIConfig.fromJson(json);
    } catch (_) {
      return const AIConfig();
    }
  }

  Future<void> saveAIConfig(AIConfig config) async {
    await _storage.write(_key, jsonEncode(config.toJson()));
  }

  Future<void> clearAIConfig() async {
    await _storage.delete(_key);
  }
}

class _SecureStorageAdapter implements AIConfigStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
