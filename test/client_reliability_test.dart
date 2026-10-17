import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/models/default_tag_config.dart';
import 'package:litchi_journal_flutter/models/focus_timer.dart';
import 'package:litchi_journal_flutter/models/habit_trend.dart';
import 'package:litchi_journal_flutter/models/image_upload_item.dart';
import 'package:litchi_journal_flutter/models/image_settings.dart';
import 'package:litchi_journal_flutter/screens/focus_timer_screen.dart';
import 'package:litchi_journal_flutter/screens/image_compress_page.dart';
import 'package:litchi_journal_flutter/screens/quick_capture_screen.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/draft_repository.dart';
import 'package:litchi_journal_flutter/services/focus_timer_controller.dart';
import 'package:litchi_journal_flutter/services/focus_timer_repository.dart';
import 'package:litchi_journal_flutter/services/image_settings_repository.dart';
import 'package:litchi_journal_flutter/services/habit_trend_cache_repository.dart';
import 'package:litchi_journal_flutter/services/failure_messages.dart';
import 'package:litchi_journal_flutter/services/past_memory_service.dart';
import 'package:litchi_journal_flutter/services/reading_cache_repository.dart';
import 'package:litchi_journal_flutter/widgets/entry_type.dart';
import 'package:litchi_journal_flutter/widgets/image_section_card.dart';
import 'package:litchi_journal_flutter/widgets/image_upload_strip.dart';

class _DraftStorage implements DraftStorage {
  final Completer<String?> restored = Completer();
  int writes = 0;
  String? value;
  bool failDelete = false;
  @override
  Future<String?> read(String key) => restored.future;
  @override
  Future<void> write(String key, String value) async {
    writes++;
    this.value = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('unavailable');
    value = null;
  }
}

class _TrendStorage implements HabitTrendCacheStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _ImageStorage implements ImageSettingsStorage {
  bool fail = true;
  @override
  Future<String?> read(String key) async =>
      jsonEncode(ImageSettings(maxLongSidePx: 2560).toJson());
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('unavailable');
  }

  @override
  Future<void> delete(String key) async {}
}

class _TimerStorage implements FocusTimerStorage {
  String? value;
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String value) async => this.value = value;
  @override
  Future<void> delete(String key) async => value = null;
}

Widget _capture(_DraftStorage storage) => MaterialApp(
  home: QuickCaptureScreen(
    entryType: EntryType.quickNote,
    openedAt: DateTime(2026, 10, 18, 8),
    recordDate: DateTime(2026, 10, 18),
    tagConfig: DefaultTagConfig.value,
    draftRepository: DraftRepository(storage: storage),
    onSave: (_) async {},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final status in [400, 401, 403, 409, 500]) {
    test('write preserves HTTP $status instead of returning false', () async {
      final api = ApiClient(
        ApiConfig(baseUrl: 'https://fixture.invalid', token: 'fixture'),
        httpClient: MockClient(
          (_) async => http.Response('private server detail', status),
        ),
      );
      await expectLater(
        api.appendQuickNote(DateTime(2026, 10, 18), '正文'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', status)
              .having(
                (e) => e.message.contains('private server detail'),
                'redacted',
                false,
              ),
        ),
      );
      api.dispose();
    });
  }

  test('trend connection identity includes credential digest', () {
    final first = ApiClient(
      ApiConfig(baseUrl: 'https://fixture.invalid', token: 'first'),
    );
    final second = ApiClient(
      ApiConfig(baseUrl: 'https://fixture.invalid', token: 'second'),
    );
    expect(first.cacheNamespace, isNot(second.cacheNamespace));
    expect(first.cacheNamespace, first.readingCacheNamespace);
    first.dispose();
    second.dispose();
  });

  test('write preserves visited gallery cursors across restart', () async {
    final dir = await Directory.systemTemp.createTemp('litchi-manifest-write-');
    addTearDown(() => dir.delete(recursive: true));
    final cache = ReadingCacheRepository(directoryProvider: () async => dir);
    final api = ApiClient(
      ApiConfig(baseUrl: 'https://fixture.invalid', token: 'fixture'),
      readingCache: cache,
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.method == 'POST'
                ? {'success': true}
                : {'months': [], 'nextCursor': null, 'hasMore': false},
          ),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await api.fetchGallery(cursor: '2024-01');
    await api.fetchGallery();
    await api.appendQuickNote(DateTime(2026, 10, 18), '正文');
    final next = ReadingCacheRepository(directoryProvider: () async => dir);
    final namespaces = [
      '${api.readingCacheNamespace}/gallery',
      '${api.readingCacheNamespace}/gallery-visits',
    ];
    final entries = await Future.wait(
      namespaces.map(
        (ns) =>
            next.read(ReadingCacheKind.data, ns, 'visited-gallery-pages-v1'),
      ),
    );
    expect(
      entries.whereType<CachedBytes>().any(
        (entry) => utf8.decode(entry.bytes).contains('2024-01'),
      ),
      true,
    );
    final restarted = ApiClient(
      ApiConfig(baseUrl: 'https://fixture.invalid', token: 'fixture'),
      readingCache: next,
      httpClient: MockClient((_) async => http.Response('', 500)),
    );
    expect(await restarted.cachedGalleryPages().toList(), isEmpty);
    final starts = await restarted.visitedGalleryPageStarts();
    expect(starts, contains('2024-01'));
    final now = DateTime.now();
    expect(
      starts,
      contains('${now.year}-${now.month.toString().padLeft(2, '0')}'),
    );
    await next.clear();
    expect(await restarted.visitedGalleryPageStarts(), isEmpty);
    restarted.dispose();
    api.dispose();
  });

  testWidgets(
    'late draft cannot overwrite newly typed text and writes are debounced',
    (tester) async {
      final storage = _DraftStorage();
      await tester.pumpWidget(_capture(storage));
      await tester.enterText(find.byType(TextField).first, '正在输入');
      storage.restored.complete(
        jsonEncode(
          QuickDraft(
            content: '旧草稿',
            tags: [],
            updatedAt: DateTime.now(),
          ).toJson(),
        ),
      );
      await tester.pump();
      expect(find.text('正在输入'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '继续输入一');
      await tester.enterText(find.byType(TextField).first, '继续输入二');
      await tester.pump(const Duration(milliseconds: 200));
      expect(storage.writes, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(storage.writes, 1);
      expect(storage.value, contains('继续输入二'));
    },
  );

  testWidgets('leaving flushes pending input without renewing an idle draft', (
    tester,
  ) async {
    final storage = _DraftStorage();
    storage.restored.complete(null);
    await tester.pumpWidget(_capture(storage));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '待离开保存');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(storage.writes, 1);

    final idleStorage = _DraftStorage();
    idleStorage.restored.complete(null);
    await tester.pumpWidget(_capture(idleStorage));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '已防抖保存');
    await tester.pump(const Duration(milliseconds: 500));
    expect(idleStorage.writes, 1);
    await tester.pump(const Duration(minutes: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(idleStorage.writes, 1);
  });

  testWidgets('draft read failure does not leave restoration stuck', (
    tester,
  ) async {
    final storage = _DraftStorage();
    await tester.pumpWidget(_capture(storage));
    storage.restored.completeError(StateError('unavailable'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).first, '仍可记录');
    await tester.pump(const Duration(milliseconds: 500));
    expect(storage.writes, 1);
  });

  testWidgets('image settings storage failure restores save interaction', (
    tester,
  ) async {
    final storage = _ImageStorage();
    await tester.pumpWidget(
      MaterialApp(
        home: ImageCompressPage(
          repository: ImageSettingsRepository(storage: storage),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('保存中...'), findsNothing);
    expect(find.textContaining('保存失败'), findsOneWidget);
    storage.fail = false;
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    final field = find.byType(DropdownButtonFormField<int>).first;
    expect(
      tester.state<FormFieldState<int>>(field).value,
      ImageSettings.defaultMaxLongSidePx,
    );
  });

  test(
    'same server with different credentials cannot read prior trend cache',
    () async {
      final storage = _TrendStorage();
      final first = ApiClient(
        ApiConfig(baseUrl: 'https://identity.invalid', token: 'fixture-one'),
      );
      final second = ApiClient(
        ApiConfig(baseUrl: 'https://identity.invalid', token: 'fixture-two'),
      );
      final period = HabitTrendPeriod.forAnchor(
        HabitTrendRange.month,
        DateTime(2026, 10, 18),
      );
      final firstRepo = HabitTrendCacheRepository(
        storage: storage,
        namespace: first.cacheNamespace,
      );
      final secondRepo = HabitTrendCacheRepository(
        storage: storage,
        namespace: second.cacheNamespace,
      );
      await firstRepo.save(
        HabitTrendStats(
          period: period,
          sourceDays: const [],
          items: const [],
          settingsSignature: 'first-account',
        ),
      );
      expect(
        (await firstRepo.load(period))?.settingsSignature,
        'first-account',
      );
      expect(await secondRepo.load(period), isNull);
      expect(
        storage.values.keys.any((key) => key.contains('fixture-one')),
        false,
      );
      first.dispose();
      second.dispose();
    },
  );

  for (final status in [401, 409, 500]) {
    testWidgets(
      'save HTTP $status keeps input and offers a classified action',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: QuickCaptureScreen(
              entryType: EntryType.quickNote,
              openedAt: DateTime(2026, 10, 18),
              tagConfig: DefaultTagConfig.value,
              onSave: (_) async =>
                  throw ApiException('private detail', statusCode: status),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField).first, '保留未保存的文字');
        await tester.pump();
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(find.text('保留未保存的文字'), findsOneWidget);
        expect(
          find.text(writeFailureMessage(ApiException('', statusCode: status))),
          findsOneWidget,
        );
        expect(find.textContaining('private detail'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'draft cleanup failure does not turn a saved entry into failure',
    (tester) async {
      final storage = _DraftStorage()..failDelete = true;
      storage.restored.complete(null);
      var saved = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: QuickCaptureScreen(
            entryType: EntryType.quickNote,
            openedAt: DateTime(2026, 10, 18),
            recordDate: DateTime(2026, 10, 18),
            tagConfig: DefaultTagConfig.value,
            draftRepository: DraftRepository(storage: storage),
            onSave: (_) async => saved++,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '已保存文字');
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved, 1);
      expect(find.byKey(const Key('quick_capture_error')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'body images request bounded thumbnails and load preview separately',
    (tester) async {
      final widths = <String?>[];
      final bytes = img.encodePng(img.Image(width: 16, height: 16));
      final api = ApiClient(
        ApiConfig(baseUrl: 'https://images.invalid', token: 'fixture'),
        httpClient: MockClient((request) async {
          expect(request.url.path, contains('/render/'));
          widths.add(request.url.queryParameters['maxWidth']);
          return http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryImageThumbnail(
              size: 100,
              index: 0,
              filename: 'photo.jpg',
              apiClient: api,
              date: DateTime(2026, 10, 18),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(widths, ['480']);
      final thumbnail = tester.widget<Image>(find.byType(Image));
      expect((thumbnail.image as ResizeImage).width, lessThanOrEqualTo(480));
      await tester.tap(find.byType(DiaryImageThumbnail));
      await tester.pumpAndSettle();
      expect(widths, ['480', '1600']);
      final preview = tester.widgetList<Image>(find.byType(Image)).last;
      expect((preview.image as ResizeImage).width, 1600);
      api.dispose();
    },
  );

  testWidgets('upload preview decodes for its display size', (tester) async {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 16, height: 16)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageUploadStrip(
            items: [
              ImageUploadItem(
                id: 'local',
                file: XFile.fromData(bytes, name: 'photo.png'),
              ),
            ],
            onRetry: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as ResizeImage).width, lessThanOrEqualTo(1024));
    expect((image.image as ResizeImage).width, isPositive);
  });

  test(
    'memory service reuses parsed entries until a write or expiry',
    () async {
      var reads = 0;
      var clock = DateTime(2026, 10, 18);
      final api = ApiClient(
        ApiConfig(baseUrl: 'https://memories.invalid', token: 'fixture'),
        readingCache: ReadingCacheRepository(enabled: false, now: () => clock),
        httpClient: MockClient((request) async {
          if (request.method == 'POST') return http.Response('{}', 200);
          reads++;
          return http.Response(
            jsonEncode({
              'date': '2025-10-18',
              'raw': '## ✍️ 随手记 & 灵感\n- **08:00** 有内容',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final service = PastMemoryService(api);
      expect(await service.getTodayHistory(), isNotNull);
      expect(await service.getTodayHistory(), isNotNull);
      expect(reads, 1);
      await api.appendQuickNote(DateTime(2026, 10, 18), '新内容');
      expect(await service.getTodayHistory(), isNotNull);
      expect(reads, 2);
      clock = clock.add(const Duration(minutes: 6));
      await service.getTodayHistory();
      expect(reads, 3);
      api.dispose();
    },
  );

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('timer remains scrollable at $size and large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = FocusTimerController(
        repository: FocusTimerRepository(storage: _TimerStorage()),
      );
      await controller.start(
        HabitTimerTarget(
          habitKey: 'reading',
          displayName: '亲子共读',
          markdownLabel: '阅读',
          icon: 'habit-read',
          colorArgb: 0xFF7BA67A,
          diaryDate: DateTime(2026, 10, 18),
          rawLine: '',
          currentMinutes: 0,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: FocusTimerScreen(
            controller: controller,
            onSave: (_, _) async => true,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('完成'));
      expect(find.text('完成').hitTestable(), findsOneWidget);
      controller.dispose();
    });
  }
}
