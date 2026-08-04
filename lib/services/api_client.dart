import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/history_month_result.dart';
import '../models/diary_entry.dart';
import '../models/tag_config.dart';
import 'api_config.dart';

class ApiClient {
  static const requestTimeout = Duration(seconds: 12);
  static const uploadTimeout = Duration(seconds: 30);

  final ApiConfig _config;
  late final http.Client _http;
  late final String _baseUrl;
  late final Map<String, String> _headers;

  String get baseUrl => _baseUrl;
  String get cacheNamespace => _baseUrl;
  bool get hasToken => _config.token.trim().isNotEmpty;

  ApiConfig configWithBaseUrl(String baseUrl) {
    return ApiConfig(baseUrl: baseUrl, token: _config.token);
  }

  ApiClient(this._config, {http.Client? httpClient}) {
    _http = httpClient ?? http.Client();
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
      final response = await _get('/api/v1/diary/$dateStr');
      if (response.statusCode == 200) {
        return TestConnectionResult.ok();
      } else if (response.statusCode == 404) {
        return TestConnectionResult.okNoDiary();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return TestConnectionResult.authFailed();
      } else {
        return TestConnectionResult.failed('服务器返回错误 (${response.statusCode})');
      }
    } on ApiException catch (e) {
      return TestConnectionResult.failed(e.message);
    } catch (e) {
      return TestConnectionResult.failed('无法连接到服务器');
    }
  }

  Future<DiaryEntry?> getDiary(DateTime date) async {
    final dateStr = formatDate(date);
    final response = await _get('/api/v1/diary/$dateStr');
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DiaryEntry.fromJson(json);
    }
    return null;
  }

  Future<bool> ensureDiary(DateTime date) async {
    final response = await _post(
      '/api/v1/diary/create',
      body: {'date': formatDate(date)},
    );
    return response.statusCode == 200;
  }

  Future<bool> _appendToSection(
    String section,
    DateTime date,
    String content,
    List<String> tags, {
    String? time,
  }) async {
    final response = await _post(
      '/api/v1/diary/$section',
      body: {
        'date': formatDate(date),
        'content': content,
        'tags': tags,
        'time': time ?? formatTime(DateTime.now()),
        'operationId': generateUuidV4(),
      },
    );
    return response.statusCode == 200;
  }

  Future<bool> appendQuickNote(
    DateTime date,
    String content, {
    List<String> tags = const [],
    String? time,
  }) {
    return _appendToSection('quick-note', date, content, tags, time: time);
  }

  Future<bool> appendReflection(
    DateTime date,
    String content, {
    List<String> tags = const [],
    String? time,
  }) {
    return _appendToSection('reflection', date, content, tags, time: time);
  }

  Future<bool> appendHappiness(
    DateTime date,
    String content, {
    List<String> tags = const [],
    String? time,
  }) {
    return _appendToSection('happiness', date, content, tags, time: time);
  }

  Future<bool> appendAnxiety(
    DateTime date,
    String content, {
    List<String> tags = const [],
    String? time,
  }) {
    return _appendToSection('anxiety', date, content, tags, time: time);
  }

  Future<bool> replaceAnxiety(DateTime date, String content) async {
    final response = await _post(
      '/api/v1/diary/anxiety/replace',
      body: {
        'date': formatDate(date),
        'content': content,
        'operationId': generateUuidV4(),
      },
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> uploadImage(
    DateTime date,
    String imageBase64, {
    String? operationId,
    String? imagePrefix,
  }) async {
    final response = await _post(
      '/api/v1/diary/image/upload',
      body: {
        'date': formatDate(date),
        'imageData': imageBase64,
        if (imagePrefix != null && imagePrefix.trim().isNotEmpty)
          'imagePrefix': imagePrefix.trim(),
        // ignore: use_null_aware_elements
        if (operationId != null) 'operationId': operationId,
      },
      timeout: uploadTimeout,
    );
    if (response.statusCode != 200) {
      throw ApiException(_statusMessage('图片上传失败', response.statusCode));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchDiaryImage({
    required int year,
    required String imageName,
    int? month,
  }) async {
    final encodedName = Uri.encodeComponent(imageName);
    final uri = month != null
        ? Uri.parse(
            '$_baseUrl/api/v1/diary/image/$year/$encodedName?month=$month',
          )
        : Uri.parse('$_baseUrl/api/v1/diary/image/$year/$encodedName');

    final response = await _send(() => _http.get(uri, headers: _headers));
    if (response.statusCode != 200) {
      throw ApiException(_statusMessage('图片加载失败', response.statusCode));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<bool> replaceLizhiSays(DateTime date, String content) async {
    final response = await _post(
      '/api/v1/diary/lizhi-says',
      body: {'date': formatDate(date), 'content': content},
    );
    return response.statusCode == 200;
  }

  Future<bool> replaceTomorrowSection(DateTime date, String content) async {
    final response = await _post(
      '/api/v1/diary/tomorrow',
      body: {'date': formatDate(date), 'content': content},
    );
    return response.statusCode == 200;
  }

  Future<bool> editEntry(
    DateTime date, {
    required String section,
    required String target,
    required String replacement,
  }) async {
    final response = await _post(
      '/api/v1/diary/edit-entry',
      body: {
        'date': formatDate(date),
        'section': section,
        'target': target,
        'replacement': replacement,
      },
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteEntry(
    DateTime date, {
    required String section,
    required String line,
  }) async {
    final response = await _post(
      '/api/v1/diary/delete-entry',
      body: {'date': formatDate(date), 'section': section, 'line': line},
    );
    return response.statusCode == 200;
  }

  Future<TagConfig> fetchTagConfig() async {
    final response = await _get('/api/v1/settings/tags');

    if (response.statusCode != 200) {
      throw ApiException(_statusMessage('获取标签配置失败', response.statusCode));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return TagConfig.fromJson(json);
  }

  Future<HistoryMonthResult> fetchHistoryMonth(int year, int month) async {
    final response = await _get('/api/v1/history/$year/$month');

    if (response.statusCode != 200) {
      throw ApiException(_statusMessage('获取历史日记列表失败', response.statusCode));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return HistoryMonthResult.fromJson(json);
  }

  Future<bool> updateHabits(
    DateTime date, {
    required int water,
    required int steps,
    required bool reading,
    required bool language,
    required bool supplements,
    Map<String, Map<String, dynamic>>? extraCheckboxes,
  }) async {
    final body = <String, dynamic>{
      'date': formatDate(date),
      'water': water,
      'steps': steps,
      'reading': reading,
      'language': language,
      'supplements': supplements,
      'operationId': generateUuidV4(),
    };
    if (extraCheckboxes != null && extraCheckboxes.isNotEmpty) {
      body['extraCheckboxes'] = extraCheckboxes;
    }
    final response = await _post('/api/v1/diary/habit', body: body);
    return response.statusCode == 200;
  }

  Future<http.Response> _get(String path) {
    return _send(
      () => _http.get(Uri.parse('$_baseUrl$path'), headers: _headers),
    );
  }

  Future<http.Response> _post(
    String path, {
    required Map<String, dynamic> body,
    Duration timeout = requestTimeout,
  }) {
    return _send(
      () => _http.post(
        Uri.parse('$_baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      timeout: timeout,
    );
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    Duration timeout = requestTimeout,
  }) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException('连接超时，请检查网络或服务器状态');
    } on SocketException {
      throw const ApiException('无法连接到服务器，请检查网络或服务器地址');
    } on http.ClientException {
      throw const ApiException('网络请求失败，请检查服务器地址');
    }
  }

  String _statusMessage(String prefix, int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return '$prefix：认证失败，请检查 Token';
    }
    if (statusCode == 413) {
      return '$prefix：图片过大，请调低图片质量后重试';
    }
    if (statusCode >= 500) {
      return '$prefix：服务器错误 ($statusCode)';
    }
    return '$prefix ($statusCode)';
  }

  void dispose() {
    _http.close();
  }
}

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
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
