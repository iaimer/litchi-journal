import 'dart:convert';
// ignore_for_file: prefer_initializing_formals

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/default_tag_config.dart';
import '../models/tag_config.dart';
import 'api_client.dart';

class TagRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;
  final Duration refreshTimeout;

  TagRepository({
    required ApiClient apiClient,
    FlutterSecureStorage? storage,
    this.refreshTimeout = const Duration(seconds: 5),
  }) : _apiClient = apiClient,
       _storage = storage ?? const FlutterSecureStorage();

  static const _cacheKey = 'tag_config';

  Future<TagConfig> loadTagConfig() async {
    final cached = await _readCachedTagConfigSafely();
    if (_isUsable(cached)) return cached!;

    try {
      final config = await refreshTagConfig().timeout(refreshTimeout);
      if (_isUsable(config)) return config;
    } catch (_) {
      // 远程暂不可用时使用内置标签表，保证记录入口和标签设置仍可用。
    }
    return DefaultTagConfig.value;
  }

  Future<TagConfig> refreshTagConfig() async {
    final config = await _apiClient.fetchTagConfig();
    await _cacheTagConfigSafely(config);
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

  Future<TagConfig?> _readCachedTagConfigSafely() async {
    try {
      return await cachedTagConfig();
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheTagConfigSafely(TagConfig config) async {
    try {
      final json = jsonEncode(config.toJson());
      await _storage.write(key: _cacheKey, value: json);
    } catch (_) {
      // 缓存失败不应影响本次标签配置可用性。
    }
  }

  bool _isUsable(TagConfig? config) {
    if (config == null || config.domains.isEmpty) return false;
    return config.domains.any((domain) => domain.topics.isNotEmpty);
  }
}
