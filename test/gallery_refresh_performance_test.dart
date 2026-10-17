import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/models/diary_entry.dart';
import 'package:litchi_journal_flutter/models/gallery_result.dart';
import 'package:litchi_journal_flutter/screens/past_screen.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/reading_cache_repository.dart';
import 'package:litchi_journal_flutter/widgets/gallery_image_tile.dart';

class _GalleryApi extends ApiClient {
  final List<String> starts;
  final pending = <String, Completer<GalleryPage>>{};
  final requested = <String>[];
  int active = 0;
  int maximumActive = 0;

  _GalleryApi(this.starts)
    : super(
        ApiConfig(baseUrl: 'https://gallery.invalid', token: 'fixture'),
        httpClient: MockClient((_) async => http.Response('', 404)),
        readingCache: ReadingCacheRepository(enabled: true),
      );

  @override
  Future<DiaryEntry?> getDiary(
    DateTime date, {
    void Function(CachedReading<DiaryEntry>)? onCached,
    bool allowCachedFallback = false,
  }) async => null;
  @override
  Future<List<String>> visitedGalleryPageStarts() async => starts;
  @override
  Stream<CachedReading<GalleryPage>> cachedGalleryPages() =>
      const Stream.empty();
  @override
  Future<GalleryPage> fetchGallery({
    String? cursor,
    int limit = 3,
    void Function(CachedReading<GalleryPage>)? onCached,
  }) async {
    if (cursor == null) return const GalleryPage(months: []);
    requested.add(cursor);
    active++;
    if (active > maximumActive) maximumActive = active;
    final result = Completer<GalleryPage>();
    pending[cursor] = result;
    try {
      return await result.future;
    } finally {
      active--;
    }
  }

  void finish(
    String cursor, [
    GalleryPage page = const GalleryPage(months: []),
  ]) {
    final task = pending[cursor];
    if (task != null && !task.isCompleted) task.complete(page);
  }

  @override
  void dispose() {
    for (final cursor in pending.keys) {
      finish(cursor);
    }
    super.dispose();
  }
}

GalleryPage _june(String image) => GalleryPage(
  months: [
    GalleryMonth(
      year: 2026,
      month: 6,
      totalDays: 1,
      totalImages: 1,
      days: [
        GalleryDay(date: '2026-06-01', images: [image], hasContent: true),
      ],
    ),
  ],
);

Future<void> _open(WidgetTester tester, _GalleryApi api) async {
  await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: api)));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'six visited pages refresh in two waves with at most three concurrent requests',
    (tester) async {
      final api = _GalleryApi([
        '2026-08',
        '2026-05',
        '2026-02',
        '2025-11',
        '2025-08',
        '2025-05',
      ]);
      addTearDown(api.dispose);
      await _open(tester, api);
      expect(api.requested, ['2026-08', '2026-05', '2026-02']);
      expect(api.maximumActive, 3);
      for (final cursor in api.requested.toList()) {
        api.finish(cursor);
      }
      await tester.pump();
      await tester.pump();
      expect(api.requested, api.starts);
      expect(api.maximumActive, 3);
      for (final cursor in api.requested.toList()) {
        api.finish(cursor);
      }
      await tester.pumpAndSettle();
      expect(api.active, 0);
      expect(api.requested.toSet().length, 6);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'out-of-order responses preserve the existing merge order of overlapping months',
    (tester) async {
      final api = _GalleryApi(['2026-08', '2026-07', '2026-06']);
      addTearDown(api.dispose);
      await _open(tester, api);
      expect(api.requested.length, 3);
      api.finish('2026-06', _june('new.jpg'));
      api.finish('2026-07');
      await tester.pump();
      api.finish('2026-08', _june('old.jpg'));
      await tester.pumpAndSettle();
      final dates = tester.widgetList<GalleryImageTile>(
        find.byType(GalleryImageTile),
      );
      expect(dates.length, 1);
      expect(find.byKey(const ValueKey('2026-06-01-new.jpg')), findsOneWidget);
      expect(find.byKey(const ValueKey('2026-06-01-old.jpg')), findsNothing);
    },
  );

  testWidgets(
    'authentication failure stops scheduling the remaining visited pages',
    (tester) async {
      final api = _GalleryApi(['2026-08', '2026-05', '2026-02', '2025-11']);
      addTearDown(api.dispose);
      await _open(tester, api);
      api.pending['2026-08']!.completeError(
        const ApiException('认证失败', statusCode: 401),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('认证失败，请检查连接设置后重试'), findsOneWidget);
      for (final cursor in api.requested.toList()) {
        api.finish(cursor, _june('old.jpg'));
      }
      await tester.pumpAndSettle();
      expect(api.requested, isNot(contains('2025-11')));
      expect(find.byType(GalleryImageTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving during a refresh prevents subsequent batches and old UI updates',
    (tester) async {
      final api = _GalleryApi(['2026-08', '2026-05', '2026-02', '2025-11']);
      addTearDown(api.dispose);
      await _open(tester, api);
      await tester.pumpWidget(const SizedBox());
      for (final cursor in api.requested.toList()) {
        api.finish(cursor);
      }
      await tester.pump();
      expect(api.requested, isNot(contains('2025-11')));
      expect(tester.takeException(), isNull);
    },
  );
}
