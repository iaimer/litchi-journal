import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfig {
  static const _storage = FlutterSecureStorage();
  static const _keyUrl = 'api_base_url';
  static const _keyToken = 'api_token';

  final String baseUrl;
  final String token;

  ApiConfig({required this.baseUrl, required this.token});

  static Future<ApiConfig?> load() async {
    final url = await _storage.read(key: _keyUrl);
    final token = await _storage.read(key: _keyToken);
    if (url == null || url.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return ApiConfig(baseUrl: url, token: token);
  }

  Future<void> save() async {
    await _storage.write(key: _keyUrl, value: baseUrl);
    await _storage.write(key: _keyToken, value: token);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _keyUrl);
    await _storage.delete(key: _keyToken);
  }
}
