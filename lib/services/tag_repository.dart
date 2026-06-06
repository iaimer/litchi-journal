import 'dart:convert';
// ignore_for_file: prefer_initializing_formals

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/tag_config.dart';
import 'api_client.dart';

class TagRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  TagRepository({
    required ApiClient apiClient,
    FlutterSecureStorage? storage,
  })  : _apiClient = apiClient,
        _storage = storage ?? const FlutterSecureStorage();

  static const _cacheKey = 'tag_config';

  Future<TagConfig> loadTagConfig() async {
    final cached = await cachedTagConfig();
    if (cached != null) return cached;

    try {
      return await refreshTagConfig();
    } catch (_) {
      throw Exception('无法获取标签配置，请检查网络连接');
    }
  }

  Future<TagConfig> refreshTagConfig() async {
    final config = await _apiClient.fetchTagConfig();
    final json = jsonEncode(config.toJson());
    await _storage.write(key: _cacheKey, value: json);
    return config;
  }

  Future<TagConfig?> cachedTagConfig() async {
    final json = await _storage.read(key: _cacheKey);
    if (json == null || json.isEmpty) return null;

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return TagConfig.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
