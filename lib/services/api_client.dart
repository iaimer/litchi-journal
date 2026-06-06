import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/diary_entry.dart';
import '../models/tag_config.dart';
import 'api_config.dart';

class ApiClient {
  final ApiConfig _config;
  late final http.Client _http;
  late final String _baseUrl;
  late final Map<String, String> _headers;

  ApiClient(this._config) {
    _http = http.Client();
    _baseUrl = _normalizeUrl(_config.baseUrl);
    _headers = {
      'Authorization': 'Token ${_config.token}',
      'Content-Type': 'application/json',
    };
  }

  static String _normalizeUrl(String url) {
    var normalized = url.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.endsWith('/api/v1')) {
      normalized = normalized.substring(0, normalized.length - 7);
    }
    return normalized;
  }

  static String formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  static String generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  Future<TestConnectionResult> testConnection(DateTime date) async {
    final dateStr = formatDate(date);
    try {
      final response = await _http.get(
        Uri.parse('$_baseUrl/api/v1/diary/$dateStr'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return TestConnectionResult.ok();
      } else if (response.statusCode == 404) {
        return TestConnectionResult.okNoDiary();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return TestConnectionResult.authFailed();
      } else {
        return TestConnectionResult.failed('服务器返回错误 (${response.statusCode})');
      }
    } catch (e) {
      return TestConnectionResult.failed('无法连接到服务器');
    }
  }

  Future<DiaryEntry?> getDiary(DateTime date) async {
    final dateStr = formatDate(date);
    final response = await _http.get(
      Uri.parse('$_baseUrl/api/v1/diary/$dateStr'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DiaryEntry.fromJson(json);
    }
    return null;
  }

  Future<bool> appendQuickNote(DateTime date, String content) async {
    final dateStr = formatDate(date);
    final response = await _http.post(
      Uri.parse('$_baseUrl/api/v1/diary/quick-note'),
      headers: _headers,
      body: jsonEncode({
        'date': dateStr,
        'content': content,
        'tags': <String>[],
        'time': formatTime(DateTime.now()),
        'operationId': generateUuidV4(),
      }),
    );
    return response.statusCode == 200;
  }

  Future<TagConfig> fetchTagConfig() async {
    final response = await _http.get(
      Uri.parse('$_baseUrl/api/v1/settings/tags'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('获取标签配置失败 (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return TagConfig.fromJson(json);
  }

  void dispose() {
    _http.close();
  }
}

class TestConnectionResult {
  final bool success;
  final String message;

  TestConnectionResult._({required this.success, required this.message});

  factory TestConnectionResult.ok() =>
      TestConnectionResult._(success: true, message: '连接成功');

  factory TestConnectionResult.okNoDiary() =>
      TestConnectionResult._(success: true, message: '连接成功，今日日记尚未创建');

  factory TestConnectionResult.authFailed() =>
      TestConnectionResult._(success: false, message: '认证失败，请检查 Token');

  factory TestConnectionResult.failed(String msg) =>
      TestConnectionResult._(success: false, message: msg);
}
