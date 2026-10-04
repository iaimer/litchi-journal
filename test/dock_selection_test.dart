import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_app_bar.dart';
import 'package:litchi_journal_flutter/widgets/flora_dock.dart';
import 'package:litchi_journal_flutter/widgets/flora_glass.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/flora_origin.dart';
import 'package:litchi_journal_flutter/widgets/flora_origin_transform.dart';
import 'package:litchi_journal_flutter/widgets/flora_page_route.dart';

const _selectedNames = [
  'dock-diary-selected',
  'dock-history-selected',
  'dock-habits-selected',
];
const _outlineNames = [FloraIcons.diary, FloraIcons.history, FloraIcons.habits];

Finder _icon(String name) => find.byWidgetPredicate(
  (widget) => widget is FloraIcon && widget.name == name,
);

Future<Uint8List> _raster(
  WidgetTester tester,
  Finder finder, {
  double pixelRatio = 1,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      return (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}

Future<void> _mount(
  WidgetTester tester,
  Widget home, {
  bool dark = false,
  double scale = 1,
  bool reduced = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

Widget _dockHost({int initial = 0}) => StatefulBuilder(
  builder: (context, setState) => Scaffold(
    bottomNavigationBar: Padding(
      padding: const EdgeInsets.all(16),
      child: FloraDock(
        selectedIndex: initial,
        height: FloraDock.heightFor(context),
        onSelected: (index) => setState(() => initial = index),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dock 实心派生资源独立注册，保持原空心资源映射', () async {
    const filenames = [
      'notebook-pen-filled.svg',
      'images-filled.svg',
      'sprout-filled.svg',
    ];
    for (var index = 0; index < _selectedNames.length; index++) {
      final name = _selectedNames[index];
      final path = FloraIcons.path(name);
      expect(path, 'assets/icons/navigation/${filenames[index]}');
      expect(FloraIcons.all, contains(name));
      expect(FloraIcons.isLucide(name), isFalse);
      final svg = await rootBundle.loadString(path);
      expect(svg, contains('viewBox="0 0 24 24"'));
      expect(svg, contains('fill="currentColor"'));
      expect(svg, isNot(contains('white')));
      expect(svg, isNot(contains('#')));
      final bytes = await SvgAssetLoader(path).loadBytes(null);
      expect(bytes.lengthInBytes, greaterThan(0));
      expect(
        FloraIcons.path(_outlineNames[index]),
        startsWith('assets/icons/lucide/'),
      );
    }
  });

  testWidgets('实心照片使用真实透明镂空，深色不产生白色块', (tester) async {
    const boundaryKey = Key('filled-photo-pixels');
    await _mount(
      tester,
      const Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: FloraIcon('dock-history-selected', color: Color(0xFFCA9A84)),
          ),
        ),
      ),
      dark: true,
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final pixels = (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 4);
      try {
        return (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    }))!;
    int alphaAt(int x, int y) => pixels[((y * 4) * 96 + x * 4) * 4 + 3];
    expect(alphaAt(9, 5), 255);
    expect(alphaAt(13, 7), 0);
    expect(alphaAt(16, 14), 0);
    for (var offset = 0; offset < pixels.length; offset += 4) {
      if (pixels[offset + 3] == 255) {
        expect(pixels.sublist(offset, offset + 3), [202, 154, 132]);
      }
    }
  });

  testWidgets('选中日记本保留透明纸页和清楚的装订、文字、笔尖', (tester) async {
    const boundaryKey = Key('filled-notebook-pixels');
    await _mount(
      tester,
      const Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: FloraIcon(
              FloraIcons.dockDiarySelected,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
    final pixels = await _raster(
      tester,
      find.byKey(boundaryKey),
      pixelRatio: 4,
    );
    int alphaAt(int x, int y) => pixels[((y * 4) * 96 + x * 4) * 4 + 3];
    expect(alphaAt(10, 4), 0);
    expect(alphaAt(16, 16), 0);
    expect(alphaAt(9, 20), 0);
    expect(alphaAt(9, 18), 255);
    expect(alphaAt(6, 12), 255);
    expect(alphaAt(18, 5), 255);
  });

  for (final dark in [false, true]) {
    testWidgets('选中日记本上沿和右沿完整连续，不缺页 dark=$dark', (tester) async {
      const boundaryKey = Key('notebook-closed-outline');
      await _mount(
        tester,
        Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: FloraIcon(
                FloraIcons.dockDiarySelected,
                color: dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        ),
        dark: dark,
        scale: 1.3,
      );
      final pixels = await _raster(
        tester,
        find.byKey(boundaryKey),
        pixelRatio: 4,
      );
      int alphaAt(int x, int y) => pixels[((y * 4) * 96 + x * 4) * 4 + 3];
      for (var x = 8; x <= 18; x++) {
        expect(alphaAt(x, 2), 255, reason: '上沿 x=$x 必须闭合');
      }
      for (var y = 5; y <= 20; y++) {
        expect(alphaAt(20, y), 255, reason: '右沿 y=$y 必须闭合');
      }
      expect(alphaAt(16, 16), 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('Dock 按下和松开不绘制瞬时椭圆背景 dark=$dark', (tester) async {
      const boundaryKey = Key('dock-press-pixels');
      await _mount(
        tester,
        RepaintBoundary(key: boundaryKey, child: _dockHost()),
        dark: dark,
        scale: 1.3,
      );
      final before = await _raster(tester, find.byKey(boundaryKey));
      Future<void> expectUnchanged() async {
        final after = await _raster(tester, find.byKey(boundaryKey));
        var changedBytes = 0;
        for (var index = 0; index < before.length; index++) {
          if (before[index] != after[index]) changedBytes++;
        }
        expect(changedBytes, 0);
      }

      final gesture = await tester.startGesture(
        tester.getCenter(_icon(FloraIcons.dockDiarySelected)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await expectUnchanged();
      await tester.pump(const Duration(milliseconds: 100));
      await expectUnchanged();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 40));
      await expectUnchanged();
      await tester.pumpAndSettle();
      await expectUnchanged();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('玻璃头部保留，返回按钮不重复叠加玻璃', (tester) async {
    await _mount(
      tester,
      Scaffold(
        appBar: FloraAppBar(
          glassBackground: true,
          title: const Text('历史日记'),
          leading: IconButton(
            icon: const FloraIcon(FloraIcons.back),
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(find.byType(FloraGlassHeader), findsOneWidget);
    expect(find.byType(FloraGlassIconButton), findsNothing);
    expect(
      tester.getSize(
        find.ancestor(
          of: _icon(FloraIcons.back),
          matching: find.byType(IconButton),
        ),
      ),
      const Size(48, 48),
    );
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Dock 三项仅当前项实心，位置稳定 dark=$dark scale=$scale', (tester) async {
        await _mount(tester, _dockHost(), dark: dark, scale: scale);
        final dockRect = tester.getRect(find.byType(FloraDock));
        for (var selected = 0; selected < 3; selected++) {
          await tester.tap(find.text(['今天', '过往', '习惯'][selected]));
          await tester.pumpAndSettle();
          final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
          expect(bar.indicatorColor, Colors.transparent);
          expect(bar.selectedIndex, selected);
          for (var index = 0; index < 3; index++) {
            final name = index == selected
                ? _selectedNames[index]
                : _outlineNames[index];
            expect(_icon(name), findsOneWidget);
            expect(tester.getSize(_icon(name)), const Size(24, 24));
            final label = tester.widget<Text>(
              find.text(['今天', '过往', '习惯'][index]),
            );
            expect(
              label.style?.fontWeight,
              index == selected ? FontWeight.w700 : FontWeight.w500,
            );
          }
          expect(tester.getRect(find.byType(FloraDock)), dockRect);
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('显式返回透明且保持 48dp 热区 dark=$dark scale=$scale', (tester) async {
        var backCount = 0;
        await _mount(
          tester,
          Scaffold(
            appBar: FloraAppBar(
              title: const Text('设置'),
              leading: IconButton(
                icon: const FloraIcon(FloraIcons.back),
                onPressed: () => backCount++,
              ),
              actions: [
                IconButton(
                  tooltip: '其他操作',
                  icon: const FloraIcon(FloraIcons.more),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          dark: dark,
          scale: scale,
        );
        final button = find.ancestor(
          of: _icon(FloraIcons.back),
          matching: find.byType(IconButton),
        );
        expect(
          find.ancestor(of: button, matching: find.byType(FloraGlassSurface)),
          findsNothing,
        );
        expect(tester.getSize(button), const Size(48, 48));
        expect(
          find.ancestor(
            of: button,
            matching: find.byType(FloraOriginIconButton),
          ),
          findsOneWidget,
        );
        expect(find.byType(FloraGlassIconButton), findsOneWidget);
        await tester.tap(button);
        expect(backCount, 1);
        final rect = tester.getRect(button);
        for (final position in [
          rect.topLeft + const Offset(1, 1),
          rect.topRight + const Offset(-1, 1),
          rect.bottomLeft + const Offset(1, -1),
          rect.bottomRight + const Offset(-1, -1),
          Offset(rect.left + 1, rect.center.dy),
          Offset(rect.right - 1, rect.center.dy),
        ]) {
          await tester.tapAt(position);
        }
        expect(backCount, 7);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('自动返回无玻璃底座且能退出页面', (tester) async {
    await _mount(tester, const Scaffold(body: Text('父页面')));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(appBar: FloraAppBar(title: const Text('子页面'))),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.ancestor(
      of: _icon(FloraIcons.back),
      matching: find.byType(IconButton),
    );
    expect(tester.getSize(button), const Size(48, 48));
    expect(find.byType(FloraGlassIconButton), findsNothing);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('父页面'), findsOneWidget);
    expect(find.text('子页面'), findsNothing);
  });

  testWidgets('返回按钮保留外部焦点节点，Enter 能激活返回', (tester) async {
    final focusNode = FocusNode();
    final states = WidgetStatesController();
    addTearDown(focusNode.dispose);
    addTearDown(states.dispose);
    var backCount = 0;
    var gainedFocus = false;
    focusNode.addListener(() => gainedFocus |= focusNode.hasFocus);
    await _mount(
      tester,
      Scaffold(
        appBar: FloraAppBar(
          title: const Text('设置'),
          leading: IconButton(
            icon: const FloraIcon(FloraIcons.back),
            focusNode: focusNode,
            statesController: states,
            onPressed: () => backCount++,
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    expect(gainedFocus, isTrue);
    expect(states.value, contains(WidgetState.focused));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(IconButton)),
    );
    await tester.pump();
    expect(states.value, contains(WidgetState.pressed));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(states.value, isNot(contains(WidgetState.pressed)));
    expect(backCount, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(backCount, 2);
  });

  for (final dark in [false, true]) {
    for (final reduced in [false, true]) {
      testWidgets('透明返回仍收回真实入口 dark=$dark reduced=$reduced', (tester) async {
        const entryKey = Key('navigation-origin');
        late FloraPageRoute<void> route;
        await _mount(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FloraInkWell(
                  key: entryKey,
                  onTap: () {
                    route = FloraPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: FloraAppBar(title: const Text('子页面')),
                      ),
                    );
                    Navigator.of(context).push(route);
                  },
                  child: const SizedBox.square(
                    dimension: 48,
                    child: Text('打开'),
                  ),
                ),
              ),
            ),
          ),
          dark: dark,
          scale: 1.3,
          reduced: reduced,
        );
        final anchor = tester.getRect(find.byKey(entryKey));
        await tester.tap(find.byKey(entryKey));
        await tester.pumpAndSettle();
        expect(route.origin?.rect, anchor);
        await tester.tap(_icon(FloraIcons.back));
        await tester.pump();
        if (reduced) {
          expect(route.reverseTransitionDuration, Duration.zero);
        } else {
          await tester.pump(const Duration(milliseconds: 80));
          expect(route.animation!.value, inExclusiveRange(0, 1));
          expect(
            tester
                .widget<FloraOriginTransform>(
                  find.byType(FloraOriginTransform).last,
                )
                .source,
            anchor,
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('子页面'), findsNothing);
        expect(find.byKey(entryKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('返回按钮保留 autofocus 与短暂交互反馈设置', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await _mount(
      tester,
      Scaffold(
        appBar: FloraAppBar(
          title: const Text('设置'),
          leading: IconButton(
            icon: const FloraIcon(FloraIcons.back),
            focusNode: focusNode,
            autofocus: true,
            enableFeedback: false,
            focusColor: const Color(0x225A4A36),
            hoverColor: const Color(0x115A4A36),
            highlightColor: const Color(0x335A4A36),
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(focusNode.hasFocus, isTrue);
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.autofocus, isTrue);
    expect(button.enableFeedback, isFalse);
    expect(button.focusColor, const Color(0x225A4A36));
    expect(button.hoverColor, const Color(0x115A4A36));
    expect(button.highlightColor, const Color(0x335A4A36));
  });

  testWidgets('键盘焦点不会改变 Dock 所选页面', (tester) async {
    await _mount(tester, _dockHost());
    final context = tester.element(find.text('过往'));
    Focus.of(context).requestFocus();
    await tester.pumpAndSettle();
    expect(_icon(_selectedNames[0]), findsOneWidget);
    expect(_icon(FloraIcons.history), findsOneWidget);
    expect(_icon(_selectedNames[1]), findsNothing);
    final focusMarker = tester.widget<DecoratedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.child is FloraIcon &&
            (widget.child as FloraIcon).name == FloraIcons.history,
      ),
    );
    expect((focusMarker.decoration as BoxDecoration).border?.bottom.width, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_icon(_selectedNames[1]), findsOneWidget);
  });

  testWidgets('减少动态效果时 Dock 切换立即完成且无缩放', (tester) async {
    await _mount(tester, _dockHost(), reduced: true);
    final rect = tester.getRect(find.byType(FloraDock));
    await tester.tap(find.text('习惯'));
    await tester.pump();
    expect(_icon(_selectedNames[2]), findsOneWidget);
    expect(tester.getRect(find.byType(FloraDock)), rect);
    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .animationDuration,
      Duration.zero,
    );
  });
}
