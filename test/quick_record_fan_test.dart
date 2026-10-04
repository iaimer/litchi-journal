import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/entry_type.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/historical_quick_record_fab.dart';
import 'package:litchi_journal_flutter/widgets/quick_record_fan.dart';

const _mainKey = Key('test_fan_main');
const _noteKey = Key('test_fan_note');
const _eyeKey = Key('test_fan_eye');
final _main = find.byKey(_mainKey);
final _note = find.byKey(_noteKey);
final _eye = find.byKey(_eyeKey);

Widget _host(
  ValueNotifier<bool> expanded, {
  bool reducedMotion = false,
  bool tickerEnabled = true,
  ThemeData? theme,
  VoidCallback? onSelect,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(1.6),
      ),
      child: TickerMode(
        enabled: tickerEnabled,
        child: Scaffold(
          floatingActionButton: ValueListenableBuilder<bool>(
            valueListenable: expanded,
            builder: (_, open, _) => QuickRecordFan(
              expanded: open,
              onToggle: () => expanded.value = !expanded.value,
              mainButtonKey: _mainKey,
              tooltip: '快速记录',
              actions: _actions(onSelect ?? () {}),
            ),
          ),
        ),
      ),
    ),
  );
}

List<QuickRecordFanAction> _actions(VoidCallback onSelect) => [
  QuickRecordFanAction(
    key: _noteKey,
    title: '随手记',
    icon: const FloraIcon(FloraIcons.fabWrite, size: 19),
    angleDegrees: 180,
    onTap: onSelect,
  ),
  QuickRecordFanAction(
    key: _eyeKey,
    title: '觉察',
    icon: const FloraIcon(FloraIcons.fabInsight, size: 19),
    angleDegrees: 155,
    onTap: onSelect,
  ),
];

double _distance(WidgetTester tester, Finder action) =>
    (tester.getCenter(action) - tester.getCenter(_main)).distance;

double _opacity(WidgetTester tester, Finder action) => tester
    .widget<Opacity>(find.ancestor(of: action, matching: find.byType(Opacity)))
    .opacity;

double _rotation(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(of: _main, matching: find.byType(Transform)).first,
  );
  return math.atan2(
    transform.transform.entry(1, 0),
    transform.transform.entry(0, 0),
  );
}

void main() {
  testWidgets('按下子入口后收回，松手不能再进入记录页', (tester) async {
    final expanded = ValueNotifier(true);
    addTearDown(expanded.dispose);
    var selections = 0;
    await tester.pumpWidget(_host(expanded, onSelect: () => selections++));
    final gesture = await tester.startGesture(tester.getCenter(_note));
    expanded.value = false;
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(selections, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('收回时撤销子入口键盘焦点，不能用回车激活', (tester) async {
    final expanded = ValueNotifier(true);
    addTearDown(expanded.dispose);
    var selections = 0;
    await tester.pumpWidget(_host(expanded, onSelect: () => selections++));
    final innerGesture = find
        .descendant(of: _note, matching: find.byType(GestureDetector))
        .last;
    Focus.of(tester.element(innerGesture)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selections, 1);
    expanded.value = false;
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selections, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('同步展开的位移、透明度和加号旋转都有中间帧', (tester) async {
    final expanded = ValueNotifier(false);
    addTearDown(expanded.dispose);
    await tester.pumpWidget(_host(expanded));
    expect(_note, findsNothing);
    await tester.tap(_main);
    await tester.pump();
    expect(_distance(tester, _note), closeTo(0, 0.01));
    expect(_opacity(tester, _note), 0);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_distance(tester, _note), inExclusiveRange(0, 120));
    expect(_distance(tester, _eye), closeTo(_distance(tester, _note), 0.01));
    expect(_opacity(tester, _note), inExclusiveRange(0, 1));
    expect(_opacity(tester, _eye), _opacity(tester, _note));
    expect(_rotation(tester), inExclusiveRange(0, math.pi / 4));
    await tester.pump(const Duration(milliseconds: 160));
    expect(_distance(tester, _note), closeTo(120, 0.01));
    expect(_opacity(tester, _note), 1);
    expect(_rotation(tester), closeTo(math.pi / 4, 0.001));
    expect(tester.getCenter(_note).dx, lessThan(tester.getCenter(_main).dx));
    expect(tester.getCenter(_eye).dy, lessThan(tester.getCenter(_main).dy));
  });

  testWidgets('收回期间仍绘制子按钮，但立即禁用点击和语义，结束后移除', (tester) async {
    final expanded = ValueNotifier(true);
    addTearDown(expanded.dispose);
    final semantics = tester.ensureSemantics();
    var selections = 0;
    await tester.pumpWidget(_host(expanded, onSelect: () => selections++));
    final oldCenter = tester.getCenter(_note);
    expect(
      tester.semantics.simulatedAccessibilityTraversal().map(
        (node) => node.getSemanticsData().label,
      ),
      contains('随手记'),
    );
    await tester.tap(_main);
    await tester.pump();
    expect(_note, findsOneWidget);
    expect(
      tester.semantics.simulatedAccessibilityTraversal().map(
        (node) => node.getSemanticsData().label,
      ),
      isNot(contains('随手记')),
    );
    await tester.tapAt(oldCenter);
    await tester.pump(const Duration(milliseconds: 60));
    expect(selections, 0);
    expect(_distance(tester, _note), inExclusiveRange(0, 120));
    expect(_opacity(tester, _note), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_note, findsNothing);
    expect(_rotation(tester), closeTo(0, 0.001));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    semantics.dispose();
  });

  testWidgets('展开和收回中反转从当前位置继续，连续点击后正确复原', (tester) async {
    final expanded = ValueNotifier(false);
    addTearDown(expanded.dispose);
    await tester.pumpWidget(_host(expanded));
    await tester.tap(_main);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final opening = _distance(tester, _note);
    await tester.tap(_main);
    await tester.pump();
    expect(_distance(tester, _note), closeTo(opening, 0.01));
    await tester.pump(const Duration(milliseconds: 20));
    final closing = _distance(tester, _note);
    expect(closing, lessThan(opening));
    await tester.tap(_main);
    await tester.pump();
    expect(_distance(tester, _note), closeTo(closing, 0.01));
    await tester.pump(const Duration(milliseconds: 20));
    expect(_distance(tester, _note), greaterThan(closing));
    for (var index = 0; index < 5; index++) {
      await tester.tap(_main);
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
    expect(expanded.value, isFalse);
    expect(_note, findsNothing);
    expect(_rotation(tester), closeTo(0, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动态效果时直接展开和关闭，不留下动画任务', (tester) async {
    final expanded = ValueNotifier(false);
    addTearDown(expanded.dispose);
    await tester.pumpWidget(_host(expanded, reducedMotion: true));
    await tester.tap(_main);
    await tester.pump();
    expect(_distance(tester, _note), closeTo(120, 0.01));
    expect(_rotation(tester), closeTo(math.pi / 4, 0.001));
    await tester.tap(_main);
    await tester.pump();
    expect(_note, findsNothing);
    expect(_rotation(tester), closeTo(0, 0.001));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('动画中开启减少动态效果或隐藏路由，立即到达目标状态', (tester) async {
    final expanded = ValueNotifier(false);
    addTearDown(expanded.dispose);
    await tester.pumpWidget(_host(expanded));
    expanded.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(_host(expanded, reducedMotion: true));
    expect(_distance(tester, _note), closeTo(120, 0.01));
    await tester.pumpWidget(_host(expanded));
    expanded.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(_note, findsOneWidget);
    await tester.pumpWidget(_host(expanded, tickerEnabled: false));
    expect(_note, findsNothing);
    await tester.pumpWidget(_host(expanded));
    expect(_note, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('${theme.brightness} 窄屏大字体保持位置和 48dp 点击区', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final expanded = ValueNotifier(true);
      addTearDown(expanded.dispose);
      var selections = 0;
      await tester.pumpWidget(
        _host(expanded, theme: theme, onSelect: () => selections++),
      );
      expect(tester.getSize(_note), const Size(48, 48));
      expect(tester.getSize(_main), const Size(56, 56));
      expect(tester.getRect(_note).left, greaterThanOrEqualTo(0));
      await tester.tapAt(tester.getRect(_note).centerLeft + const Offset(1, 0));
      await tester.pump();
      expect(selections, 1);
      await tester.tap(_note);
      await tester.pump();
      expect(selections, 2);
      expect(find.byTooltip('随手记'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('历史补录共用动效，保持三入口极坐标及选择行为', (tester) async {
    var expanded = false;
    EntryType? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: StatefulBuilder(
            builder: (_, setState) => HistoricalQuickRecordFab(
              expanded: expanded,
              onToggle: () => setState(() => expanded = !expanded),
              onEntrySelected: (type) {
                selected = type;
                setState(() => expanded = false);
              },
            ),
          ),
        ),
      ),
    );
    final main = find.byKey(const Key('historical_quick_record_fab'));
    final note = find.byKey(const Key('historical_quick_record_quick_note'));
    await tester.tap(main);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      (tester.getCenter(note) - tester.getCenter(main)).distance,
      inExclusiveRange(0, 120),
    );
    expect(find.byTooltip('觉察'), findsOneWidget);
    expect(find.byTooltip('小确幸'), findsOneWidget);
    expect(find.byTooltip('焦虑四问'), findsNothing);
    await tester.tap(note);
    await tester.pump();
    expect(selected, EntryType.quickNote);
    expect(note, findsOneWidget);
    await tester.pumpAndSettle();
    expect(note, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('收回中开启减少动态效果立即移除菜单', (tester) async {
    final expanded = ValueNotifier(true);
    addTearDown(expanded.dispose);
    await tester.pumpWidget(_host(expanded));
    expanded.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(_distance(tester, _note), inExclusiveRange(0, 120));
    await tester.pumpWidget(_host(expanded, reducedMotion: true));
    expect(_note, findsNothing);
    expect(_rotation(tester), closeTo(0, 0.001));
    expect(tester.takeException(), isNull);
  });
}
