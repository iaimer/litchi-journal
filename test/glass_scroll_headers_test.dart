import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:litchi_journal_flutter/screens/past_screen.dart';
import 'package:litchi_journal_flutter/screens/habit_stats_screen.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/habit_settings_repository.dart';
import 'package:litchi_journal_flutter/services/habit_trend_cache_repository.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';

void main() {
  testWidgets('过往标题置顶，图墙进入同一视口的标题背后', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(PastScreen(apiClient: _client())));
    await tester.pumpAndSettle();

    final scroll = find.byType(CustomScrollView);
    expect(tester.getRect(scroll).top, 0);
    final titleRect = tester.getRect(find.text('过往'));
    final tile = find.byKey(const ValueKey('2024-03-01-photo-1.png'));
    final initialTileRect = tester.getRect(tile);
    final sample = Offset(
      initialTileRect.center.dx,
      _headerRect(tester).bottom - 12,
    );
    final before = await _pixelAt(tester, sample);
    final view = tester.widget<CustomScrollView>(scroll);
    view.controller!.jumpTo(125);
    await tester.pumpAndSettle();

    final header = _headerRect(tester);
    expect(tester.getRect(find.text('过往')), titleRect);
    expect(tester.getRect(tile).top, closeTo(initialTileRect.top - 125, 0.5));
    expect(tester.getRect(tile).overlaps(header), isTrue);
    _expectHeaderPaintedLast(tester);
    final after = await _pixelAt(tester, sample);
    expect(after.b - after.r, greaterThan(before.b - before.r + 20 / 255));
    expect(tester.takeException(), isNull);
  });

  testWidgets('习惯标题置顶，指标能滚入标题背后且刷新保留内容', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _MemoryStorage();
    await tester.pumpWidget(
      _app(
        HabitStatsScreen(
          apiClient: _client(),
          habitSettingsRepo: HabitSettingsRepository(storage: storage),
          trendCacheRepo: HabitTrendCacheRepository(storage: storage),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scroll = find.byType(CustomScrollView);
    expect(scroll, findsOneWidget);
    expect(tester.getRect(scroll).top, 0);
    final titleRect = tester.getRect(find.text('习惯趋势'));
    final metric = find.byKey(const ValueKey('habit_metric_reading'));
    final initialMetricRect = tester.getRect(metric);
    final sample = Offset(
      initialMetricRect.right - 12,
      _headerRect(tester).bottom - 8,
    );
    final before = await _pixelAt(tester, sample);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(initialMetricRect.top - titleRect.top);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('习惯趋势')), titleRect);
    expect(tester.getRect(metric).overlaps(_headerRect(tester)), isTrue);
    _expectHeaderPaintedLast(tester);
    final after = await _pixelAt(tester, sample);
    final difference =
        (before.r - after.r).abs() +
        (before.g - after.g).abs() +
        (before.b - after.b).abs();
    expect(difference, greaterThan(0.03));
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    expect(refresh.edgeOffset, closeTo(_headerRect(tester).height, 0.5));
    final offset = position.pixels;
    final future = refresh.onRefresh();
    await tester.pump();
    expect(metric, findsOneWidget);
    await future;
    await tester.pumpAndSettle();
    expect(position.pixels, offset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      testWidgets('过往日历自然展开和收起：深色=$dark，高对比=$highContrast', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(
            PastScreen(apiClient: _client()),
            dark: dark,
            highContrast: highContrast,
          ),
        );
        await tester.pumpAndSettle();

        final title = tester.getRect(find.text('过往'));
        final collapsed = _headerRect(tester);
        final controller = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!;
        controller.jumpTo(125);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('history_calendar_toggle')));
        await tester.pumpAndSettle();

        final expanded = _headerRect(tester);
        final calendar = tester.getRect(
          find.byKey(const Key('history_calendar')),
        );
        expect(expanded.height, greaterThan(collapsed.height + 300));
        expect(calendar.bottom, lessThanOrEqualTo(expanded.bottom));
        expect(expanded.bottom, lessThan(720));
        expect(tester.getRect(find.text('过往')), title);
        expect(controller.offset, 125);
        expect(
          tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .edgeOffset,
          closeTo(expanded.height, 0.5),
        );

        await tester.tap(find.byKey(const Key('history_calendar_toggle')));
        await tester.pumpAndSettle();
        expect(_headerRect(tester), collapsed);
        expect(controller.offset, 125);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('月份跳转定位在实际头部下方，展开日历后仍正确', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(PastScreen(apiClient: _client())));
    await tester.pumpAndSettle();

    for (final expanded in [false, true]) {
      if (expanded) {
        await tester.tap(find.byKey(const Key('history_calendar_toggle')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('gallery_previous_month')));
      await tester.pumpAndSettle();
      final month = find.text('2024年2月').last;
      expect(
        tester.getRect(month).top,
        greaterThanOrEqualTo(_headerRect(tester).bottom),
      );
      expect(
        tester.getRect(month).top,
        lessThan(_headerRect(tester).bottom + 40),
      );
      await tester.tap(find.byKey(const Key('gallery_next_month')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('gallery_month_picker')),
          matching: find.text('2024年3月'),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('画廊控制器继续分页，刷新保留旧图墙及滚动位置', (tester) async {
    final requests = <Uri>[];
    final pending = Completer<http.Response>();
    await tester.pumpWidget(
      _app(
        PastScreen(
          apiClient: _client(
            requests: requests,
            paginate: true,
            galleryRefresh: pending,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    await tester.drag(
      find.byType(CustomScrollView),
      Offset(0, -controller.position.maxScrollExtent),
    );
    await tester.pumpAndSettle();
    expect(
      requests
          .where((uri) => uri.path == '/api/v1/history/gallery')
          .map((uri) => uri.queryParameters['cursor']),
      [null, '2024-02'],
    );
    final offset = controller.offset;
    final future = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    expect(find.text('2024年2月'), findsWidgets);
    expect(
      find.byType(LinearProgressIndicator, skipOffstage: false),
      findsOneWidget,
    );
    pending.complete(
      _json({
        'months': [_month(3), _month(2)],
        'nextCursor': null,
      }),
    );
    await future;
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(offset, 0.5));
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget home, {bool dark = false, bool highContrast = false}) =>
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 24),
          textScaler: const TextScaler.linear(1.3),
          highContrast: highContrast,
        ),
        child: RepaintBoundary(
          key: const Key('scroll_header_capture'),
          child: child!,
        ),
      ),
      home: home,
    );

Future<Color> _pixelAt(WidgetTester tester, Offset point) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('scroll_header_capture')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    final color = Color.fromARGB(
      255,
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
    image.dispose();
    return color;
  }))!;
}

Rect _headerRect(WidgetTester tester) {
  final header = tester.widget<PinnedHeaderSliver>(
    find.byType(PinnedHeaderSliver),
  );
  return tester.getRect(find.byWidget(header.child!));
}

void _expectHeaderPaintedLast(WidgetTester tester) {
  final viewport = tester.renderObject<RenderViewport>(find.byType(Viewport));
  expect(viewport.paintOrder, SliverPaintOrder.firstIsTop);
}

ApiClient _client({
  List<Uri>? requests,
  bool paginate = false,
  Completer<http.Response>? galleryRefresh,
}) {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(30, 120, 230));
  final imageBytes = img.encodePng(image);
  var galleryRequests = 0;
  final client = ApiClient(
    ApiConfig(baseUrl: 'https://test.local', token: 'test'),
    httpClient: _HeaderHttpClient((request) async {
      expect(request.method, 'GET');
      requests?.add(request.url);
      if (request.url.path.startsWith('/api/v1/diary/image/render/')) {
        return http.Response.bytes(
          imageBytes,
          200,
          headers: {'content-type': 'image/png'},
        );
      }
      if (request.url.path == '/api/v1/history/gallery') {
        galleryRequests++;
        final cursor = request.url.queryParameters['cursor'];
        if (galleryRequests > 1 && cursor == null && galleryRefresh != null) {
          return galleryRefresh.future;
        }
        if (paginate) {
          return _json({
            'months': [_month(cursor == null ? 3 : 2)],
            'nextCursor': cursor == null ? '2024-02' : null,
          });
        }
        return _json({
          'months': [_month(3), _month(2)],
          'nextCursor': null,
        });
      }
      if (request.url.path == '/api/v1/stats/habit') {
        return _json([
          {
            'date': request.url.queryParameters['from'],
            'hasDiary': true,
            'water': 0,
            'steps': 0,
            'reading': true,
            'readingMinutes': 30,
            'language': false,
            'supplements': false,
            'customCheckboxes': {},
            'customDurations': {},
          },
        ]);
      }
      return _json({'diaries': []});
    }),
  );
  addTearDown(client.dispose);
  return client;
}

Map<String, Object> _month(int month) => {
  'year': 2024,
  'month': month,
  'totalDays': 24,
  'totalImages': 24,
  'days': [
    for (var day = 1; day <= 24; day++)
      {
        'date':
            '2024-${month.toString().padLeft(2, '0')}-'
            '${day.toString().padLeft(2, '0')}',
        'images': ['photo-$day.png'],
        'hasContent': true,
      },
  ],
};

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _MemoryStorage implements HabitSettingsStorage, HabitTrendCacheStorage {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _HeaderHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest) respond;

  _HeaderHttpClient(this.respond);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await respond(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
