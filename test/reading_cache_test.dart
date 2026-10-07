import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/models/diary_entry.dart';
import 'package:litchi_journal_flutter/models/gallery_result.dart';
import 'package:litchi_journal_flutter/screens/home_screen.dart';
import 'package:litchi_journal_flutter/screens/past_screen.dart';
import 'package:litchi_journal_flutter/screens/read_only_diary_screen.dart';
import 'package:litchi_journal_flutter/screens/reading_cache_page.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/gallery_service.dart';
import 'package:litchi_journal_flutter/services/reading_cache_repository.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/gallery_image_tile.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));
http.Response _jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, dynamic> _diary(String text, {String date = '2026-10-06'}) => {
  'date': date,
  'title': date,
  'raw': '## 随手记\n- **18:20** $text',
  'sections': <String, dynamic>{},
};
ApiClient _api(
  ReadingCacheRepository cache,
  Future<http.Response> Function(http.Request) handler, {
  String baseUrl = 'http://cache.test',
  String token = 'fixture-credential',
}) => ApiClient(
  ApiConfig(baseUrl: baseUrl, token: token),
  readingCache: cache,
  httpClient: MockClient(handler),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('磁盘阅读缓存', () {
    late Directory directory;
    late ReadingCacheRepository cache;
    var clock = DateTime(2026, 10, 7);
    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'litchi-reading-cache-test-',
      );
      cache = ReadingCacheRepository(
        directoryProvider: () async => directory,
        now: () => clock,
      );
    });
    tearDown(() async => directory.delete(recursive: true));
    Future<void> put(ReadingCacheKind kind, String key, String value) =>
        cache.write(cache.begin(kind, 'connection', key), _bytes(value));

    test('跨实例保留内容和更新时间，读取不延长更新期限', () async {
      await put(ReadingCacheKind.data, 'diary', '正文');
      final savedAt = clock;
      clock = clock.add(const Duration(days: 9));
      final next = ReadingCacheRepository(
        directoryProvider: () async => directory,
        now: () => clock,
      );
      final result = await next.read(
        ReadingCacheKind.data,
        'connection',
        'diary',
      );
      expect(utf8.decode(result!.bytes), '正文');
      expect(result.updatedAt, savedAt);
    });

    test('日记和图片分类计量，清图片不清正文', () async {
      await put(ReadingCacheKind.data, 'diary', 'body');
      await put(ReadingCacheKind.image, 'image', 'image');
      final before = await cache.usage();
      expect(before.dataBytes, greaterThan(0));
      expect(before.imageBytes, greaterThan(0));
      await cache.clear(imagesOnly: true);
      expect((await cache.usage()).imageBytes, 0);
      expect(
        await cache.read(ReadingCacheKind.data, 'connection', 'diary'),
        isNotNull,
      );
      await cache.clear();
      expect((await cache.usage()).totalBytes, 0);
    });

    test('清理后在途请求不能回填，新请求仍可缓存', () async {
      final stale = cache.begin(ReadingCacheKind.image, 'connection', 'image');
      await cache.clear(imagesOnly: true);
      await cache.write(stale, _bytes('旧图片'));
      expect(
        await cache.read(ReadingCacheKind.image, 'connection', 'image'),
        isNull,
      );
      await put(ReadingCacheKind.image, 'image', '新图片');
      expect(
        utf8.decode(
          (await cache.read(
            ReadingCacheKind.image,
            'connection',
            'image',
          ))!.bytes,
        ),
        '新图片',
      );
    });

    test('同资源新请求先完成时，旧响应不能覆盖', () async {
      final old = cache.begin(ReadingCacheKind.data, 'connection', 'diary');
      await put(ReadingCacheKind.data, 'diary', 'new');
      await cache.write(old, _bytes('old'));
      expect(
        utf8.decode(
          (await cache.read(
            ReadingCacheKind.data,
            'connection',
            'diary',
          ))!.bytes,
        ),
        'new',
      );
    });

    test('校验损坏条目，只删除对应缓存', () async {
      await put(ReadingCacheKind.data, 'bad', 'bad');
      await put(ReadingCacheKind.image, 'good', 'good');
      final files = await Directory(
        '${directory.path}/reading_cache_v1/data',
      ).list().toList();
      await (files.single as File).writeAsBytes([0, 1]);
      expect(
        await cache.read(ReadingCacheKind.data, 'connection', 'bad'),
        isNull,
      );
      expect(
        await cache.read(ReadingCacheKind.image, 'connection', 'good'),
        isNotNull,
      );
    });

    test('达到上限按最后使用淘汰，超大单项不落盘', () async {
      cache = ReadingCacheRepository(
        directoryProvider: () async => directory,
        now: () => clock,
        maxImageBytes: 90,
      );
      await put(ReadingCacheKind.image, 'one', 'one');
      clock = clock.add(const Duration(seconds: 1));
      await put(ReadingCacheKind.image, 'two', 'two');
      clock = clock.add(const Duration(seconds: 1));
      await cache.read(ReadingCacheKind.image, 'connection', 'one');
      clock = clock.add(const Duration(seconds: 1));
      await put(ReadingCacheKind.image, 'three', 'three');
      expect(
        await cache.read(ReadingCacheKind.image, 'connection', 'two'),
        isNull,
      );
      expect(
        await cache.read(ReadingCacheKind.image, 'connection', 'one'),
        isNotNull,
      );
      await put(ReadingCacheKind.image, 'large', 'x' * 100);
      expect(
        await cache.read(ReadingCacheKind.image, 'connection', 'large'),
        isNull,
      );
      expect((await cache.usage()).imageBytes, lessThanOrEqualTo(90));
    });

    test('服务器与凭据隔离，磁盘标识不含凭据', () async {
      final first = _api(
        cache,
        (_) async => _jsonResponse(jsonEncode(_diary('first')), 200),
      );
      await first.getDiary(DateTime(2026, 10, 6));
      for (final different in [
        _api(
          cache,
          (_) async => throw const SocketException('offline'),
          baseUrl: 'http://other.test',
        ),
        _api(
          cache,
          (_) async => throw const SocketException('offline'),
          token: 'other-fixture',
        ),
      ]) {
        var called = false;
        await expectLater(
          different.getDiary(
            DateTime(2026, 10, 6),
            onCached: (_) => called = true,
          ),
          throwsA(isA<ApiException>()),
        );
        expect(called, isFalse);
      }
      final files = await directory.list(recursive: true).toList();
      expect(
        files.any((file) => file.path.contains('fixture-credential')),
        isFalse,
      );
    });

    test('先交付本地正文，再更新；重建客户端后仍可离线回退', () async {
      final first = _api(
        cache,
        (_) async => _jsonResponse(jsonEncode(_diary('cached')), 200),
      );
      await first.getDiary(DateTime(2026, 10, 6));
      final response = Completer<http.Response>();
      final second = _api(cache, (_) => response.future);
      final delivered = Completer<CachedReading<DiaryEntry>>();
      final read = second.getDiary(
        DateTime(2026, 10, 6),
        onCached: delivered.complete,
      );
      expect((await delivered.future).value.raw, contains('cached'));
      response.complete(_jsonResponse(jsonEncode(_diary('latest')), 200));
      expect((await read)!.raw, contains('latest'));
      final offline = _api(
        cache,
        (_) async => throw const SocketException('offline'),
      );
      expect(
        (await offline.getDiary(
          DateTime(2026, 10, 6),
          allowCachedFallback: true,
        ))!.raw,
        contains('latest'),
      );
    });

    test('401/403不返回缓存，404清除旧正文，500不是不存在', () async {
      for (final status in [401, 403, 404, 500]) {
        final online = _api(
          cache,
          (_) async => _jsonResponse(jsonEncode(_diary('cached')), 200),
        );
        await online.getDiary(DateTime(2026, 10, 6));
        final failed = _api(cache, (_) async => http.Response('{}', status));
        if (status == 404) {
          expect(await failed.getDiary(DateTime(2026, 10, 6)), isNull);
          expect(
            await cache.read(
              ReadingCacheKind.data,
              failed.readingCacheNamespace,
              '/api/v1/diary/2026-10-06',
            ),
            isNull,
          );
        } else {
          await expectLater(
            failed.getDiary(DateTime(2026, 10, 6)),
            throwsA(isA<ApiException>()),
          );
          if (status != 500) {
            await expectLater(
              failed.getDiary(DateTime(2026, 10, 6), allowCachedFallback: true),
              throwsA(isA<ApiException>()),
            );
          }
        }
      }
    });

    test('图片跨启动命中、尺寸隔离、强制重试绕过缓存', () async {
      var requests = 0;
      final client = _api(
        cache,
        (_) async => http.Response.bytes(_bytes('${++requests}'), 200),
      );
      Future<Uint8List> image(int width, {bool force = false}) =>
          client.fetchRenderedDiaryImage(
            year: 2026,
            month: 10,
            imageName: 'one.jpg',
            maxWidth: width,
            forceRefresh: force,
          );
      await image(480);
      await image(480);
      expect(requests, 1);
      await image(1600);
      expect(requests, 2);
      await image(480, force: true);
      expect(requests, 3);
      final offline = _api(
        ReadingCacheRepository(directoryProvider: () async => directory),
        (_) async => throw const SocketException('offline'),
      );
      expect(
        utf8.decode(
          await offline.fetchRenderedDiaryImage(
            year: 2026,
            month: 10,
            imageName: 'one.jpg',
            maxWidth: 480,
          ),
        ),
        '3',
      );
    });

    test('超过七天先显示图片，后台更新失败不删除旧图', () async {
      var offline = false;
      var requests = 0;
      final client = _api(cache, (_) async {
        requests++;
        if (offline) throw const SocketException('offline');
        return http.Response.bytes(_bytes('photo'), 200);
      });
      Future<Uint8List> image() => client.fetchRenderedDiaryImage(
        year: 2026,
        month: 10,
        imageName: 'one.jpg',
        maxWidth: 480,
      );
      await image();
      clock = clock.add(const Duration(days: 8));
      offline = true;
      expect(utf8.decode(await image()), 'photo');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(requests, 2);
      expect((await cache.usage()).imageBytes, greaterThan(0));
    });

    test('明确图片404不从缓存回退，失败响应不落盘', () async {
      final online = _api(
        cache,
        (_) async => http.Response.bytes(_bytes('photo'), 200),
      );
      await online.fetchRenderedDiaryImage(
        year: 2026,
        month: 10,
        imageName: 'one.jpg',
        maxWidth: 480,
      );
      final missing = _api(cache, (_) async => http.Response('', 404));
      await expectLater(
        missing.fetchRenderedDiaryImage(
          year: 2026,
          month: 10,
          imageName: 'one.jpg',
          maxWidth: 480,
          forceRefresh: true,
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      expect((await cache.usage()).imageBytes, 0);
    });

    test('保存仅失效目标日记及索引，旧读取不能重新落盘', () async {
      final client = _api(
        cache,
        (request) async => _jsonResponse(
          request.method == 'POST'
              ? '{}'
              : jsonEncode(
                  _diary('existing', date: request.url.pathSegments.last),
                ),
          200,
        ),
      );
      await client.getDiary(DateTime(2026, 10, 5));
      await client.getDiary(DateTime(2026, 10, 6));
      final stale = cache.begin(
        ReadingCacheKind.data,
        client.readingCacheNamespace,
        '/api/v1/diary/2026-10-06',
      );
      await client.appendQuickNote(DateTime(2026, 10, 6), 'new');
      await cache.write(stale, _bytes(jsonEncode(_diary('old'))));
      expect(
        await cache.read(
          ReadingCacheKind.data,
          client.readingCacheNamespace,
          '/api/v1/diary/2026-10-06',
        ),
        isNull,
      );
      expect(
        await cache.read(
          ReadingCacheKind.data,
          client.readingCacheNamespace,
          '/api/v1/diary/2026-10-05',
        ),
        isNotNull,
      );
    });

    test('磁盘不可用仍能联网读取', () async {
      final unavailable = ReadingCacheRepository(
        directoryProvider: () async =>
            throw const FileSystemException('unavailable'),
      );
      final client = _api(
        unavailable,
        (_) async => _jsonResponse(jsonEncode(_diary('network')), 200),
      );
      expect(
        (await client.getDiary(DateTime(2026, 10, 6), onCached: (_) {}))!.raw,
        contains('network'),
      );
    });

    test('编辑前重新确认原始行，变化后不提交POST', () async {
      var posts = 0;
      final client = _api(cache, (request) async {
        if (request.method == 'POST') posts++;
        return _jsonResponse(jsonEncode(_diary('changed')), 200);
      });
      await expectLater(
        client.editEntry(
          DateTime(2026, 10, 6),
          section: 'quick_notes',
          target: '- **18:20** old',
          replacement: '- **18:20** new',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('重新确认'),
          ),
        ),
      );
      expect(posts, 0);
    });

    test('下载过程中清理，不回填磁盘，新访问重新请求', () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      var requests = 0;
      final client = _api(cache, (_) async {
        if (++requests == 1) {
          started.complete();
          return response.future;
        }
        return http.Response.bytes(_bytes('fresh'), 200);
      });
      Future<Uint8List> load() => client.fetchRenderedDiaryImage(
        year: 2026,
        month: 10,
        imageName: 'one.jpg',
        maxWidth: 480,
      );
      final pending = load();
      await started.future;
      await cache.clear(imagesOnly: true);
      response.complete(http.Response.bytes(_bytes('stale'), 200));
      await pending;
      expect((await cache.usage()).imageBytes, 0);
      expect(utf8.decode(await load()), 'fresh');
      expect(requests, 2);
    });

    test('旧404不能删除更新请求已经保存的新副本', () async {
      final stale = Completer<http.Response>();
      final started = Completer<void>();
      var requests = 0;
      final client = _api(cache, (_) async {
        if (++requests == 1) {
          started.complete();
          return stale.future;
        }
        return _jsonResponse(jsonEncode(_diary('new')), 200);
      });
      final first = client.getDiary(DateTime(2026, 10, 6));
      await started.future;
      await client.getDiary(DateTime(2026, 10, 6));
      stale.complete(http.Response('', 404));
      await first;
      final stored = await cache.read(
        ReadingCacheKind.data,
        client.readingCacheNamespace,
        '/api/v1/diary/2026-10-06',
      );
      expect(utf8.decode(stored!.bytes), contains('new'));
    });

    test('删除日记后，离线读取不能复活旧副本', () async {
      var status = 200;
      final client = _api(cache, (_) async {
        if (status == 0) throw const SocketException('offline');
        return _jsonResponse(jsonEncode(_diary('old')), status);
      });
      await client.getDiary(DateTime(2026, 10, 6));
      status = 404;
      expect(await client.getDiary(DateTime(2026, 10, 6)), isNull);
      status = 0;
      var usedCache = false;
      await expectLater(
        client.getDiary(
          DateTime(2026, 10, 6),
          onCached: (_) => usedCache = true,
          allowCachedFallback: true,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(usedCache, isFalse);
    });

    test('规范化连接地址复用同一命名空间', () {
      final first = _api(
        cache,
        (_) async => http.Response('', 404),
        baseUrl: 'https://CACHE.test:443/api/v1/',
      );
      final second = _api(
        cache,
        (_) async => http.Response('', 404),
        baseUrl: 'https://cache.test',
      );
      expect(first.readingCacheNamespace, second.readingCacheNamespace);
    });

    test('跨月且首页淘汰后，离线仍恢复已缓存的较早分页', () async {
      clock = DateTime(2026, 9, 30);
      var offline = false;
      final client = _api(cache, (request) async {
        if (offline) throw const SocketException('offline');
        final earlier = request.url.queryParameters['cursor'] != null;
        return _jsonResponse(
          jsonEncode({
            'months': [
              {
                'year': 2026,
                'month': earlier ? 6 : 9,
                'totalDays': 1,
                'totalImages': 1,
                'days': [
                  {
                    'date': earlier ? '2026-06-01' : '2026-09-01',
                    'images': ['one.jpg'],
                    'hasContent': true,
                  },
                ],
              },
            ],
            'nextCursor': earlier ? '2026-03' : '2026-06',
          }),
          200,
        );
      });
      await client.fetchGallery();
      await client.fetchGallery(cursor: '2026-06');
      clock = DateTime(2026, 10, 1);
      offline = true;
      final restored = await client.cachedGalleryPages().toList();
      expect(
        restored.expand((item) => item.value.months).map((m) => m.month),
        containsAll([9, 6]),
      );
      await cache.remove(
        ReadingCacheKind.data,
        '${client.readingCacheNamespace}/gallery',
        '/api/v1/history/gallery?limit=3|start=2026-09',
      );
      final remaining = await client.cachedGalleryPages().toList();
      expect(
        remaining.expand((item) => item.value.months).map((m) => m.month),
        contains(6),
      );
    });

    test('图墙内存命中也检查七天期限，后台404通知并移除旧图', () async {
      clock = DateTime(2026, 10, 7);
      var requests = 0;
      final client = _api(
        cache,
        (_) async => ++requests == 1
            ? http.Response.bytes(_bytes('old'), 200)
            : http.Response('', 404),
      );
      final images = GalleryImageCache();
      final missing = Completer<ApiException>();
      Future<Uint8List> load() => images.load(
        client,
        year: 2026,
        month: 10,
        imageName: 'one.jpg',
        maxWidth: 480,
        onRevalidated: (result) {
          if (result.error != null && !missing.isCompleted) {
            missing.complete(result.error);
          }
        },
      );
      await load();
      clock = clock.add(const Duration(days: 8));
      expect(utf8.decode(await load()), 'old');
      expect((await missing.future).statusCode, 404);
      await expectLater(load(), throwsA(isA<ApiException>()));
      expect(requests, 3);
    });

    test('后台已更新磁盘时，仍按编辑来源版本拦截旧提交', () async {
      var changed = false;
      var posts = 0;
      final original = _diary('old')['raw'] as String;
      final client = _api(cache, (request) async {
        if (request.method == 'POST') posts++;
        final json = _diary('old');
        if (changed) json['raw'] = '$original\n- **19:00** 新记录';
        return _jsonResponse(jsonEncode(json), 200);
      });
      await client.getDiary(DateTime(2026, 10, 6));
      changed = true;
      await client.getDiary(DateTime(2026, 10, 6));
      await expectLater(
        client.deleteEntry(
          DateTime(2026, 10, 6),
          section: 'quick_notes',
          line: '- **18:20** old',
          expectedRaw: original,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(posts, 0);
    });

    test('副本版本变化要求再次确认，即使目标行仍存在', () async {
      var text = 'old';
      var posts = 0;
      final client = _api(cache, (request) async {
        if (request.method == 'POST') posts++;
        final json = _diary(text);
        if (text == 'changed') {
          json['raw'] = '${_diary('old')['raw']}\n- **19:00** 新记录';
        }
        return _jsonResponse(jsonEncode(json), 200);
      });
      await client.getDiary(DateTime(2026, 10, 6));
      text = 'changed';
      await expectLater(
        client.deleteEntry(
          DateTime(2026, 10, 6),
          section: 'quick_notes',
          line: '- **18:20** old',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(posts, 0);
    });

    test('预热只读取最近七天存在的日记，并发不超过两个', () async {
      var active = 0;
      var maximum = 0;
      final readDates = <String>[];
      final client = _api(cache, (request) async {
        expect(request.method, 'GET');
        if (request.url.path.contains('/history/')) {
          return _jsonResponse(
            jsonEncode({
              'year': 2026,
              'month': 10,
              'diaries': [
                for (final day in [2, 3, 5, 6])
                  {'date': '2026-10-0$day', 'exists': true},
              ],
            }),
            200,
          );
        }
        active++;
        if (active > maximum) maximum = active;
        readDates.add(request.url.pathSegments.last);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        active--;
        return _jsonResponse(
          jsonEncode(_diary('warm', date: request.url.pathSegments.last)),
          200,
        );
      });
      await client.warmRecentDiaries(DateTime(2026, 10, 7));
      expect(maximum, 2);
      expect(
        readDates,
        unorderedEquals([
          '2026-10-02',
          '2026-10-03',
          '2026-10-05',
          '2026-10-06',
        ]),
      );
    });
  });

  testWidgets('离线历史正文立即显示，补录和正文修改不可用', (tester) async {
    final cache = _MemoryCache();
    final client = _api(
      cache,
      (_) async => throw const SocketException('offline'),
    );
    final key = '/api/v1/diary/2026-10-06';
    await cache.write(
      cache.begin(ReadingCacheKind.data, client.readingCacheNamespace, key),
      _bytes(jsonEncode(_diary('离线正文'))),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReadOnlyDiaryScreen(
          date: DateTime(2026, 10, 6),
          apiClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('离线正文'), findsOneWidget);
    expect(find.textContaining('正在显示本地内容'), findsOneWidget);
    final view = tester.widget<DiaryMarkdownView>(
      find.byType(DiaryMarkdownView),
    );
    expect(view.readOnly, isTrue);
    await tester.tap(
      find.byKey(const Key('historical_quick_record_fab')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('historical_quick_record_quick_note')),
      findsNothing,
    );
  });

  testWidgets('后台请求尚未返回时，本地正文已经可读', (tester) async {
    final cache = _MemoryCache();
    final network = Completer<http.Response>();
    final client = _api(
      cache,
      (request) async => request.url.path == '/api/v1/diary/2026-10-06'
          ? network.future
          : http.Response('{}', 404),
    );
    await cache.write(
      cache.begin(
        ReadingCacheKind.data,
        client.readingCacheNamespace,
        '/api/v1/diary/2026-10-06',
      ),
      _bytes(jsonEncode(_diary('立即出现的正文'))),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReadOnlyDiaryScreen(
          date: DateTime(2026, 10, 6),
          apiClient: client,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('立即出现的正文'), findsOneWidget);
    expect(find.textContaining('检查更新中'), findsOneWidget);
    network.complete(http.Response('', 503));
    await tester.pumpAndSettle();
    expect(find.textContaining('立即出现的正文'), findsOneWidget);
  });

  testWidgets('切换连接后，旧日期请求不能覆盖新连接正文', (tester) async {
    final oldResponse = Completer<http.Response>();
    final cache = _MemoryCache();
    final first = _api(
      cache,
      (request) async => request.url.path == '/api/v1/diary/2026-10-06'
          ? oldResponse.future
          : http.Response('{}', 404),
    );
    final second = _api(
      cache,
      (request) async => request.url.path == '/api/v1/diary/2026-10-06'
          ? _jsonResponse(jsonEncode(_diary('新连接正文')), 200)
          : http.Response('{}', 404),
      baseUrl: 'http://other.test',
    );
    Widget page(ApiClient client) => MaterialApp(
      home: ReadOnlyDiaryScreen(date: DateTime(2026, 10, 6), apiClient: client),
    );
    await tester.pumpWidget(page(first));
    await tester.pump();
    await tester.pumpWidget(page(second));
    await tester.pumpAndSettle();
    oldResponse.complete(_jsonResponse(jsonEncode(_diary('旧连接正文')), 200));
    await tester.pumpAndSettle();
    expect(find.textContaining('新连接正文'), findsOneWidget);
    expect(find.textContaining('旧连接正文'), findsNothing);
  });

  testWidgets('未缓存断网今天不调用创建，也不显示空日记', (tester) async {
    var creates = 0;
    final client = _api(_MemoryCache(), (request) async {
      if (request.method == 'POST') creates++;
      throw const SocketException('offline');
    });
    await tester.pumpWidget(MaterialApp(home: HomeScreen(apiClient: client)));
    await tester.pumpAndSettle();
    expect(creates, 0);
    expect(find.textContaining('此日记尚未缓存'), findsWidgets);
    expect(find.text('今日还没有日记内容'), findsNothing);
  });

  testWidgets('离线画廊恢复月份索引，保持首图与分页游标', (tester) async {
    final cache = _MemoryCache();
    final client = _api(
      cache,
      (_) async => throw const SocketException('offline'),
    );
    final now = DateTime.now();
    final cursor = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final key = '/api/v1/history/gallery?limit=3|start=$cursor';
    await cache.write(
      cache.begin(
        ReadingCacheKind.data,
        '${client.readingCacheNamespace}/gallery',
        key,
      ),
      _bytes(
        jsonEncode({
          'months': [
            {
              'year': 2026,
              'month': 9,
              'totalDays': 1,
              'totalImages': 2,
              'days': [
                {
                  'date': '2026-09-12',
                  'images': ['one.jpg', 'two.jpg'],
                  'hasContent': true,
                },
              ],
            },
          ],
          'nextCursor': '2026-06',
        }),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryImageTile), findsOneWidget);
    expect(find.text('2026年9月'), findsOneWidget);
    expect(find.textContaining('正在显示本地内容'), findsOneWidget);
  });

  testWidgets('离线月历保留纯文字标记，可进入已缓存正文', (tester) async {
    final cache = _MemoryCache();
    final client = _api(
      cache,
      (_) async => throw const SocketException('offline'),
    );
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, 1);
    final dateKey = ApiClient.formatDate(date);
    await cache.write(
      cache.begin(
        ReadingCacheKind.data,
        client.readingCacheNamespace,
        '/api/v1/history/${date.year}/${date.month}',
      ),
      _bytes(
        jsonEncode({
          'year': date.year,
          'month': date.month,
          'diaries': [
            {
              'date': dateKey,
              'exists': true,
              'hasContent': true,
              'hasImages': false,
            },
          ],
        }),
      ),
    );
    await cache.write(
      cache.begin(
        ReadingCacheKind.data,
        client.readingCacheNamespace,
        '/api/v1/diary/$dateKey',
      ),
      _bytes(jsonEncode(_diary('纯文字离线记录', date: dateKey))),
    );
    await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history_calendar_toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('history_calendar_marker_$dateKey')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(ValueKey('history_calendar_day_$dateKey')));
    await tester.pumpAndSettle();
    expect(find.textContaining('纯文字离线记录'), findsOneWidget);
  });

  testWidgets('刷新已加载旧月份的图片与统计，并移除已删除的月份内容', (tester) async {
    final cache = _MemoryCache();
    final now = DateTime.now();
    final earlier = DateTime(now.year, now.month - 3);
    final earlierCursor =
        '${earlier.year}-${earlier.month.toString().padLeft(2, '0')}';
    var version = 0;
    final client = _api(cache, (request) async {
      if (!request.url.path.endsWith('/gallery')) return http.Response('', 404);
      final old = request.url.queryParameters['cursor'] == earlierCursor;
      final month = old ? earlier : DateTime(now.year, now.month);
      return _jsonResponse(
        jsonEncode({
          'months': [
            {
              'year': month.year,
              'month': month.month,
              'totalDays': old && version == 2 ? 0 : 1,
              'totalImages': old
                  ? version == 2
                        ? 0
                        : version + 1
                  : 1,
              'days': old && version == 2
                  ? []
                  : [
                      {
                        'date': ApiClient.formatDate(month),
                        'images': [
                          'one.jpg',
                          if (old && version == 1) 'two.jpg',
                        ],
                        'hasContent': true,
                      },
                    ],
            },
          ],
          'nextCursor': old ? null : earlierCursor,
        }),
        200,
      );
    });
    await client.fetchGallery();
    await client.fetchGallery(cursor: earlierCursor);
    Widget page(bool active) => MaterialApp(
      home: PastScreen(apiClient: client, active: active),
    );
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    GalleryImageTile earlierTile() => tester
        .widgetList<GalleryImageTile>(find.byType(GalleryImageTile))
        .firstWhere((tile) => tile.day.date == ApiClient.formatDate(earlier));
    expect(earlierTile().day.images.length, 1);
    version = 1;
    await cache.invalidateData('${client.readingCacheNamespace}/gallery');
    await tester.pumpWidget(page(false));
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(earlierTile().day.images.length, 2);
    expect(find.text('1天 · 2张'), findsOneWidget);
    version = 2;
    await cache.invalidateData('${client.readingCacheNamespace}/gallery');
    await tester.pumpWidget(page(false));
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<GalleryImageTile>(find.byType(GalleryImageTile))
          .where((tile) => tile.day.date == ApiClient.formatDate(earlier)),
      isEmpty,
    );
  });

  for (final status in [401, 403, 404]) {
    testWidgets('过期图片后台$status后及时显示对应状态，不保留旧图', (tester) async {
      var clock = DateTime(2026, 10, 7);
      final cache = _MemoryCache(now: () => clock);
      final response = Completer<http.Response>();
      var requests = 0;
      final client = _api(
        cache,
        (_) async => ++requests == 1
            ? http.Response.bytes(
                base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jhWQAAAAASUVORK5CYII=',
                ),
                200,
              )
            : response.future,
      );
      await client.fetchRenderedDiaryImage(
        year: 2026,
        month: 10,
        imageName: 'one.jpg',
        maxWidth: 480,
      );
      clock = clock.add(const Duration(days: 8));
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 160,
            height: 160,
            child: GalleryImageTile(
              day: const GalleryDay(
                date: '2026-10-01',
                images: ['one.jpg'],
                hasContent: true,
              ),
              galleryService: GalleryService(client),
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      response.complete(http.Response('', status));
      await tester.pumpAndSettle();
      expect(find.text(status == 404 ? '图片不可用' : '认证失败，请检查连接'), findsOneWidget);
      expect(find.text('点击重试'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });
  }

  testWidgets('跨月重叠分页逐月保留最新索引，空月份不复活旧照片', (tester) async {
    var clock = DateTime(2026, 9, 30);
    var offline = false;
    final cache = _MemoryCache(now: () => clock);
    final client = _api(cache, (_) async {
      if (offline) throw const SocketException('offline');
      return _jsonResponse(
        jsonEncode({
          'months': [
            for (var offset = 0; offset < 3; offset++)
              {
                'year': 2026,
                'month': clock.month - offset,
                'totalDays': clock.month == 9 ? 1 : 0,
                'totalImages': clock.month == 9 ? 1 : 0,
                'days': clock.month == 9
                    ? [
                        {
                          'date':
                              '2026-${(clock.month - offset).toString().padLeft(2, '0')}-01',
                          'images': ['old.jpg'],
                          'hasContent': true,
                        },
                      ]
                    : [],
              },
          ],
          'nextCursor': '2026-${(clock.month - 3).toString().padLeft(2, '0')}',
        }),
        200,
      );
    });
    await client.fetchGallery();
    clock = DateTime(2026, 10, 1);
    await client.fetchGallery();
    clock = DateTime(2026, 11, 1);
    offline = true;
    await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
    await tester.pumpAndSettle();
    final dates = tester
        .widgetList<GalleryImageTile>(find.byType(GalleryImageTile))
        .map((tile) => tile.day.date);
    expect(dates, isNot(contains('2026-09-01')));
    expect(dates, isNot(contains('2026-08-01')));
    expect(dates, contains('2026-07-01'));
  });

  testWidgets('缓存管理深色窄屏放大字体不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: ReadingCachePage(repository: _MemoryCache()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('本地缓存'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('清除全部阅读缓存'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('缓存管理支持确认与取消，清图片保留正文', (tester) async {
    final cache = _MemoryCache();
    await cache.write(
      cache.begin(ReadingCacheKind.data, 'a', 'diary'),
      _bytes('body'),
    );
    await cache.write(
      cache.begin(ReadingCacheKind.image, 'a', 'image'),
      _bytes('image'),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReadingCachePage(repository: cache)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除图片缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect((await cache.usage()).imageBytes, greaterThan(0));
    await tester.tap(find.text('清除图片缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();
    expect((await cache.usage()).imageBytes, 0);
    expect((await cache.usage()).dataBytes, greaterThan(0));
  });

  test('清图片使画廊内存失效', () async {
    var requests = 0;
    final cache = _MemoryCache();
    final client = _api(
      cache,
      (_) async => http.Response.bytes(_bytes('${++requests}'), 200),
    );
    final images = GalleryImageCache();
    Future<Uint8List> load() => images.load(
      client,
      year: 2026,
      month: 10,
      imageName: 'one.jpg',
      maxWidth: 480,
    );
    await load();
    await load();
    expect(requests, 1);
    await cache.clear(imagesOnly: true);
    await load();
    expect(requests, 2);
  });
}

/// Widget 测试不依赖真实 IO 时钟；磁盘行为由上面的真实目录测试覆盖。
class _MemoryCache extends ReadingCacheRepository {
  final Map<String, CachedBytes> _entries = {};
  _MemoryCache({super.now});
  @override
  Future<CachedBytes?> read(
    ReadingCacheKind kind,
    String namespace,
    String key,
  ) async =>
      _entries['${kind.name}/${ReadingCacheRepository.digest(namespace)}-${ReadingCacheRepository.digest(key)}.cache'];
  @override
  Future<void> write(CacheWriteTicket ticket, Uint8List bytes) async {
    if (isCurrent(ticket)) {
      _entries[ticket.name] = CachedBytes(bytes, now());
    }
  }

  @override
  Future<void> remove(
    ReadingCacheKind kind,
    String namespace,
    String key,
  ) async => _entries.remove(begin(kind, namespace, key).name);
  @override
  Future<void> invalidateData(String namespace) async {
    dataGeneration++;
    final prefix = 'data/${ReadingCacheRepository.digest(namespace)}-';
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<void> clear({bool imagesOnly = false}) async {
    imageGeneration++;
    if (!imagesOnly) dataGeneration++;
    _entries.removeWhere((key, _) => !imagesOnly || key.startsWith('image/'));
  }

  @override
  Future<ReadingCacheUsage> usage() async => ReadingCacheUsage(
    _entries.entries
        .where((entry) => entry.key.startsWith('data/'))
        .fold(0, (sum, entry) => sum + entry.value.bytes.length),
    _entries.entries
        .where((entry) => entry.key.startsWith('image/'))
        .fold(0, (sum, entry) => sum + entry.value.bytes.length),
  );
}
