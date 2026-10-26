import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/entry_type.dart';
import 'package:litchi_journal_flutter/widgets/flora_dock.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/historical_quick_record_fab.dart';
import 'package:litchi_journal_flutter/widgets/quick_record_backdrop.dart';
import 'package:litchi_journal_flutter/widgets/quick_record_menu.dart';

const _mainKey = Key('test_menu_main');
const _noteKey = Key('test_menu_note');
const _eyeKey = Key('test_menu_eye');
final _main = find.byKey(_mainKey);
final _note = find.byKey(_noteKey);
final _eye = find.byKey(_eyeKey);

Widget _host(
  ValueNotifier<bool> expanded, {
  bool reducedMotion = false,
  bool tickerEnabled = true,
  bool dark = false,
  bool highContrast = false,
  double scale = 1,
  VoidCallback? onSelect,
  VoidCallback? onBodyTap,
}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reducedMotion,
      highContrast: highContrast,
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      textScaler: TextScaler.linear(scale),
    ),
    child: child!,
  ),
  home: TickerMode(
    enabled: tickerEnabled,
    child: ValueListenableBuilder<bool>(
      valueListenable: expanded,
      builder: (_, open, _) => Scaffold(
        body: QuickRecordBackdrop(
          expanded: open,
          bannerBottom: 88,
          onDismiss: () => expanded.value = false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBodyTap,
            child: const SizedBox.expand(),
          ),
        ),
        floatingActionButtonLocation: const FloraDockFabLocation(40),
        floatingActionButton: QuickRecordMenu(
          topInset: 88,
          expanded: open,
          onExpandedChanged: (value) => expanded.value = value,
          mainButtonKey: _mainKey,
          tooltip: '快速记录',
          actions: _actions(onSelect),
        ),
      ),
    ),
  ),
);

List<QuickRecordMenuAction> _actions(VoidCallback? onSelect) => [
  QuickRecordMenuAction(
    key: _eyeKey,
    title: '觉察',
    icon: const FloraIcon(FloraIcons.fabInsight, size: 28),
    onTap: onSelect ?? () {},
  ),
  QuickRecordMenuAction(
    key: _noteKey,
    title: '随手记',
    icon: const FloraIcon(FloraIcons.fabWrite, size: 28),
    onTap: onSelect ?? () {},
  ),
];

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: _note, matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  testWidgets('展开显示图文竖排入口并隐藏主按钮', (tester) async {
    final expanded = ValueNotifier(true);
    addTearDown(expanded.dispose);
    await tester.pumpWidget(_host(expanded));
    expect(find.text('随手记'), findsOneWidget);
    expect(find.text('觉察'), findsOneWidget);
    expect(tester.getSize(_note), const Size(176, 56));
    expect(
      tester.getRect(_note).left,
      closeTo(tester.getRect(_eye).left, 0.01),
    );
    expect(
      tester.getRect(_eye).bottom,
      closeTo(tester.getRect(_note).top, 0.01),
    );
    expect(
      tester.getRect(_note).right,
      closeTo(tester.getRect(_main).right, 0.01),
    );
    expect(tester.getRect(_note).bottom + 8, tester.getRect(_main).bottom);
    expect(tester.widget<FloatingActionButton>(_main).onPressed, isNull);
    final icon = find.descendant(of: _note, matching: find.byType(FloraIcon));
    expect(tester.widget<FloraIcon>(icon).size, 28);
    expect(
      tester.getRect(icon).right,
      lessThan(tester.getRect(find.text('随手记')).left),
    );
  });

  testWidgets('外部点击立即移除正文模糊且不穿透，内部留白不关闭', (tester) async {
    final expanded = ValueNotifier(true);
    addTearDown(expanded.dispose);
    var bodyTaps = 0;
    await tester.pumpWidget(_host(expanded, onBodyTap: () => bodyTaps++));
    final backdrop = find.byType(QuickRecordBackdrop);
    final filter = find.descendant(
      of: backdrop,
      matching: find.byType(BackdropFilter),
    );
    expect(filter, findsOneWidget);
    await tester.tapAt(tester.getRect(_eye).topLeft + const Offset(20, -4));
    await tester.pump();
    expect(expanded.value, isTrue);
    await tester.tapAt(const Offset(30, 150));
    await tester.pump();
    expect(expanded.value, isFalse);
    expect(bodyTaps, 0);
    expect(filter, findsNothing);
    expect(tester.widget<FloatingActionButton>(_main).onPressed, isNotNull);
    await tester.tapAt(const Offset(30, 150));
    await tester.pumpAndSettle();
    expect(bodyTaps, 1);
  });

  testWidgets('同帧多次外部按下只关闭菜单，不会重新展开', (tester) async {
    final expanded = ValueNotifier(true);
    addTearDown(expanded.dispose);
    await tester.pumpWidget(_host(expanded));
    final first = await tester.startGesture(const Offset(20, 40), pointer: 11);
    final second = await tester.startGesture(const Offset(50, 40), pointer: 12);
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(expanded.value, isFalse);
    expect(_note, findsNothing);
  });

  testWidgets('按下子入口后收回，松手不能再进入记录页', (tester) async {
    final expanded = ValueNotifier(true);
    addTearDown(expanded.dispose);
    var selections = 0;
    await tester.pumpWidget(_host(expanded, onSelect: () => selections++));
    final gesture = await tester.startGesture(tester.getCenter(_note));
    expanded.value = false;
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selections, 0);
  });

  testWidgets('收回撤销键盘焦点与语义，回车不能激活', (tester) async {
    final expanded = ValueNotifier(true);
    addTearDown(expanded.dispose);
    final semantics = tester.ensureSemantics();

    var selections = 0;
    await tester.pumpWidget(_host(expanded, onSelect: () => selections++));
    final ink = find.descendant(of: _note, matching: find.byType(InkWell));
    Focus.of(
      tester.element(
        find.descendant(of: ink, matching: find.byType(GestureDetector)).last,
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selections, 1);
    expanded.value = false;
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selections, 1);
    expect(
      tester.semantics.simulatedAccessibilityTraversal().map(
        (node) => node.getSemanticsData().label,
      ),
      isNot(contains('随手记')),
    );
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('整块菜单位移和淡入有中间帧，反向操作连续', (tester) async {
    final expanded = ValueNotifier(false);
    addTearDown(expanded.dispose);
    await tester.pumpWidget(_host(expanded));
    final anchor = tester.getRect(_main);
    await tester.tap(_main);
    await tester.pump();
    final start = tester.getRect(_note);
    expect(_opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 40));
    final middle = tester.getRect(_note);
    expect(middle.top, lessThan(start.top));
    expect(_opacity(tester), inExclusiveRange(0, 1));
    expanded.value = false;
    await tester.pump();
    expect(tester.getRect(_note), middle);
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.getRect(_note).top, greaterThan(middle.top));
    final closing = tester.getRect(_note);
    await tester.tap(_main);
    await tester.pump();
    expect(tester.getRect(_note), closing);
    await tester.pumpAndSettle();
    expect(start.top - tester.getRect(_note).top, closeTo(8, 0.01));
    expect(_opacity(tester), 1);
    expect(tester.getRect(_main), anchor);
    expanded.value = false;
    await tester.pumpAndSettle();
    expect(_note, findsNothing);
  });

  testWidgets('减少动态效果和 Ticker 停用立即完成，不留半展开状态', (tester) async {
    final expanded = ValueNotifier(false);
    addTearDown(expanded.dispose);
    await tester.pumpWidget(_host(expanded));
    expanded.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(_host(expanded, reducedMotion: true));
    expect(_opacity(tester), 1);
    expanded.value = false;
    await tester.pump();
    expect(_note, findsNothing);
    await tester.pumpWidget(_host(expanded));
    expanded.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(_host(expanded, tickerEnabled: false));
    expect(_opacity(tester), 1);
    expanded.value = false;
    await tester.pump();
    expect(_note, findsNothing);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      for (final scale in [1.0, 1.3, 2.0, 3.0]) {
        testWidgets(
          '320dp dark=$dark highContrast=$highContrast scale=$scale 完整标签与热区',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(320, 640));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final expanded = ValueNotifier(true);
            addTearDown(expanded.dispose);
            var selections = 0;
            await tester.pumpWidget(
              _host(
                expanded,
                dark: dark,
                highContrast: highContrast,
                scale: scale,
                onSelect: () => selections++,
              ),
            );
            for (final entry in [_eye, _note]) {
              final rect = tester.getRect(entry);
              expect(rect.left, greaterThanOrEqualTo(16));
              expect(rect.right, lessThanOrEqualTo(304.01));
              expect(rect.top, greaterThanOrEqualTo(88));
              expect(rect.bottom, lessThanOrEqualTo(600.01));
              expect(rect.height, greaterThanOrEqualTo(56));
            }
            await tester.tapAt(
              tester.getRect(_note).centerRight - const Offset(1, 0),
            );
            expect(selections, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('超高菜单在标题以下内部滚动，所有入口可触达', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final expanded = ValueNotifier(true);
    addTearDown(expanded.dispose);
    await tester.pumpWidget(_host(expanded, scale: 3));
    final scroll = find.descendant(
      of: find.byType(QuickRecordMenu),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scroll).position.maxScrollExtent,
      greaterThan(0),
    );
    await tester.ensureVisible(_note);
    expect(tester.getRect(_note).bottom, lessThanOrEqualTo(220.01));
    expect(tester.takeException(), isNull);
  });

  for (final type in [
    EntryType.happiness,
    EntryType.reflection,
    EntryType.quickNote,
  ]) {
    testWidgets('历史补录竖排入口选择 $type', (tester) async {
      EntryType? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: HistoricalQuickRecordFab(
              expanded: true,
              onExpandedChanged: (_) {},
              onEntrySelected: (type) => selected = type,
            ),
          ),
        ),
      );
      final entries = ['happiness', 'reflection', 'quick_note']
          .map((name) => find.byKey(Key('historical_quick_record_$name')))
          .toList();
      expect(
        tester.getRect(entries[0]).bottom,
        closeTo(tester.getRect(entries[1]).top, 0.01),
      );
      expect(
        tester.getRect(entries[1]).bottom,
        closeTo(tester.getRect(entries[2]).top, 0.01),
      );
      await tester.tap(
        entries[[
          EntryType.happiness,
          EntryType.reflection,
          EntryType.quickNote,
        ].indexOf(type)],
      );
      expect(selected, type);
    });
  }
}
