import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:litchi_journal_flutter/screens/read_only_diary_screen.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_origin.dart';
import 'package:litchi_journal_flutter/widgets/flora_page_route.dart';
import 'package:litchi_journal_flutter/widgets/quick_record_backdrop.dart';

void main() {
  testWidgets('历史菜单展开时顶部返回一次退出详情，不退出上一级页面', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final navigator = GlobalKey<NavigatorState>();
    final client = ApiClient(
      ApiConfig(baseUrl: 'http://example.invalid', token: 'ui-test'),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'date': '2026-06-08',
            'raw': '## 随手记\n- **09:30** 历史正文',
            'sections': {},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('根页面')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('过往父页面')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      FloraPageRoute<void>(
        builder: (_) =>
            ReadOnlyDiaryScreen(date: DateTime(2026, 6, 8), apiClient: client),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historical_quick_record_fab')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('关闭记录菜单'), findsOneWidget);
    await tester.tap(find.byType(FloraOriginIconButton).first);
    await tester.pumpAndSettle();
    expect(find.byType(ReadOnlyDiaryScreen), findsNothing);
    expect(find.text('过往父页面'), findsOneWidget);
    expect(find.bySemanticsLabel('关闭记录菜单'), findsNothing);
  });

  testWidgets('展开时只从 Banner 下方模糊，并拦截阅读内容操作', (tester) async {
    var contentTaps = 0;
    final key = GlobalKey<_BackdropHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: const Key('quick_record_backdrop_capture'),
          child: _BackdropHarness(key: key, onContentTap: () => contentTaps++),
        ),
      ),
    );

    final beforeBlur = await _pixelAt(tester, const Offset(112, 150));
    await tester.tap(find.byKey(const Key('toggle_menu')));
    await tester.pumpAndSettle();

    final filter = find.byType(BackdropFilter);
    expect(filter, findsOneWidget);
    expect(tester.getRect(filter).top, 72);
    expect(find.bySemanticsLabel('关闭记录菜单'), findsOneWidget);
    final afterBlur = await _pixelAt(tester, const Offset(112, 150));
    // 红色内容块左侧的原始黑色像素会被滤镜扩散，证明实际画面退入背景。
    expect(afterBlur.r, greaterThan(beforeBlur.r + 0.08));

    await tester.tap(
      find.byKey(const Key('reading_content')),
      warnIfMissed: false,
    );
    expect(contentTaps, 0);

    await tester.tapAt(const Offset(8, 100));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(key.currentState!.expanded, isFalse);

    await tester.tap(find.byKey(const Key('reading_content')));
    expect(contentTaps, 1);
  });

  testWidgets('减少动画与高对比度分别立即完成和停用模糊', (tester) async {
    final key = GlobalKey<_BackdropHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            highContrast: true,
          ),
          child: _BackdropHarness(key: key),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('toggle_menu')));
    await tester.pump();
    expect(key.currentState!.expanded, isTrue);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.bySemanticsLabel('关闭记录菜单'), findsOneWidget);

    await tester.tapAt(const Offset(8, 100));
    await tester.pump();
    expect(find.bySemanticsLabel('关闭记录菜单'), findsNothing);
  });

  testWidgets('展开菜单取消正文已按下但尚未松开的操作', (tester) async {
    var contentTaps = 0;
    final key = GlobalKey<_BackdropHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: _BackdropHarness(key: key, onContentTap: () => contentTaps++),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('reading_content'))),
    );
    await tester.pump();
    key.currentState!.setExpanded(true);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(contentTaps, 0);
  });

  testWidgets('展开菜单停止正文惯性滚动，收起后保留位置并恢复滚动', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final key = GlobalKey<_BackdropHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: _BackdropHarness(
          key: key,
          readingContent: ListView.builder(
            controller: controller,
            itemExtent: 64,
            itemCount: 100,
            itemBuilder: (_, index) => Text('记录 $index'),
          ),
        ),
      ),
    );
    await tester.fling(find.byType(ListView), const Offset(0, -300), 1600);
    await tester.pump(const Duration(milliseconds: 32));
    key.currentState!.setExpanded(true);
    await tester.pump();
    final pausedOffset = controller.offset;
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(pausedOffset, 0.01));
    key.currentState!.setExpanded(false);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(pausedOffset, 0.01));
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(pausedOffset));
  });

  testWidgets('连续反转保持正文状态，收回完成前仍拦截内容', (tester) async {
    var contentTaps = 0;
    final key = GlobalKey<_BackdropHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: _BackdropHarness(key: key, onContentTap: () => contentTaps++),
      ),
    );
    final contentElement = tester.element(
      find.byKey(const Key('reading_content')),
    );
    key.currentState!.setExpanded(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 64));
    key.currentState!.setExpanded(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('reading_content')),
      warnIfMissed: false,
    );
    expect(contentTaps, 0);
    key.currentState!.setExpanded(true);
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byKey(const Key('reading_content'))),
      same(contentElement),
    );
    key.currentState!.setExpanded(false);
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(find.byKey(const Key('reading_content')));
    expect(contentTaps, 1);
  });

  for (final useReducedMotion in [false, true]) {
    testWidgets('动画中${useReducedMotion ? '开启减少动态效果' : '停用 Ticker'}立即完成', (
      tester,
    ) async {
      final stopMotion = ValueNotifier(false);
      addTearDown(stopMotion.dispose);
      final key = GlobalKey<_BackdropHarnessState>();
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: stopMotion,
            builder: (context, stopped, _) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: useReducedMotion && stopped),
              child: TickerMode(
                enabled: useReducedMotion || !stopped,
                child: _BackdropHarness(key: key),
              ),
            ),
          ),
        ),
      );
      key.currentState!.setExpanded(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      stopMotion.value = true;
      await tester.pump();
      expect(find.byType(BackdropFilter), findsOneWidget);
      final animation =
          tester
                  .widget<AnimatedBuilder>(
                    find.descendant(
                      of: find.byType(QuickRecordBackdrop),
                      matching: find.byType(AnimatedBuilder),
                    ),
                  )
                  .animation
              as AnimationController;
      expect(animation.value, 1);
      expect(animation.isAnimating, isFalse);
      key.currentState!.setExpanded(false);
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.bySemanticsLabel('关闭记录菜单'), findsNothing);
    });
  }
}

class _BackdropHarness extends StatefulWidget {
  final VoidCallback? onContentTap;
  final Widget? readingContent;

  const _BackdropHarness({super.key, this.onContentTap, this.readingContent});

  @override
  State<_BackdropHarness> createState() => _BackdropHarnessState();
}

class _BackdropHarnessState extends State<_BackdropHarness> {
  bool expanded = false;

  void setExpanded(bool value) => setState(() => expanded = value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          QuickRecordBackdrop(
            expanded: expanded,
            bannerBottom: 72,
            onDismiss: () => setState(() => expanded = false),
            child:
                widget.readingContent ??
                ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      const Positioned(
                        left: 120,
                        top: 100,
                        width: 120,
                        height: 120,
                        child: ColoredBox(color: Colors.red),
                      ),
                      Center(
                        child: FilledButton(
                          key: const Key('reading_content'),
                          onPressed: widget.onContentTap,
                          child: const Text('正文操作'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: FilledButton(
              key: const Key('toggle_menu'),
              onPressed: () => setState(() => expanded = !expanded),
              child: const Text('切换'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<Color> _pixelAt(WidgetTester tester, Offset point) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('quick_record_backdrop_capture')),
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
