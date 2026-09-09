import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/diary_entry.dart';
import '../models/gallery_result.dart';
import '../models/history_month_result.dart';
import '../models/tag_config.dart';
import 'api_config.dart';

typedef UploadProgressCallback = void Function(int sentBytes, int totalBytes);
typedef UploadBodyEncoder =
    Future<Uint8List> Function(Map<String, dynamic> body);

class ApiClient {
  static const requestTimeout = Duration(seconds: 12);
  static const uploadTimeout = Duration(seconds: 30);

  final ApiConfig _config;
  late final UploadBodyEncoder? _uploadBodyEncoder;
  late final http.Client _http;
  late final String _baseUrl;
  late final Map<String, String> _headers;

  String get baseUrl => _baseUrl;
  String get cacheNamespace => _baseUrl;
  bool get hasToken => _config.token.trim().isNotEmpty;

  ApiConfig configWithBaseUrl(String baseUrl) {
    return ApiConfig(baseUrl: baseUrl, token: _config.token);
  }

  ApiClient(
    this._config, {
    http.Client? httpClient,
    UploadBodyEncoder? uploadBodyEncoder,
  }) {
    _uploadBodyEncoder = uploadBodyEncoder;
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
    UploadProgressCallback? onProgress,
  }) async {
    final body = {
      'date': formatDate(date),
      'imageData': imageBase64,
      if (imagePrefix != null && imagePrefix.trim().isNotEmpty)
        'imagePrefix': imagePrefix.trim(),
      // ignore: use_null_aware_elements
      if (operationId != null) 'operationId': operationId,
    };
    final response = onProgress == null
        ? await _post(
            '/api/v1/diary/image/upload',
            body: body,
            timeout: uploadTimeout,
          )
        : await _postWithProgress(
            '/api/v1/diary/image/upload',
            body: body,
            onProgress: onProgress,
            timeout: uploadTimeout,
          );
    if (response.statusCode != 200) {
      throw ApiException(
        _statusMessage('图片上传失败', response.statusCode),
        statusCode: response.statusCode,
      );
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
      throw ApiException(
        _statusMessage('图片加载失败', response.statusCode),
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Uint8List> fetchRenderedDiaryImage({
    required int year,
    required int month,
    required String imageName,
    required int maxWidth,
  }) async {
    final encodedName = Uri.encodeComponent(imageName);
    final uri = Uri.parse(
      '$_baseUrl/api/v1/diary/image/render/$year/$encodedName',
    ).replace(queryParameters: {'month': '$month', 'maxWidth': '$maxWidth'});

    final response = await _send(() => _http.get(uri, headers: _headers));
    if (response.statusCode != 200) {
      throw ApiException(
        _statusMessage('图片加载失败', response.statusCode),
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
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
      throw ApiException(
        _statusMessage('获取标签配置失败', response.statusCode),
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return TagConfig.fromJson(json);
  }

  Future<HistoryMonthResult> fetchHistoryMonth(int year, int month) async {
    final response = await _get('/api/v1/history/$year/$month');

    if (response.statusCode != 200) {
      throw ApiException(
        _statusMessage('获取历史日记列表失败', response.statusCode),
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return HistoryMonthResult.fromJson(json);
  }

  Future<GalleryPage> fetchGallery({String? cursor, int limit = 3}) async {
    final query = <String, String>{'limit': '$limit'};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    final uri = Uri.parse(
      '$_baseUrl/api/v1/history/gallery',
    ).replace(queryParameters: query);
    final response = await _send(() => _http.get(uri, headers: _headers));
    if (response.statusCode != 200) {
      throw ApiException(
        _statusMessage('获取画廊记录失败', response.statusCode),
        statusCode: response.statusCode,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return GalleryPage.fromJson(json);
  }

  Future<bool> updateHabits(
    DateTime date, {
    required int water,
    required int steps,
    required bool reading,
    required bool language,
    required bool supplements,
    Map<String, Map<String, dynamic>>? extraCheckboxes,
    int? readingMinutes,
    int? languageMinutes,
    Map<String, Map<String, dynamic>>? extraDurations,
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
    if (readingMinutes != null) body['readingMinutes'] = readingMinutes;
    if (languageMinutes != null) body['languageMinutes'] = languageMinutes;
    if (extraDurations != null && extraDurations.isNotEmpty) {
      body['extraDurations'] = extraDurations;
    }
    final response = await _post('/api/v1/diary/habit', body: body);
    return response.statusCode == 200;
  }

  Future<HabitDurationResult?> updateHabitDuration(
    DateTime date, {
    required String habitKey,
    required String label,
    required String rawLine,
    required int minutes,
    required bool replace,
    int? dailyTargetMinutes,
  }) async {
    final body = <String, dynamic>{
      'date': formatDate(date),
      'habitKey': habitKey,
      'label': label,
      'rawLine': rawLine,
      'minutes': minutes,
      'operation': replace ? 'set' : 'add',
      'operationId': generateUuidV4(),
    };
    if (dailyTargetMinutes != null) {
      body['dailyTargetMinutes'] = dailyTargetMinutes;
    }
    final response = await _post('/api/v1/diary/habit/duration', body: body);
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return HabitDurationResult.fromJson(json);
  }

  Future<List<HabitDurationHistoryDay>> fetchHabitDurationHistory() async {
    final response = await _get('/api/v1/stats/habit?days=all');
    if (response.statusCode != 200) {
      throw ApiException(
        _statusMessage('获取习惯时长统计失败', response.statusCode),
        statusCode: response.statusCode,
      );
    }
    final raw = jsonDecode(response.body);
    if (raw is! List) throw const FormatException('习惯统计响应无效');
    return raw
        .whereType<Map<String, dynamic>>()
        .map(HabitDurationHistoryDay.fromJson)
        .toList();
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

  Future<http.Response> _postWithProgress(
    String path, {
    required Map<String, dynamic> body,
    required UploadProgressCallback onProgress,
    Duration timeout = requestTimeout,
  }) async {
    final bodyBytes =
        await (_uploadBodyEncoder?.call(body) ??
            compute(_encodeJsonBody, body));
    final request = _ProgressRequest(
      'POST',
      Uri.parse('$_baseUrl$path'),
      bodyBytes: bodyBytes,
      onProgress: onProgress,
    );
    request.headers.addAll(_headers);
    return _send(
      () async => http.Response.fromStream(await _http.send(request)),
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

Uint8List _encodeJsonBody(Map<String, dynamic> body) {
  return Uint8List.fromList(utf8.encode(jsonEncode(body)));
}

class _ProgressRequest extends http.BaseRequest {
  static const _chunkSize = 64 * 1024;

  final Uint8List bodyBytes;
  final UploadProgressCallback onProgress;

  _ProgressRequest(
    super.method,
    super.url, {
    required this.bodyBytes,
    required this.onProgress,
  }) {
    contentLength = bodyBytes.length;
  }

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_chunks());
  }

  Stream<List<int>> _chunks() async* {
    final totalBytes = bodyBytes.length;
    onProgress(0, totalBytes);
    for (var start = 0; start < totalBytes; start += _chunkSize) {
      final end = min(start + _chunkSize, totalBytes);
      yield Uint8List.sublistView(bodyBytes, start, end);
      onProgress(end, totalBytes);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class HabitDurationResult {
  final int minutes;
  final bool completed;
  final String rawLine;

  const HabitDurationResult({
    required this.minutes,
    required this.completed,
    required this.rawLine,
  });

  factory HabitDurationResult.fromJson(Map<String, dynamic> json) {
    final minutes = json['minutes'];
    final completed = json['completed'];
    final rawLine = json['rawLine'];
    if (minutes is! num || completed is! bool || rawLine is! String) {
      throw const FormatException('习惯时长响应无效');
    }
    return HabitDurationResult(
      minutes: minutes.toInt(),
      completed: completed,
      rawLine: rawLine,
    );
  }
}

class HabitDurationHistoryDay {
  final DateTime date;
  final int? readingMinutes;
  final int? languageMinutes;
  final Map<String, int> customDurations;

  const HabitDurationHistoryDay({
    required this.date,
    required this.readingMinutes,
    required this.languageMinutes,
    required this.customDurations,
  });

  factory HabitDurationHistoryDay.fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse(json['date'] as String? ?? '');
    if (date == null) throw const FormatException('习惯统计日期无效');
    final durations = <String, int>{};
    final raw = json['customDurations'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is num && entry.value >= 0) {
          durations[entry.key as String] = (entry.value as num).toInt();
        }
      }
    }
    return HabitDurationHistoryDay(
      date: date,
      readingMinutes: _optionalWholeInt(json['readingMinutes']),
      languageMinutes: _optionalWholeInt(json['languageMinutes']),
      customDurations: durations,
    );
  }
}

int? _optionalWholeInt(Object? value) {
  if (value is! num || value < 0 || value != value.toInt()) return null;
  return value.toInt();
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
