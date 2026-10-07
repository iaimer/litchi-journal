import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/diary_entry.dart';
import '../models/gallery_result.dart';
import '../models/history_month_result.dart';
import '../models/habit_stats.dart';
import '../models/tag_config.dart';
import 'api_config.dart';
import 'reading_cache_repository.dart';
import 'habit_stats_service.dart';
import 'habit_stats_cache_repository.dart';
import 'habit_trend_cache_repository.dart';

typedef UploadProgressCallback = void Function(int sentBytes, int totalBytes);
typedef UploadBodyEncoder =
    Future<Uint8List> Function(Map<String, dynamic> body);

class ImageRevalidation {
  final Uint8List? bytes;
  final ApiException? error;
  const ImageRevalidation.success(this.bytes) : error = null;
  const ImageRevalidation.failure(this.error) : bytes = null;
}

class ApiClient {
  static const requestTimeout = Duration(seconds: 12);
  static const uploadTimeout = Duration(seconds: 30);

  final ApiConfig _config;
  final ReadingCacheRepository readingCache;
  late final UploadBodyEncoder? _uploadBodyEncoder;
  late final http.Client _http;
  late final String _baseUrl;
  late final Map<String, String> _headers;

  String get baseUrl => _baseUrl;
  String get cacheNamespace => _baseUrl;
  String get readingCacheNamespace {
    final uri = Uri.parse(_baseUrl).normalizePath();
    final canonical = uri.replace(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port:
          (uri.scheme == 'https' && uri.port == 443) ||
              (uri.scheme == 'http' && uri.port == 80)
          ? 0
          : uri.port,
    );
    return ReadingCacheRepository.digest('$canonical\n${_config.token}');
  }

  bool get hasToken => _config.token.trim().isNotEmpty;

  ApiConfig configWithBaseUrl(String baseUrl) {
    return ApiConfig(baseUrl: baseUrl, token: _config.token);
  }

  ApiClient(
    this._config, {
    http.Client? httpClient,
    UploadBodyEncoder? uploadBodyEncoder,
    ReadingCacheRepository? readingCache,
  }) : readingCache =
           readingCache ??
           (httpClient == null
               ? ReadingCacheRepository.shared
               : ReadingCacheRepository.disabled) {
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

  Future<DiaryEntry?> getDiary(
    DateTime date, {
    void Function(CachedReading<DiaryEntry>)? onCached,
    bool allowCachedFallback = false,
  }) async {
    final dateStr = formatDate(date);
    return _readJson(
      '/api/v1/diary/$dateStr',
      DiaryEntry.fromJson,
      onCached: onCached,
      allowCachedFallback: allowCachedFallback,
      missingAllowed: true,
    );
  }

  Future<T?> _readJson<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    void Function(CachedReading<T>)? onCached,
    bool allowCachedFallback = false,
    bool missingAllowed = false,
    String? cacheKey,
  }) async {
    final key = cacheKey ?? path;
    final namespace = path.startsWith('/api/v1/history/gallery')
        ? '$readingCacheNamespace/gallery'
        : readingCacheNamespace;
    var ticket = readingCache.begin(ReadingCacheKind.data, namespace, key);
    CachedReading<T>? cached;
    if (readingCache.enabled && (onCached != null || allowCachedFallback)) {
      final local = await _readStoredJson(namespace, key, parse);
      cached = local.reading;
      if (local.corrupted && ticket.generation == readingCache.dataGeneration) {
        ticket = readingCache.begin(ReadingCacheKind.data, namespace, key);
      }
      if (cached != null) onCached?.call(cached);
    }
    try {
      return await _readRemoteJson(
        path,
        namespace,
        key,
        parse,
        ticket,
        missingAllowed: missingAllowed,
      );
    } on ApiException catch (error) {
      if (allowCachedFallback &&
          cached != null &&
          error.canUseCachedReading &&
          ticket.generation == readingCache.dataGeneration) {
        return cached.value;
      }
      rethrow;
    }
  }

  Future<({CachedReading<T>? reading, bool corrupted})> _readStoredJson<T>(
    String namespace,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final stored = await readingCache.read(
      ReadingCacheKind.data,
      namespace,
      key,
    );
    if (stored == null) return (reading: null, corrupted: false);
    try {
      return (
        reading: CachedReading(
          parse(jsonDecode(utf8.decode(stored.bytes)) as Map<String, dynamic>),
          stored.updatedAt,
        ),
        corrupted: false,
      );
    } catch (_) {
      await readingCache.remove(ReadingCacheKind.data, namespace, key);
      return (reading: null, corrupted: true);
    }
  }

  Future<T?> _readRemoteJson<T>(
    String path,
    String namespace,
    String key,
    T Function(Map<String, dynamic>) parse,
    CacheWriteTicket ticket, {
    required bool missingAllowed,
  }) async {
    final response = await _get(path);
    if (ticket.generation != readingCache.dataGeneration) {
      throw const ApiException('内容已更新，请重新读取');
    }
    if ((response.statusCode == 404 && missingAllowed) ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      if (readingCache.isCurrent(ticket)) {
        await readingCache.remove(ReadingCacheKind.data, namespace, key);
      }
      if (response.statusCode == 404) return null;
    }
    if (response.statusCode != 200) {
      throw ApiException(
        _statusMessage('读取失败', response.statusCode),
        statusCode: response.statusCode,
      );
    }
    final value = parse(jsonDecode(response.body) as Map<String, dynamic>);
    await readingCache.write(ticket, response.bodyBytes);
    if (ticket.generation != readingCache.dataGeneration) {
      throw const ApiException('内容已更新，请重新读取');
    }
    return value;
  }

  /// 最近七天只补充已经存在的日记，不创建文件，也不预下载大图。
  Future<void> warmRecentDiaries(DateTime today) async {
    final generation = readingCache.dataGeneration;
    try {
      final dates = List.generate(
        7,
        (index) => DateTime(today.year, today.month, today.day - index),
      );
      final existing = <String>{};
      final months = dates.map((date) => '${date.year}-${date.month}').toSet();
      for (final month in months) {
        final parts = month.split('-');
        final history = await fetchHistoryMonth(
          int.parse(parts[0]),
          int.parse(parts[1]),
          allowCachedFallback: false,
        );
        existing.addAll(
          history.diaries.where((day) => day.exists).map((day) => day.date),
        );
      }
      final pending = dates
          .skip(1)
          .where((date) => existing.contains(formatDate(date)))
          .toList();
      Future<void> worker() async {
        while (pending.isNotEmpty &&
            generation == readingCache.dataGeneration) {
          final date = pending.removeLast();
          await getDiary(date);
        }
      }

      await Future.wait([worker(), worker()]);
    } catch (_) {
      /* 预热失败不打扰当前阅读，不自动循环重试。 */
    }
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
    String? entryId,
    String? operationId,
  }) async {
    final response = await _post(
      '/api/v1/diary/$section',
      body: {
        'date': formatDate(date),
        'content': content,
        'tags': tags,
        'time': time ?? formatTime(DateTime.now()),
        'entryId': ?entryId,
        'operationId': operationId ?? generateUuidV4(),
      },
    );
    return response.statusCode == 200;
  }

  Future<bool> appendQuickNote(
    DateTime date,
    String content, {
    List<String> tags = const [],
    String? time,
    String? entryId,
    String? operationId,
  }) {
    return _appendToSection(
      'quick-note',
      date,
      content,
      tags,
      time: time,
      entryId: entryId,
      operationId: operationId,
    );
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
    String? entryId,
    String? operationId,
  }) {
    return _appendToSection(
      'happiness',
      date,
      content,
      tags,
      time: time,
      entryId: entryId,
      operationId: operationId,
    );
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
    String? entryId,
    UploadProgressCallback? onProgress,
  }) async {
    final body = {
      'date': formatDate(date),
      'imageData': imageBase64,
      if (imagePrefix != null && imagePrefix.trim().isNotEmpty)
        'imagePrefix': imagePrefix.trim(),
      'entryId': ?entryId,
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
    bool forceRefresh = false,
    void Function(ImageRevalidation)? onRevalidated,
  }) async {
    final encodedName = Uri.encodeComponent(imageName);
    final uri = month != null
        ? Uri.parse(
            '$_baseUrl/api/v1/diary/image/$year/$encodedName?month=$month',
          )
        : Uri.parse('$_baseUrl/api/v1/diary/image/$year/$encodedName');

    final bytes = await _readImage(
      uri,
      forceRefresh: forceRefresh,
      jsonImage: true,
      onRevalidated: onRevalidated,
    );
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Future<Uint8List> fetchRenderedDiaryImage({
    required int year,
    required int month,
    required String imageName,
    required int maxWidth,
    bool forceRefresh = false,
    void Function(ImageRevalidation)? onRevalidated,
    void Function(DateTime)? onCacheRead,
  }) async {
    final encodedName = Uri.encodeComponent(imageName);
    final uri = Uri.parse(
      '$_baseUrl/api/v1/diary/image/render/$year/$encodedName',
    ).replace(queryParameters: {'month': '$month', 'maxWidth': '$maxWidth'});

    return _readImage(
      uri,
      forceRefresh: forceRefresh,
      onRevalidated: onRevalidated,
      onCacheRead: onCacheRead,
    );
  }

  Future<Uint8List> _readImage(
    Uri uri, {
    bool forceRefresh = false,
    bool jsonImage = false,
    void Function(ImageRevalidation)? onRevalidated,
    void Function(DateTime)? onCacheRead,
  }) async {
    final namespace = readingCacheNamespace;
    final key = uri.toString();
    final ticket = readingCache.begin(ReadingCacheKind.image, namespace, key);
    final cached = forceRefresh
        ? null
        : await readingCache.read(ReadingCacheKind.image, namespace, key);
    Future<Uint8List> download({bool background = false}) => _downloadImage(
      uri,
      ticket,
      jsonImage,
      invalidateOnFailure: !background,
    );

    if (cached != null) {
      onCacheRead?.call(cached.updatedAt);
      if (readingCache.now().difference(cached.updatedAt) >=
          ReadingCacheRepository.imageFreshness) {
        unawaited(
          download(background: true).then<void>(
            (bytes) {
              if (readingCache.isCurrent(ticket)) {
                onRevalidated?.call(ImageRevalidation.success(bytes));
              }
            },
            onError: (Object error, StackTrace _) {
              // 暂时不可连接仍保留旧图，但明确不存在或认证失败必须通知阅读层。
              if (error is ApiException && readingCache.isCurrent(ticket)) {
                if (error.statusCode == 404 || error.isAuthenticationFailure) {
                  unawaited(
                    readingCache.remove(ReadingCacheKind.image, namespace, key),
                  );
                }
                onRevalidated?.call(ImageRevalidation.failure(error));
              }
            },
          ),
        );
      }
      return cached.bytes;
    }
    try {
      final bytes = await download();
      onCacheRead?.call(readingCache.now());
      return bytes;
    } on ApiException catch (error) {
      if (error.isNetworkFailure) {
        throw const ApiException('此图片尚未缓存，连接服务器后可查看', isNetworkFailure: true);
      }
      rethrow;
    }
  }

  Future<Uint8List> _downloadImage(
    Uri uri,
    CacheWriteTicket ticket,
    bool jsonImage, {
    bool invalidateOnFailure = true,
  }) async {
    final response = await _send(() => _http.get(uri, headers: _headers));
    if (response.statusCode != 200) {
      if (invalidateOnFailure &&
          (response.statusCode == 404 ||
              response.statusCode == 401 ||
              response.statusCode == 403) &&
          readingCache.isCurrent(ticket)) {
        await readingCache.remove(
          ReadingCacheKind.image,
          readingCacheNamespace,
          uri.toString(),
        );
      }
      throw ApiException(
        _statusMessage('图片加载失败', response.statusCode),
        statusCode: response.statusCode,
      );
    }
    if (response.bodyBytes.isEmpty) throw const ApiException('图片数据无效，请重试');
    if (jsonImage) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'];
      if (data is! String || data.isEmpty) {
        throw const ApiException('图片数据无效，请重试');
      }
    }
    await readingCache.write(ticket, response.bodyBytes);
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
    String? entryId,
    String? expectedRaw,
  }) async {
    await _verifyEntryTarget(date, target, expectedRaw: expectedRaw);
    final response = await _post(
      '/api/v1/diary/edit-entry',
      body: {
        'date': formatDate(date),
        'section': section,
        'target': target,
        'replacement': replacement,
        'entryId': ?entryId,
      },
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteEntry(
    DateTime date, {
    required String section,
    required String line,
    String? expectedRaw,
  }) async {
    await _verifyEntryTarget(date, line, expectedRaw: expectedRaw);
    final response = await _post(
      '/api/v1/diary/delete-entry',
      body: {'date': formatDate(date), 'section': section, 'line': line},
    );
    return response.statusCode == 200;
  }

  Future<void> _verifyEntryTarget(
    DateTime date,
    String rawLine, {
    String? expectedRaw,
  }) async {
    final stored = await readingCache.read(
      ReadingCacheKind.data,
      readingCacheNamespace,
      '/api/v1/diary/${formatDate(date)}',
    );
    String? previousRaw;
    if (stored != null) {
      try {
        previousRaw = DiaryEntry.fromJson(
          jsonDecode(utf8.decode(stored.bytes)) as Map<String, dynamic>,
        ).raw;
      } catch (_) {
        // 损坏副本不参与写入确认，仍必须重新读取服务端。
      }
    }
    final latest = await getDiary(date);
    if ((expectedRaw ?? previousRaw) != null &&
        (expectedRaw ?? previousRaw) != latest?.raw) {
      throw const ApiException('记录已发生变化，请刷新日记后重新确认');
    }
    if (latest == null || !('\n${latest.raw}\n').contains('\n$rawLine\n')) {
      throw const ApiException('记录已发生变化，请刷新日记后重新确认');
    }
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

  Future<HistoryMonthResult> fetchHistoryMonth(
    int year,
    int month, {
    void Function(CachedReading<HistoryMonthResult>)? onCached,
    bool allowCachedFallback = true,
  }) async {
    return (await _readJson(
      '/api/v1/history/$year/$month',
      HistoryMonthResult.fromJson,
      onCached: onCached,
      allowCachedFallback: allowCachedFallback,
    ))!;
  }

  Future<GalleryPage> fetchGallery({
    String? cursor,
    int limit = 3,
    void Function(CachedReading<GalleryPage>)? onCached,
  }) async {
    final path = _galleryPath(cursor, limit);
    final key = _galleryCacheKey(path, cursor);
    final generation = readingCache.dataGeneration;
    final page = (await _readJson(
      path,
      GalleryPage.fromJson,
      onCached: onCached,
      cacheKey: key,
    ))!;
    if (limit == 3 && generation == readingCache.dataGeneration) {
      await _rememberGalleryPage(key);
    }
    return page;
  }

  String _galleryPath(String? cursor, int limit) {
    final query = <String, String>{'limit': '$limit'};
    if (cursor?.isNotEmpty == true) query['cursor'] = cursor!;
    final uri = Uri.parse(
      '$_baseUrl/api/v1/history/gallery',
    ).replace(queryParameters: query);
    return '${uri.path}?${uri.query}';
  }

  String _galleryCacheKey(String path, String? cursor) {
    if (cursor?.isNotEmpty == true) return path;
    final today = readingCache.now();
    return '$path|start=${today.year}-${today.month.toString().padLeft(2, '0')}';
  }

  static const _galleryManifestKey = 'visited-gallery-pages-v1';
  Future<void> _galleryManifestQueue = Future.value();

  Future<List<String>> _galleryManifest() async {
    final stored = await readingCache.read(
      ReadingCacheKind.data,
      '$readingCacheNamespace/gallery',
      _galleryManifestKey,
    );
    if (stored == null) return [];
    try {
      return (jsonDecode(utf8.decode(stored.bytes)) as List).cast<String>();
    } catch (_) {
      await readingCache.remove(
        ReadingCacheKind.data,
        '$readingCacheNamespace/gallery',
        _galleryManifestKey,
      );
      return [];
    }
  }

  Future<void> _rememberGalleryPage(String key) {
    if (!readingCache.enabled) return Future.value();
    final generation = readingCache.dataGeneration;
    final result = _galleryManifestQueue.then((_) async {
      if (generation != readingCache.dataGeneration) return;
      await _writeGalleryManifest(key);
    });
    _galleryManifestQueue = result.catchError((Object _) {});
    return result;
  }

  Future<void> _writeGalleryManifest(String key) async {
    final ticket = readingCache.begin(
      ReadingCacheKind.data,
      '$readingCacheNamespace/gallery',
      _galleryManifestKey,
    );
    final visited = await _galleryManifest();
    // 描述符也有界；其引用的内容仍由统一容量上限淘汰。
    final keys = {key, ...visited}.take(240).toList();
    await readingCache.write(
      ticket,
      Uint8List.fromList(utf8.encode(jsonEncode(keys))),
    );
  }

  /// 重启及跨月后恢复仍存在的已访问分页，首页淘汰不阻断较早月份。
  Stream<CachedReading<GalleryPage>> cachedGalleryPages() async* {
    if (!readingCache.enabled) return;
    final generation = readingCache.dataGeneration;
    final visited = <String>{};
    final keys = [
      _galleryCacheKey(_galleryPath(null, 3), null),
      ...await _galleryManifest(),
    ];
    keys.sort((a, b) => _galleryKeyMonth(b).compareTo(_galleryKeyMonth(a)));
    for (final key in keys) {
      if (!visited.add(key)) continue;
      final namespace = '$readingCacheNamespace/gallery';
      final stored = await readingCache.read(
        ReadingCacheKind.data,
        namespace,
        key,
      );
      if (generation != readingCache.dataGeneration) return;
      if (stored == null) continue;
      GalleryPage page;
      try {
        page = GalleryPage.fromJson(
          jsonDecode(utf8.decode(stored.bytes)) as Map<String, dynamic>,
        );
      } catch (_) {
        await readingCache.remove(ReadingCacheKind.data, namespace, key);
        continue;
      }
      yield CachedReading(page, stored.updatedAt);
    }
  }

  String _galleryKeyMonth(String key) =>
      RegExp(r'(?:start=|cursor=)(\d{4}-\d{2})').firstMatch(key)?.group(1) ??
      '';

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

  /// 获取指定日期区间内的每日习惯快照。
  ///
  /// 服务端只读取并解析 Markdown，不会因为统计请求创建日记或修改内容。
  Future<List<HabitDayRecord>> fetchHabitStatsRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final generation = readingCache.dataGeneration;
    final uri = Uri.parse('$_baseUrl/api/v1/stats/habit').replace(
      queryParameters: {'from': formatDate(start), 'to': formatDate(end)},
    );
    final response = await _send(() => _http.get(uri, headers: _headers));
    if (generation != readingCache.dataGeneration) {
      throw const ApiException('内容已更新，请重新读取');
    }
    if (response.statusCode != 200) {
      throw ApiException(
        _statusMessage('获取习惯趋势失败', response.statusCode),
        statusCode: response.statusCode,
      );
    }
    final raw = jsonDecode(response.body);
    if (raw is! List) throw const FormatException('习惯趋势响应无效');
    return raw
        .whereType<Map<String, dynamic>>()
        .map(HabitDayRecord.fromJson)
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
  }) async {
    final response = await _send(
      () => _http.post(
        Uri.parse('$_baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      timeout: timeout,
    );
    if (response.statusCode == 200 && path.startsWith('/api/v1/diary/')) {
      await _invalidateReading(body);
      if (path.contains('delete')) {
        await _invalidateImagesSafely();
      }
    }
    return response;
  }

  Future<void> _invalidateImagesSafely() async {
    try {
      await readingCache.clear(imagesOnly: true);
    } catch (_) {
      /* 保留服务端操作结果。 */
    }
  }

  Future<void> _invalidateReading(Map<String, dynamic> body) async {
    // 先同步使在途读取失效，再等待磁盘清理。
    final invalidations = <Future<void>>[
      readingCache.invalidateData('$readingCacheNamespace/gallery'),
    ];
    HabitStatsService.clearDayCache();
    invalidations.add(HabitStatsCacheRepository().clear());
    invalidations.add(
      HabitTrendCacheRepository.invalidateNamespace(cacheNamespace),
    );
    final date = body['date'];
    if (date is String) {
      invalidations.add(
        readingCache.remove(
          ReadingCacheKind.data,
          readingCacheNamespace,
          '/api/v1/diary/$date',
        ),
      );
      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        invalidations.add(
          readingCache.remove(
            ReadingCacheKind.data,
            readingCacheNamespace,
            '/api/v1/history/${parsed.year}/${parsed.month}',
          ),
        );
      }
    }
    try {
      await Future.wait(invalidations).timeout(const Duration(seconds: 2));
    } catch (_) {
      // 服务端保存成功，不因本地清理失败或延迟改变结果。
    }
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
    final response = await _send(
      () async => http.Response.fromStream(await _http.send(request)),
      timeout: timeout,
    );
    if (response.statusCode == 200 && path.startsWith('/api/v1/diary/')) {
      await _invalidateReading(body);
    }
    return response;
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    Duration timeout = requestTimeout,
  }) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException('连接超时，请检查网络或服务器状态', isNetworkFailure: true);
    } on SocketException {
      throw const ApiException('无法连接到服务器，请检查网络或服务器地址', isNetworkFailure: true);
    } on http.ClientException {
      throw const ApiException('网络请求失败，请检查服务器地址', isNetworkFailure: true);
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
  final bool isNetworkFailure;

  const ApiException(
    this.message, {
    this.statusCode,
    this.isNetworkFailure = false,
  });
  bool get canUseCachedReading =>
      isNetworkFailure || (statusCode != null && statusCode! >= 500);
  bool get isAuthenticationFailure => statusCode == 401 || statusCode == 403;

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
