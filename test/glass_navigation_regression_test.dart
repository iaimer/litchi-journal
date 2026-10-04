import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/main.dart' as app;
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_dock.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/quick_record_fan.dart';
import 'package:litchi_journal_flutter/widgets/quick_record_backdrop.dart';

const _fab = Key('quick_record_fab');

http.Response _diary() => http.Response(
  jsonEncode({
    'date': '2026-10-04',
    'raw': '## 随手记\n- **08:25** 加载后的正文 #生活',
    'sections': {},
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _mount(
  WidgetTester tester, {
  bool settle = true,
  Size size = const Size(390, 844),
  double scale = 1,
  double bottom = 0,
  bool reduced = false,
  Completer<http.Response>? diaryResponse,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final client = ApiClient(
    ApiConfig(baseUrl: 'http://example.invalid', token: 'ui-test'),
    httpClient: MockClient((request) async {
      if (request.url.path.startsWith('/api/v1/diary/')) {
        return diaryResponse == null ? _diary() : diaryResponse.future;
      }
      if (request.url.path == '/api/v1/stats/habit') {
        return http.Response('[]', 200);
      }
      if (request.url.path == '/api/v1/history/gallery') {
        return http.Response('{"months":[],"nextCursor":null}', 200);
      }
      return http.Response('{}', 404);
    }),
  );
  addTearDown(client.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(top: 24, bottom: bottom),
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: app.MainScreen(apiClient: client, onApiConfigChanged: (_) {}),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void _expectSameRect(Rect actual, Rect expected) {
  expect(actual.width, closeTo(56, 0.5));
  expect(actual.height, closeTo(56, 0.5));
  expect(actual.left, closeTo(expected.left, 0.5));
  expect(actual.top, closeTo(expected.top, 0.5));
}

Future<void> _expectStableFrames(WidgetTester tester, Rect expected) async {
  final fan = tester.getRect(find.byType(QuickRecordFan));
  for (var frame = 0; frame < 32; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    _expectSameRect(tester.getRect(find.byKey(_fab)), expected);
    expect(tester.getRect(find.byType(QuickRecordFan)), fan);
    expect(tester.takeException(), isNull);
  }
}

void main() {
  test('相同底部距离的 FAB 定位对象按值相等', () {
    expect(FloraDockFabLocation(84), FloraDockFabLocation(84));
    expect(
      FloraDockFabLocation(84).hashCode,
      FloraDockFabLocation(84).hashCode,
    );
    expect(FloraDockFabLocation(84), isNot(FloraDockFabLocation(100)));
  });

  testWidgets('冷启动从首帧起加号和扇形宿主稳定', (tester) async {
    await _mount(tester, settle: false);
    await _expectStableFrames(tester, tester.getRect(find.byKey(_fab)));
  });

  testWidgets('重复点击今天不缩放加号', (tester) async {
    await _mount(tester);
    final initial = tester.getRect(find.byKey(_fab));
    await tester.tap(find.text('今天').last);
    await _expectStableFrames(tester, initial);
  });

  testWidgets('Dock 操作会直接执行并收起已展开的记录菜单', (tester) async {
    await _mount(tester);
    final initial = tester.getRect(find.byKey(_fab));

    await tester.tap(find.byKey(_fab));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_record_quick_note')), findsOneWidget);

    await tester.tap(find.text('过往').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history_calendar_toggle')), findsOneWidget);

    await tester.tap(find.text('今天').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_record_quick_note')), findsNothing);
    _expectSameRect(tester.getRect(find.byKey(_fab)), initial);

    await tester.tap(find.byKey(_fab));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今天').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_record_quick_note')), findsNothing);
    expect(find.bySemanticsLabel('关闭记录菜单'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(QuickRecordBackdrop, skipOffstage: false),
        matching: find.byType(BackdropFilter, skipOffstage: false),
        skipOffstage: false,
      ),
      findsNothing,
    );
    _expectSameRect(tester.getRect(find.byKey(_fab)), initial);
  });

  testWidgets('菜单展开后设置一次打开，返回后不残留背景层', (tester) async {
    await _mount(tester);
    await tester.tap(find.byKey(_fab));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is FloraIcon && widget.name == FloraIcons.settings,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    final context = tester.element(find.text('外观'));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(_fab), findsOneWidget);
    expect(find.bySemanticsLabel('关闭记录菜单'), findsNothing);
    expect(find.byKey(const Key('quick_record_quick_note')), findsNothing);
  });

  testWidgets('今天页系统返回仅收起菜单并清除背景层', (tester) async {
    await _mount(tester);
    await tester.tap(find.byKey(_fab));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('加载后的正文'), findsOneWidget);
    expect(find.byKey(_fab), findsOneWidget);
    expect(find.bySemanticsLabel('关闭记录菜单'), findsNothing);
    expect(find.byKey(const Key('quick_record_quick_note')), findsNothing);
  });

  for (final tab in ['过往', '习惯']) {
    testWidgets('从$tab返回今天逐帧保持加号大小和位置', (tester) async {
      await _mount(tester);
      final initial = tester.getRect(find.byKey(_fab));
      final dock = tester.getRect(find.byType(FloraDock));
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FloraDock)), dock);
      await tester.tap(find.text('今天').last);
      await tester.pump();
      await _expectStableFrames(tester, initial);
    });
  }

  testWidgets('异步日记加载完成不让加号缩小恢复', (tester) async {
    final response = Completer<http.Response>();
    await _mount(tester, settle: false, diaryResponse: response);
    await tester.pump(const Duration(milliseconds: 600));
    final initial = tester.getRect(find.byKey(_fab));
    response.complete(_diary());
    await _expectStableFrames(tester, initial);
    expect(find.text('加载后的正文'), findsOneWidget);
  });

  testWidgets('展开收回及中途反转只移动子入口，不缩放整个扇形', (tester) async {
    await _mount(tester);
    final initial = tester.getRect(find.byKey(_fab));
    await tester.tap(find.byKey(_fab));
    await _expectStableFrames(tester, initial);
    await tester.tap(find.byKey(_fab));
    await _expectStableFrames(tester, initial);
    await tester.tap(find.byKey(_fab));
    await tester.pump(const Duration(milliseconds: 64));
    _expectSameRect(tester.getRect(find.byKey(_fab)), initial);
    await tester.tap(find.byKey(_fab));
    await tester.pump(const Duration(milliseconds: 32));
    _expectSameRect(tester.getRect(find.byKey(_fab)), initial);
    await tester.tap(find.byKey(_fab));
    await _expectStableFrames(tester, initial);
  });

  for (final reduced in [false, true]) {
    testWidgets('窄屏大字体安全区内加号位于同宽 Dock 上方，减少动画=$reduced', (tester) async {
      await _mount(
        tester,
        size: const Size(320, 700),
        scale: 1.3,
        bottom: 24,
        reduced: reduced,
      );
      final dock = tester.getRect(find.byType(FloraDock));
      final fab = tester.getRect(find.byKey(_fab));
      expect(dock.left, 16);
      expect(dock.right, 304);
      expect(fab.bottom, closeTo(dock.top - 12, 0.5));
      expect(fab.right, 304);
      await tester.tap(find.byKey(_fab));
      await _expectStableFrames(tester, fab);
      final keys = [
        'quick_record_quick_note',
        'quick_record_reflection',
        'quick_record_happiness',
        'quick_record_anxiety',
      ];
      final entries = keys
          .map((key) => tester.getRect(find.byKey(Key(key))))
          .toList();
      for (var index = 0; index < entries.length; index++) {
        expect(
          tester.getSize(find.byKey(Key(keys[index]))),
          const Size(48, 48),
        );
        expect(entries[index].left, greaterThanOrEqualTo(0));
        expect(entries[index].right, lessThanOrEqualTo(320));
        expect(entries[index].top, greaterThanOrEqualTo(24));
        expect(entries[index].bottom, lessThan(dock.top));
        for (var next = index + 1; next < entries.length; next++) {
          expect(entries[index].overlaps(entries[next]), isFalse);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
