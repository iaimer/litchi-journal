import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:litchi_journal_flutter/models/default_tag_config.dart';
import 'package:litchi_journal_flutter/models/tag_settings.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/screens/tag_settings_page.dart';
import 'package:litchi_journal_flutter/screens/habit_edit_screen.dart';
import 'package:litchi_journal_flutter/widgets/quick_note_timeline.dart';
import 'package:litchi_journal_flutter/main.dart' as app;
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_dock.dart';
import 'package:litchi_journal_flutter/widgets/flora_glass.dart';
import 'package:litchi_journal_flutter/widgets/flora_origin.dart';
import 'package:litchi_journal_flutter/widgets/flora_origin_transform.dart';
import 'package:litchi_journal_flutter/widgets/flora_page_route.dart';
import 'package:litchi_journal_flutter/widgets/flora_sheet.dart';
import 'package:litchi_journal_flutter/widgets/flora_dialog.dart';
import 'package:litchi_journal_flutter/widgets/quick_record_fan.dart';
import 'package:litchi_journal_flutter/widgets/timeline_action_sheet.dart';

const _entry = Key('entry');
const _page = Key('page');

Widget _host(
  VoidCallback open, {
  ValueNotifier<bool>? reduced,
  ValueNotifier<bool>? ticker,
}) => ListenableBuilder(
  listenable: Listenable.merge([?reduced, ?ticker]),
  builder: (_, _) => MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: reduced?.value ?? false),
      child: TickerMode(enabled: ticker?.value ?? true, child: child!),
    ),
    home: Scaffold(
      body: Stack(
        children: [
          Positioned(
            right: 16,
            top: 150,
            child: FloraInkWell(
              key: _entry,
              onTap: open,
              child: const SizedBox(width: 48, height: 48, child: Text('入口')),
            ),
          ),
        ],
      ),
    ),
  ),
);

Future<Object?> _back(
  WidgetTester tester,
  String method, {
  int edge = 0,
  double progress = 0,
}) async {
  final result = Completer<Object?>();
  const codec = StandardMethodCodec();
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.backGesture.name,
    codec.encodeMethodCall(
      MethodCall(method, {
        'touchOffset': [edge == 0 ? 1.0 : 319.0, 300.0],
        'swipeEdge': edge,
        'progress': progress,
      }),
    ),
    (data) => result.complete(codec.decodeEnvelope(data!)),
  );
  return result.future;
}

Rect _paintedPage(WidgetTester tester) => tester.getRect(find.byKey(_page));

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('真实 MainScreen 窄屏大字体下 Dock 与 FAB 对齐，末尾可读且切换保留滚动', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final raw =
        '## 随手记\n${List.generate(12, (index) => '- **08:25** 第 $index 条内容，给自己留一点时间。 #生活').join('\n')}\n- **18:30** 末尾内容 #生活';
    final client = ApiClient(
      ApiConfig(baseUrl: 'http://example.invalid', token: 'ui-test'),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path.startsWith('/api/v1/diary/')) {
          return http.Response(
            jsonEncode({'date': '2026-10-04', 'raw': raw, 'sections': {}}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (path == '/api/v1/stats/habit') return http.Response('[]', 200);
        if (path == '/api/v1/history/gallery') {
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
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: app.MainScreen(apiClient: client, onApiConfigChanged: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    final dock = tester.getRect(find.byType(FloraDock));
    final fab = tester.getRect(find.byKey(const Key('quick_record_fab')));
    expect(fab.bottom, closeTo(dock.top - 12, 0.5));
    expect(dock.left, 16);
    expect(dock.right, 304);
    await tester.tap(find.byKey(const Key('quick_record_fab')));
    await tester.pumpAndSettle();
    final entries = [
      for (final key in [
        'quick_record_quick_note',
        'quick_record_reflection',
        'quick_record_happiness',
        'quick_record_anxiety',
      ])
        tester.getRect(find.byKey(Key(key))),
    ];
    for (var index = 0; index < entries.length; index++) {
      expect(
        tester.getSize(
          find.byKey(
            Key(
              [
                'quick_record_quick_note',
                'quick_record_reflection',
                'quick_record_happiness',
                'quick_record_anxiety',
              ][index],
            ),
          ),
        ),
        const Size(48, 48),
      );
      expect(entries[index].bottom, lessThan(dock.top));
      expect(entries[index].left, greaterThanOrEqualTo(0));
      expect(entries[index].right, lessThanOrEqualTo(320));
      for (var next = index + 1; next < entries.length; next++) {
        expect(entries[index].overlaps(entries[next]), false);
      }
    }
    await tester.tap(find.byKey(const Key('quick_record_fab')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('末尾内容')).bottom,
      lessThanOrEqualTo(dock.top),
    );
    final scrolling = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final offset = scrolling.pixels;
    await tester.tap(find.text('过往').last);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(FloraDock)).center.dx, 160);
    await tester.tap(find.text('今天').last);
    await tester.pumpAndSettle();
    expect(scrolling.pixels, offset);
    expect(tester.takeException(), isNull);
  });

  testWidgets('实际标签新增按钮向表单传入自身区域', (tester) async {
    final config = DefaultTagConfig.value;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TagSettingsPage(
          initialSettings: TagSettings.fromTagConfig(config),
          tagConfig: config,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(TextButton, '＋ 添加领域');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final rect = tester.getRect(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester
          .widget<FloraOriginTransform>(find.byType(FloraOriginTransform))
          .source,
      rect,
    );
    await tester.pumpAndSettle();
    expect(find.text('新增领域'), findsOneWidget);
    Navigator.of(tester.element(find.text('新增领域'))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('实际习惯恢复默认确认框从恢复按钮展开', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const HabitEditScreen(habitKey: 'water'),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, '恢复默认');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final rect = tester.getRect(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester
          .widget<FloraOriginTransform>(find.byType(FloraOriginTransform))
          .source,
      rect,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('真实条目编辑页返回原三点，不返回已移除的菜单选项', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: QuickNoteTimeline(
            section: QuickNoteSection(
              title: '随手记',
              contents: const [],
              notes: [
                QuickNoteItem(
                  time: '08:25',
                  content: '测试记录',
                  tags: const ['#生活'],
                  rawLine: '- **08:25** 测试记录 #生活',
                ),
              ],
            ),
            onEdit: (_, _, _, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final more = find.byTooltip('更多操作');
    final rect = tester.getRect(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(TextField));
    final route = ModalRoute.of(context)! as FloraPageRoute;
    expect(route.origin!.rect, rect);
    expect(route.origin!.returnRect(const Size(800, 600)), rect);
    Navigator.of(context).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester
          .widget<FloraOriginTransform>(find.byType(FloraOriginTransform))
          .source,
      rect,
    );
    await tester.pumpAndSettle();
    expect(more, findsOneWidget);
  });
  for (final stopTicker in [false, true]) {
    for (final kind in ['page', 'sheet', 'menu', 'dialog']) {
      testWidgets('$kind 打开后${stopTicker ? '停用 Ticker' : '减少动画'}，再关闭立即完成路由', (
        tester,
      ) async {
        final reduced = ValueNotifier(false);
        final ticker = ValueNotifier(true);
        addTearDown(reduced.dispose);
        addTearDown(ticker.dispose);
        await tester.pumpWidget(
          _host(
            () {
              final context = tester.element(find.byKey(_entry));
              switch (kind) {
                case 'page':
                  Navigator.of(context).push(
                    FloraPageRoute(
                      builder: (_) =>
                          const Scaffold(body: Center(child: Text('目标'))),
                    ),
                  );
                case 'sheet':
                  showFloraSheet<void>(
                    context: context,
                    builder: (_) => const SizedBox(
                      height: 180,
                      child: Center(child: Text('目标')),
                    ),
                  );
                case 'menu':
                  showTimelineActionSheet(
                    context,
                    showEdit: true,
                    showDelete: true,
                  );
                case 'dialog':
                  showFloraDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(title: Text('目标')),
                  );
              }
            },
            reduced: reduced,
            ticker: ticker,
          ),
        );
        await tester.tap(find.byKey(_entry));
        await tester.pumpAndSettle();
        final context = tester.element(find.text(kind == 'menu' ? '编辑' : '目标'));
        final route = ModalRoute.of(context)!;
        var completed = false;
        route.completed.then((_) => completed = true);
        if (stopTicker) {
          ticker.value = false;
        } else {
          reduced.value = true;
        }
        await tester.pump();
        Navigator.of(context).pop();
        await tester.pump();
        await tester.pump();
        expect(completed, true);
        expect(find.text(kind == 'menu' ? '编辑' : '目标'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final kind in ['sheet', 'menu', 'dialog']) {
    testWidgets('$kind 从减少动画恢复后退出仍向入口收缩', (tester) async {
      final reduced = ValueNotifier(true);
      addTearDown(reduced.dispose);
      await tester.pumpWidget(
        _host(() {
          final context = tester.element(find.byKey(_entry));
          switch (kind) {
            case 'sheet':
              showFloraSheet<void>(
                context: context,
                builder: (_) => const SizedBox(height: 180, child: Text('目标')),
              );
            case 'menu':
              showTimelineActionSheet(
                context,
                showEdit: true,
                showDelete: true,
              );
            case 'dialog':
              showFloraDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('目标')),
              );
          }
        }, reduced: reduced),
      );
      await tester.tap(find.byKey(_entry));
      await tester.pumpAndSettle();
      final context = tester.element(find.text(kind == 'menu' ? '编辑' : '目标'));
      final route = ModalRoute.of(context)!;
      var completed = false;
      route.completed.then((_) => completed = true);
      reduced.value = false;
      await tester.pump();
      expect(route.transitionDuration, FloraMotion.standard);
      expect(route.reverseTransitionDuration, FloraMotion.fast);
      Navigator.of(context).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(completed, false);
      final transform = tester.widget<FloraOriginTransform>(
        find.byType(FloraOriginTransform),
      );
      expect(transform.source, isNotNull);
      expect(transform.progress, greaterThan(0));
      expect(transform.progress, lessThan(1));
      await tester.pumpAndSettle();
      expect(completed, true);
      expect(tester.takeException(), isNull);
    });
  }

  for (final commit in [false, true]) {
    for (final edge in [0, 1]) {
      testWidgets('边缘 $edge ${commit ? '提交退出' : '取消回弹'}途中减少动画立即完成', (
        tester,
      ) async {
        final reduced = ValueNotifier(false);
        addTearDown(reduced.dispose);
        var clicks = 0;
        await tester.pumpWidget(
          _host(() {
            Navigator.of(tester.element(find.byKey(_entry))).push(
              FloraPageRoute(
                builder: (_) => Scaffold(
                  key: _page,
                  body: TextButton(
                    onPressed: () => clicks++,
                    child: const Text('继续记录'),
                  ),
                ),
              ),
            );
          }, reduced: reduced),
        );
        await tester.tap(find.byKey(_entry));
        await tester.pumpAndSettle();
        final context = tester.element(find.byKey(_page));
        final navigator = Navigator.of(context);
        final route = ModalRoute.of(context)!;
        var completed = false;
        route.completed.then((_) => completed = true);
        await _back(tester, 'startBackGesture', edge: edge);
        await _back(
          tester,
          'updateBackGestureProgress',
          edge: edge,
          progress: 0.4,
        );
        await tester.pump();
        await _back(
          tester,
          commit ? 'commitBackGesture' : 'cancelBackGesture',
          edge: edge,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        reduced.value = true;
        await tester.pump();
        await tester.pump();
        expect(navigator.userGestureInProgress, false);
        if (commit) {
          expect(completed, true);
          expect(find.byKey(_page), findsNothing);
        } else {
          expect(completed, false);
          expect(_paintedPage(tester), const Rect.fromLTWH(0, 0, 800, 600));
          await tester.tap(find.text('继续记录'));
          expect(clicks, 1);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final edge in [0, 1]) {
    testWidgets('边缘 $edge 拖动中禁用动画取消手势，不留下导航或点击锁', (tester) async {
      final reduced = ValueNotifier(false);
      addTearDown(reduced.dispose);
      var clicks = 0;
      await tester.pumpWidget(
        _host(() {
          Navigator.of(tester.element(find.byKey(_entry))).push(
            FloraPageRoute(
              builder: (_) => Scaffold(
                key: _page,
                body: Center(
                  child: TextButton(
                    onPressed: () => clicks++,
                    child: const Text('继续记录'),
                  ),
                ),
              ),
            ),
          );
        }, reduced: reduced),
      );
      await tester.tap(find.byKey(_entry));
      await tester.pumpAndSettle();
      await _back(tester, 'startBackGesture', edge: edge);
      await _back(
        tester,
        'updateBackGestureProgress',
        edge: edge,
        progress: 0.4,
      );
      await tester.pump();
      reduced.value = true;
      await tester.pump();
      await tester.pump();
      final navigator = Navigator.of(tester.element(find.byKey(_page)));
      expect(navigator.userGestureInProgress, false);
      reduced.value = false;
      await tester.pump();
      await _back(tester, 'commitBackGesture', edge: edge);
      await tester.pump();
      expect(_paintedPage(tester), const Rect.fromLTWH(0, 0, 800, 600));
      await tester.tap(find.text('继续记录'));
      expect(clicks, 1);
      expect(tester.takeException(), isNull);
    });
  }
  for (final edge in [0, 1]) {
    for (final returnToZero in [false, true]) {
      testWidgets('边缘 $edge ${returnToZero ? '拖回零进度' : '零进度'}取消后页面仍可点击', (
        tester,
      ) async {
        var clicks = 0;
        await tester.pumpWidget(
          _host(() {
            Navigator.of(tester.element(find.byKey(_entry))).push(
              FloraPageRoute(
                builder: (_) => Scaffold(
                  key: _page,
                  body: Center(
                    child: TextButton(
                      onPressed: () => clicks++,
                      child: const Text('继续记录'),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
        await tester.tap(find.byKey(_entry));
        await tester.pumpAndSettle();
        await _back(tester, 'startBackGesture', edge: edge);
        if (returnToZero) {
          await _back(
            tester,
            'updateBackGestureProgress',
            edge: edge,
            progress: 0.4,
          );
          await tester.pump();
          await _back(
            tester,
            'updateBackGestureProgress',
            edge: edge,
            progress: 0,
          );
        }
        await _back(tester, 'cancelBackGesture', edge: edge);
        await tester.pumpAndSettle();
        await tester.tap(find.text('继续记录'));
        await tester.pump();
        expect(clicks, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('确认弹窗的 Tab 和 Shift+Tab 焦点不越出操作区', (tester) async {
    final cancel = FocusNode();
    final confirm = FocusNode();
    addTearDown(cancel.dispose);
    addTearDown(confirm.dispose);
    await tester.pumpWidget(
      _host(() {
        showFloraDialog<void>(
          context: tester.element(find.byKey(_entry)),
          builder: (context) => AlertDialog(
            title: const Text('放弃记录？'),
            actions: [
              TextButton(
                focusNode: cancel,
                onPressed: () {},
                child: const Text('继续写'),
              ),
              TextButton(
                focusNode: confirm,
                onPressed: () {},
                child: const Text('放弃'),
              ),
            ],
          ),
        );
      }),
    );
    await tester.tap(find.byKey(_entry));
    await tester.pumpAndSettle();
    cancel.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(confirm.hasFocus, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(cancel.hasFocus, true);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(confirm.hasFocus, true);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('FAB 子入口消失后，记录页仍收回到主加号', (tester) async {
    final expanded = ValueNotifier(true);
    addTearDown(expanded.dispose);
    late FloraPageRoute<void> route;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          floatingActionButton: ValueListenableBuilder<bool>(
            valueListenable: expanded,
            builder: (context, open, _) => QuickRecordFan(
              expanded: open,
              onToggle: () => expanded.value = !open,
              mainButtonKey: const Key('main_fab'),
              tooltip: '快速记录',
              actions: [
                QuickRecordFanAction(
                  key: const Key('fan_entry'),
                  title: '随手记',
                  icon: const Text('写'),
                  angleDegrees: 180,
                  onTap: () {
                    expanded.value = false;
                    route = FloraPageRoute(
                      builder: (_) => const Scaffold(key: _page),
                    );
                    Navigator.of(context).push(route);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final mainRect = tester.getRect(find.byKey(const Key('main_fab')));
    final actionRect = tester.getRect(find.byKey(const Key('fan_entry')));
    await tester.tap(find.byKey(const Key('fan_entry')));
    await tester.pumpAndSettle();
    expect(route.origin!.rect, actionRect);
    expect(route.origin!.returnRect(const Size(800, 600)), mainRect);
    Navigator.of(tester.element(find.byKey(_page))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester
          .widget<FloraOriginTransform>(find.byType(FloraOriginTransform))
          .source,
      mainRect,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fan_entry')), findsNothing);
  });

  test('并发异步操作各自保留来源，不污染后一次点击', () async {
    const first = FloraOrigin(
      rect: Rect.fromLTWH(10, 10, 48, 48),
      viewport: Size(320, 700),
    );
    const second = FloraOrigin(
      rect: Rect.fromLTWH(260, 500, 48, 48),
      viewport: Size(320, 700),
    );
    final pending = Completer<void>();
    final one = FloraOrigin.withOrigin(first, () async {
      await pending.future;
      return FloraOrigin.current;
    });
    final two = FloraOrigin.withOrigin(second, () async {
      await Future<void>.value();
      return FloraOrigin.current;
    });
    pending.complete();
    expect(await one, same(first));
    expect(await two, same(second));
    expect(FloraOrigin.current, isNull);
  });

  testWidgets('页面从按钮展开，普通返回收回同一位置', (tester) async {
    late FloraPageRoute<void> route;
    await tester.pumpWidget(
      _host(() {
        route = FloraPageRoute(builder: (_) => const Scaffold(key: _page));
        Navigator.of(tester.element(find.byKey(_entry))).push(route);
      }),
    );
    final anchor = tester.getRect(find.byKey(_entry));
    await tester.tap(find.byKey(_entry));
    await tester.pump();
    expect(route.origin!.rect, anchor);
    await tester.pump(const Duration(milliseconds: 80));
    final opening = _paintedPage(tester);
    expect(opening.width, greaterThan(48));
    expect(opening.width, lessThan(800));
    await tester.pumpAndSettle();
    expect(_paintedPage(tester), const Rect.fromLTWH(0, 0, 800, 600));
    Navigator.of(tester.element(find.byKey(_page))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_paintedPage(tester).width, lessThan(800));
    expect(
      tester
          .widget<FloraOriginTransform>(find.byType(FloraOriginTransform).last)
          .source,
      anchor,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_page), findsNothing);
  });

  for (final edge in [0, 1]) {
    testWidgets('${edge == 0 ? '左' : '右'}边缘返回连续退出，取消后恢复原页面', (tester) async {
      await tester.pumpWidget(
        _host(() {
          Navigator.of(
            tester.element(find.byKey(_entry)),
          ).push(FloraPageRoute(builder: (_) => const Scaffold(key: _page)));
        }),
      );
      await tester.tap(find.byKey(_entry));
      await tester.pumpAndSettle();
      expect(await _back(tester, 'startBackGesture', edge: edge), true);
      await _back(
        tester,
        'updateBackGestureProgress',
        edge: edge,
        progress: 0.4,
      );
      await tester.pump();
      final dragging = _paintedPage(tester);
      expect(dragging.left, edge == 0 ? lessThan(0) : greaterThan(0));
      await _back(tester, 'cancelBackGesture', edge: edge);
      await tester.pump();
      expect(_paintedPage(tester).left, closeTo(dragging.left, 0.1));
      await tester.pumpAndSettle();
      expect(_paintedPage(tester), const Rect.fromLTWH(0, 0, 800, 600));
      await _back(tester, 'startBackGesture', edge: edge);
      await _back(
        tester,
        'updateBackGestureProgress',
        edge: edge,
        progress: 0.4,
      );
      await tester.pump();
      final releasing = _paintedPage(tester);
      await _back(tester, 'commitBackGesture', edge: edge);
      await tester.pump();
      expect(_paintedPage(tester).left, closeTo(releasing.left, 0.1));
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        _paintedPage(tester).left,
        edge == 0 ? lessThan(releasing.left) : greaterThan(releasing.left),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_page), findsNothing);
    });
  }

  testWidgets('PopScope 禁止手势预退出，系统返回仍走放弃确认', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      _host(() {
        Navigator.of(tester.element(find.byKey(_entry))).push(
          FloraPageRoute(
            builder: (_) => PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) attempts++;
              },
              child: const Scaffold(key: _page),
            ),
          ),
        );
      }),
    );
    await tester.tap(find.byKey(_entry));
    await tester.pumpAndSettle();
    expect(await _back(tester, 'startBackGesture'), false);
    await _back(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.byKey(_page), findsOneWidget);
  });

  testWidgets('中途关闭动画立即结束页面过渡', (tester) async {
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    late FloraPageRoute<void> route;
    await tester.pumpWidget(
      _host(() {
        route = FloraPageRoute(builder: (_) => const Scaffold(key: _page));
        Navigator.of(tester.element(find.byKey(_entry))).push(route);
      }, reduced: reduced),
    );
    await tester.tap(find.byKey(_entry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    reduced.value = true;
    await tester.pump();
    await tester.pump();
    expect(route.animation!.value, 1);
    expect(_paintedPage(tester).size, const Size(800, 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('菜单在三点附近展开且保留操作，点击外部关闭', (tester) async {
    TimelineAction? selected;
    await tester.pumpWidget(
      _host(() async {
        selected = await showTimelineActionSheet(
          tester.element(find.byKey(_entry)),
          showEdit: true,
          showDelete: true,
        );
      }),
    );
    final anchor = tester.getRect(find.byKey(_entry));
    await tester.tap(find.byKey(_entry));
    await tester.pumpAndSettle();
    final menu = tester.getRect(find.byType(FloraGlassSurface));
    expect(menu.top, anchor.bottom + 8);
    expect(menu.right, anchor.right);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(selected, TimelineAction.edit);
    await tester.tap(find.byKey(_entry));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.byType(FloraGlassSurface), findsNothing);
  });

  test('320dp、键盘和安全区下菜单不会跑出可用空间', () {
    final bounds = timelineMenuBounds(
      source: const Rect.fromLTWH(260, 380, 48, 48),
      viewport: const Size(320, 700),
      padding: const EdgeInsets.only(top: 30, bottom: 300),
      menuSize: const Size(176, 140),
    );
    expect(bounds.left, greaterThanOrEqualTo(12));
    expect(bounds.right, lessThanOrEqualTo(308));
    expect(bounds.bottom, lessThanOrEqualTo(388));
    expect(bounds.height, 140);
  });

  testWidgets('面板从真实入口展开，结果仍立即交还原保存流程', (tester) async {
    int? selected;
    await tester.pumpWidget(
      _host(() async {
        selected = await showFloraSheet<int>(
          context: tester.element(find.byKey(_entry)),
          showDragHandle: true,
          builder: (context) => SizedBox(
            height: 180,
            child: Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, 250),
                child: const Text('+250'),
              ),
            ),
          ),
        );
      }),
    );
    final anchor = tester.getRect(find.byKey(_entry));
    await tester.tap(find.byKey(_entry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester
          .widget<FloraOriginTransform>(find.byType(FloraOriginTransform))
          .source,
      anchor,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('+250'));
    await tester.pump();
    expect(selected, 250);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('高对比度玻璃使用实色，不再模糊背景', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: const Scaffold(
            body: FloraGlassSurface(child: SizedBox(width: 80, height: 48)),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    final surface = tester.widget<DecoratedBox>(find.byType(DecoratedBox).last);
    expect((surface.decoration as BoxDecoration).color!.a, 1);
  });

  testWidgets('窄屏放大字体 Dock 保持可点击，不改变选择行为', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Builder(
            builder: (context) => Scaffold(
              bottomNavigationBar: Row(
                children: [
                  Expanded(
                    child: FloraDock(
                      selectedIndex: 0,
                      onSelected: (value) => index = value,
                      height: FloraDock.heightFor(context),
                    ),
                  ),
                  const SizedBox(width: 68),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('过往'));
    expect(index, 1);
    expect(
      tester.getSize(find.byType(NavigationBar)).height,
      greaterThanOrEqualTo(64),
    );
    expect(tester.takeException(), isNull);
  });
}
