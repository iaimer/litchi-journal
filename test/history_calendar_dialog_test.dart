import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/screens/past_screen.dart';
import 'package:litchi_journal_flutter/screens/read_only_diary_screen.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_dock.dart';
import 'package:litchi_journal_flutter/widgets/flora_primary_header.dart';
import 'package:litchi_journal_flutter/widgets/flora_page_route.dart';
import 'package:litchi_journal_flutter/widgets/gallery_image_tile.dart';

void main() {
  testWidgets('日历居中弹出且不推开图墙，点击外部后回到原位置', (tester) async {
    final requests = <http.Request>[];
    final client = _client(withGallery: true, onRequest: requests.add);
    addTearDown(client.dispose);
    await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
    await tester.pumpAndSettle();
    final gallery = find.byType(CustomScrollView);
    final scroll = tester.widget<CustomScrollView>(gallery).controller!;
    scroll.jumpTo(240);
    await tester.pumpAndSettle();
    final headerRect = tester.getRect(find.text('过往'));
    final tileRect = tester.getRect(find.byType(GalleryImageTile).first);
    final offset = scroll.offset;

    await tester.tap(find.byKey(const Key('history_calendar_toggle')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    final calendar = find.byKey(const Key('history_calendar'));
    final screen = tester.getSize(find.byType(Scaffold).first);
    expect(tester.getCenter(calendar).dx, closeTo(screen.width / 2, 1));
    expect(tester.getCenter(calendar).dy, closeTo(screen.height / 2, 1));
    expect(tester.getRect(find.text('过往', skipOffstage: false)), headerRect);
    expect(scroll.offset, offset);
    expect(tester.getRect(find.byType(GalleryImageTile).first), tileRect);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(calendar, findsNothing);
    expect(scroll.offset, offset);
    expect(
      requests.where((request) => request.url.path.endsWith('/gallery')),
      hasLength(1),
    );
  });

  testWidgets('从当前图墙月份选日期进入详情，返回不重载且浏览不写入', (tester) async {
    final requests = <http.Request>[];
    final client = _client(withGallery: true, onRequest: requests.add);
    addTearDown(client.dispose);
    await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history_calendar_toggle')));
    await tester.pumpAndSettle();
    final day = find.byKey(const Key('history_calendar_day_2024-03-08'));
    expect(day, findsOneWidget);
    final dayRect = tester.getRect(day);
    await tester.tap(day);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(
      tester.widget<ReadOnlyDiaryScreen>(find.byType(ReadOnlyDiaryScreen)).date,
      DateTime(2024, 3, 8),
    );
    final route =
        ModalRoute.of(tester.element(find.byType(ReadOnlyDiaryScreen)))
            as FloraPageRoute;
    expect(route.origin?.rect, dayRect);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('过往'), findsOneWidget);
    expect(requests.every((request) => request.method == 'GET'), isTrue);
    expect(
      requests.where((request) => request.url.path.endsWith('/gallery')),
      hasLength(1),
    );
  });

  for (final dark in [false, true]) {
    testWidgets('只模糊 Banner 与 Dock 之间的图墙，复用玻璃强度 dark=$dark', (tester) async {
      final client = _client();
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: FloraDockScope(
            clearance: 164,
            fabBottom: 92,
            child: PastScreen(apiClient: client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = tester.getRect(find.byType(FloraPrimaryHeader));
      await tester.tap(find.byKey(const Key('history_calendar_toggle')));
      await tester.pumpAndSettle();
      final backdrop = find.byKey(const Key('history_calendar_backdrop'));
      final bounds = tester.getRect(backdrop);
      expect(bounds.top, header.bottom);
      expect(bounds.bottom, 520);
      final blur = tester.widget<BackdropFilter>(
        find.descendant(of: backdrop, matching: find.byType(BackdropFilter)),
      );
      expect(
        blur.filter,
        ui.ImageFilter.blur(
          sigmaX: FloraGlass.blurSigma,
          sigmaY: FloraGlass.blurSigma,
        ),
      );
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      // 点击原来的入口只能关闭遮罩，不能穿透后重新打开。
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('history_calendar_toggle'))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(backdrop, findsNothing);
    });
  }

  testWidgets('日历从真实入口展开并沿同一路径收回', (tester) async {
    final client = _client();
    addTearDown(client.dispose);
    await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
    await tester.pumpAndSettle();
    final trigger = tester.getRect(
      find.byKey(const Key('history_calendar_toggle')),
    );
    await tester.tap(find.byKey(const Key('history_calendar_toggle')));
    await tester.pump();
    final calendar = find.byKey(const Key('history_calendar'));
    final first = _paintedRect(tester, calendar);
    expect((first.center - trigger.center).distance, lessThan(1));
    await tester.pump(const Duration(milliseconds: 80));
    final middle = _paintedRect(tester, calendar);
    await tester.pumpAndSettle();
    final end = _paintedRect(tester, calendar);
    expect(middle.width, greaterThan(first.width));
    expect(middle.width, lessThan(end.width));
    expect(middle.center.dx, lessThan(trigger.center.dx));
    expect(middle.center.dx, greaterThan(end.center.dx));
    expect(end.center, const Offset(400, 300));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final closing = _paintedRect(tester, calendar);
    expect(closing.width, lessThan(end.width));
    expect(closing.center.dx, greaterThan(end.center.dx));
    await tester.pumpAndSettle();
    expect(calendar, findsNothing);
  });

  testWidgets('高对比度实色遮罩，减少动态效果立即居中且可返回', (tester) async {
    final client = _client();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(highContrast: true, disableAnimations: true),
          child: child!,
        ),
        home: PastScreen(apiClient: client),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history_calendar_toggle')));
    await tester.pump();
    final calendar = find.byKey(const Key('history_calendar'));
    expect(_paintedRect(tester, calendar).center, const Offset(400, 300));
    final backdrop = find.byKey(const Key('history_calendar_backdrop'));
    expect(
      find.descendant(of: backdrop, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
    final shade = tester.widget<ColoredBox>(
      find.descendant(of: backdrop, matching: find.byType(ColoredBox)),
    );
    expect(shade.color.a, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calendar, findsNothing);
  });

  testWidgets('窄屏大字月历可内部滚动，点内部留白不关闭', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _client();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PastScreen(apiClient: client),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history_calendar_toggle')));
    await tester.pumpAndSettle();
    final calendar = find.byKey(const Key('history_calendar'));
    final scroll = find.byKey(const Key('history_calendar_scroll'));
    expect(tester.getRect(scroll).left, greaterThanOrEqualTo(16));
    expect(tester.getRect(scroll).right, lessThanOrEqualTo(304));
    await tester.tapAt(tester.getTopLeft(calendar) + const Offset(8, 20));
    await tester.pumpAndSettle();
    expect(calendar, findsOneWidget);
    await tester.drag(scroll, const Offset(0, -200));
    await tester.pumpAndSettle();
    final day = tester.renderObject<RenderBox>(find.text('30'));
    expect(
      day.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(day.size.width),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('关闭后完成的旧请求不能污染再次打开的日历', (tester) async {
    final pending = <Completer<http.Response>>[];
    final client = ApiClient(
      ApiConfig(baseUrl: 'https://test.local', token: 'test'),
      httpClient: MockClient((request) async {
        if (request.url.path.startsWith('/api/v1/history/') &&
            !request.url.path.endsWith('/gallery')) {
          final response = Completer<http.Response>();
          pending.add(response);
          return response.future;
        }
        return http.Response('{"months":[],"nextCursor":null}', 200);
      }),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history_calendar_toggle')));
    await tester.pump();
    await tester.pump(FloraMotion.standard);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history_calendar_toggle')));
    await tester.pump();
    expect(pending, hasLength(2));
    pending.last.complete(http.Response(jsonEncode(_emptyMonth()), 200));
    await tester.pumpAndSettle();
    pending.first.complete(http.Response('{}', 500));
    await tester.pumpAndSettle();
    expect(find.text('记录标记暂未加载，仍可选择日期'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Rect _paintedRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

ApiClient _client({
  bool withGallery = false,
  void Function(http.Request)? onRequest,
}) => ApiClient(
  ApiConfig(baseUrl: 'https://test.local', token: 'test'),
  httpClient: MockClient((request) async {
    onRequest?.call(request);
    if (!request.url.path.startsWith('/api/v1/history/')) {
      return http.Response('{}', 404);
    }
    final body = request.url.path.endsWith('/gallery')
        ? {
            'months': [
              if (withGallery)
                {
                  'year': 2024,
                  'month': 3,
                  'totalDays': 28,
                  'totalImages': 28,
                  'days': List.generate(
                    28,
                    (index) => {
                      'date':
                          '2024-03-${(index + 1).toString().padLeft(2, '0')}',
                      'images': ['photo$index.jpg'],
                      'hasContent': true,
                    },
                  ),
                },
            ],
            'nextCursor': null,
          }
        : _emptyMonth();
    return http.Response(jsonEncode(body), 200);
  }),
);

Map<String, Object> _emptyMonth() => {
  'year': DateTime.now().year,
  'month': DateTime.now().month,
  'diaries': [],
};
