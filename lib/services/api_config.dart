import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfig {
  static const _storage = FlutterSecureStorage();
  static const _keyUrl = 'api_base_url';
  static const _keyToken = 'api_token';
  static const _keyConnection = 'api_connection';

  final String baseUrl;
  final String token;

  ApiConfig({required this.baseUrl, required this.token});

  static Future<ApiConfig?> load() async {
    final connection = await _storage.read(key: _keyConnection);
    if (connection != null) {
      try {
        final data = jsonDecode(connection);
        if (data is! Map<String, dynamic>) return null;
        final url = data['baseUrl'];
        final token = data['token'];
        if (url is! String ||
            url.isEmpty ||
            token is! String ||
            token.isEmpty) {
          return null;
        }
        return ApiConfig(baseUrl: url, token: token);
      } on FormatException {
        return null;
      }
    }
    final url = await _storage.read(key: _keyUrl);
    final token = await _storage.read(key: _keyToken);
    if (url == null || url.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return ApiConfig(baseUrl: url, token: token);
  }

  Future<void> save() async {
    // 一次写入整份连接，避免地址和凭据只更新一半。
    await _storage.write(
      key: _keyConnection,
      value: jsonEncode({'baseUrl': baseUrl, 'token': token}),
    );
  }

  static Future<void> clear() async {
    await _storage.delete(key: _keyUrl);
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyConnection);
  }
}
