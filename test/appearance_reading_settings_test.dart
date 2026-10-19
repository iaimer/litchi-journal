import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/screens/appearance_settings_page.dart';
import 'package:litchi_journal_flutter/services/ai_config_repository.dart';
import 'package:litchi_journal_flutter/services/appearance_controller.dart';
import 'package:litchi_journal_flutter/services/appearance_settings.dart';
import 'package:litchi_journal_flutter/services/appearance_settings_repository.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';

class _AppearanceStorage implements AIConfigStorage {
  String? value;
  bool gated = false;
  final failedWrites = <int>{};
  final requests = <Map<String, dynamic>>[];
  final gates = <Completer<void>>[];
  int activeWrites = 0;
  int maxConcurrentWrites = 0;

  _AppearanceStorage({AppearanceSettings? initial})
    : value = initial == null ? null : jsonEncode(initial.toJson());

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String next) async {
    final index = requests.length;
    requests.add(jsonDecode(next) as Map<String, dynamic>);
    final gate = Completer<void>();
    gates.add(gate);
    activeWrites++;
    if (activeWrites > maxConcurrentWrites) maxConcurrentWrites = activeWrites;
    try {
      if (gated) await gate.future;
      if (failedWrites.contains(index)) throw StateError('unavailable');
      value = next;
    } finally {
      activeWrites--;
    }
  }

  @override
  Future<void> delete(String key) async => value = null;
}

Future<AppearanceController> _controller(_AppearanceStorage storage) async {
  final controller = AppearanceController(
    repository: AppearanceSettingsRepository(storage: storage),
  );
  await controller.init();
  return controller;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

Widget _page(
  AppearanceController controller, {
  ThemeData? theme,
  double scale = 1,
  bool disableAnimations = false,
  bool tickerEnabled = true,
}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: disableAnimations,
    ),
    child: TickerMode(enabled: tickerEnabled, child: child!),
  ),
  home: AppearanceSettingsPage(controller: controller),
);

final _themeControl = find.byKey(const Key('appearance_theme_control'));
final _sizeControl = find.byKey(const Key('appearance_reading_size_control'));
final _preview = find.byKey(const Key('appearance_reading_preview'));

Finder _themeButton(int index) => find
    .descendant(of: _themeControl, matching: find.byType(TextButton))
    .at(index);
Finder _sizeButton(int size) => find
    .descendant(of: _sizeControl, matching: find.byType(TextButton))
    .at(AppearanceSettings.readingFontSizes.indexOf(size));

Future<void> _choose(WidgetTester tester, int size) async {
  await tester.ensureVisible(_sizeControl);
  await tester.pump();
  await tester.tap(_sizeButton(size));
  await tester.pump();
}

void main() {
  testWidgets('原生纸面三段按钮同宽同高，普通视觉40dp且热区至少48dp', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(_AppearanceStorage());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_page(controller));
    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    final mode = tester.widget<SegmentedButton<ThemeMode>>(_themeControl);
    final reading = tester.widget<SegmentedButton<int>>(_sizeControl);
    expect(mode.showSelectedIcon, isFalse);
    expect(reading.showSelectedIcon, isFalse);
    expect(mode.expandedInsets, EdgeInsets.zero);
    expect(reading.selected, {16});
    expect(tester.getSize(_themeControl), tester.getSize(_sizeControl));
    expect(tester.getSize(_themeControl).height, 48);
    expect(
      tester
              .getSize(find.byKey(const Key('appearance_theme_content_0')))
              .height +
          8,
      40,
    );
    for (var i = 0; i < 3; i++) {
      final top = tester.getRect(_themeButton(i));
      final bottom = tester.getRect(_sizeButton([14, 16, 18][i]));
      expect(top.width, closeTo(tester.getSize(_themeControl).width / 3, .01));
      expect(top.left, closeTo(bottom.left, .01));
      expect(top.height, greaterThanOrEqualTo(48));
      expect(top.width, greaterThanOrEqualTo(48));
      expect(
        tester.getRect(find.byKey(Key('appearance_theme_label_$i'))).center.dy,
        closeTo(
          tester.getRect(find.byKey(Key('appearance_theme_icon_$i'))).center.dy,
          .01,
        ),
      );
    }
    for (final control in [mode, reading]) {
      expect(control.style!.elevation!.resolve({}), 0);
      expect(
        control.style!.shape!.resolve({}),
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      );
      expect(control.style!.backgroundColor!.resolve({})!.a, 1);
      expect(
        control.style!.backgroundColor!.resolve({WidgetState.selected})!.a,
        1,
      );
      expect(control.style!.textStyle!.resolve({})!.fontSize, 14);
      expect(
        control.style!.textStyle!.resolve({WidgetState.selected})!.fontWeight,
        FontWeight.w600,
      );
    }
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byKey(const Key('appearance_reading_thumb')), findsNothing);
    expect(
      find.byKey(const Key('appearance_reading_size_slider')),
      findsNothing,
    );
    expect(find.text('正文预览'), findsOneWidget);
    for (final label in ['跟随系统', '浅色', '深色', '小', '中', '大']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('字号只接受点击，横向拖动不会切换或保存', (tester) async {
    final storage = _AppearanceStorage();
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_page(controller));
    await tester.ensureVisible(_sizeControl);
    await tester.pumpAndSettle();
    for (final delta in [120.0, -120.0]) {
      await tester.dragFrom(
        tester.getCenter(_sizeButton(16)),
        Offset(delta, 0),
      );
      await tester.pumpAndSettle();
      expect(controller.readingFontSize, 16);
      expect(storage.requests, isEmpty);
    }
    await _choose(tester, 18);
    await tester.pumpAndSettle();
    await _choose(tester, 18);
    await tester.pumpAndSettle();
    expect(controller.readingFontSize, 18);
    expect(storage.requests, hasLength(1));
  });

  testWidgets('两组选择具有互斥按钮语义，字号朗读包含实际数值', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final controller = await _controller(_AppearanceStorage());
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller));
      for (var i = 0; i < 3; i++) {
        final data = tester.getSemantics(_themeButton(i)).getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(
          data.flagsCollection.isSelected,
          i == 0 ? Tristate.isTrue : Tristate.isFalse,
        );
        expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      }
      await tester.ensureVisible(_sizeControl);
      await tester.pumpAndSettle();
      for (final size in [14, 16, 18]) {
        final data = tester.getSemantics(_sizeButton(size)).getSemanticsData();
        expect(data.label, contains('$size号'));
        expect(data.flagsCollection.isSlider, isFalse);
      }
      final node = tester.getSemantics(_sizeButton(18));
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(controller.readingFontSize, 18);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('点击保留简短颜色过渡，连续反向从当前颜色继续', (tester) async {
    final controller = await _controller(_AppearanceStorage());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_page(controller));
    final label = find.byKey(const Key('appearance_reading_label_2'));
    Color color() => DefaultTextStyle.of(tester.element(label)).style.color!;
    final start = color();
    final end = AppTheme.light.colorScheme.onPrimary;
    await controller.setReadingFontSize(18);
    await tester.pump();
    expect(color(), start);
    await tester.pump(const Duration(milliseconds: 80));
    final middle = color();
    expect(middle, isNot(start));
    expect(middle, isNot(end));
    await controller.setReadingFontSize(16);
    await tester.pump();
    expect(color(), middle);
    await tester.pumpAndSettle();
    expect(color(), start);
    expect(tester.widget<SegmentedButton<int>>(_sizeControl).selected, {16});
  });

  for (final reduced in [true, false]) {
    testWidgets('${reduced ? '减少动画' : 'Ticker停用'}时颜色切换无需等待', (tester) async {
      final controller = await _controller(_AppearanceStorage());
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller));
      await controller.setThemeMode(ThemeMode.dark);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(
        _page(controller, disableAnimations: reduced, tickerEnabled: reduced),
      );
      final mode = tester.widget<SegmentedButton<ThemeMode>>(_themeControl);
      expect(mode.selected, {ThemeMode.dark});
      expect(mode.style!.animationDuration, Duration.zero);
      expect(
        DefaultTextStyle.of(tester.element(find.text('深色'))).style.color,
        AppTheme.light.colorScheme.onPrimary,
      );
      await controller.setReadingFontSize(18);
      await tester.pump();
      expect(tester.widget<SegmentedButton<int>>(_sizeControl).selected, {18});
      expect(
        DefaultTextStyle.of(tester.element(find.text('大'))).style.color,
        AppTheme.light.colorScheme.onPrimary,
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });
  }
  test('选择立即生效，重启后从原有外观仓储恢复字号和主题', () async {
    final storage = _AppearanceStorage(
      initial: AppearanceSettings(themeMode: ThemeMode.dark),
    )..gated = true;
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    final saved = controller.setReadingFontSize(14);
    expect(controller.readingFontSize, 14);
    expect(controller.themeMode, ThemeMode.dark);
    await _flush();
    expect(jsonDecode(storage.value!)['readingFontSize'], 16);
    storage.gates.single.complete();
    await saved;
    final restarted = await _controller(storage);
    addTearDown(restarted.dispose);
    expect(restarted.readingFontSize, 14);
    expect(restarted.themeMode, ThemeMode.dark);
  });

  test('连续切换及主题修改共用串行保存，最后选择为准', () async {
    final storage = _AppearanceStorage()..gated = true;
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    final tasks = [
      controller.setReadingFontSize(14),
      controller.setReadingFontSize(18),
      controller.setReadingFontSize(16),
      controller.setThemeMode(ThemeMode.dark),
    ];
    expect(controller.readingFontSize, 16);
    expect(controller.themeMode, ThemeMode.dark);
    await _flush();
    expect(storage.requests.length, 1);
    for (var index = 0; index < tasks.length; index++) {
      storage.gates[index].complete();
      await tasks[index];
      await _flush();
    }
    expect(storage.maxConcurrentWrites, 1);
    expect(storage.requests.map((item) => item['readingFontSize']), [
      14,
      18,
      16,
      16,
    ]);
    final restarted = await _controller(storage);
    addTearDown(restarted.dispose);
    expect(restarted.readingFontSize, 16);
    expect(restarted.themeMode, ThemeMode.dark);
  });

  test('字号失败只恢复字号，排队的主题保存不能带入失败值', () async {
    final storage = _AppearanceStorage()..gated = true;
    storage.failedWrites.add(0);
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    final first = expectLater(
      controller.setReadingFontSize(14),
      throwsStateError,
    );
    final theme = controller.setThemeMode(ThemeMode.dark);
    await _flush();
    storage.gates[0].complete();
    await first;
    await _flush();
    expect(controller.readingFontSize, 16);
    expect(controller.themeMode, ThemeMode.dark);
    expect(storage.requests[1]['readingFontSize'], 16);
    storage.gates[1].complete();
    await theme;
    final restored = await _controller(storage);
    addTearDown(restored.dispose);
    expect(restored.readingFontSize, 16);
    expect(restored.themeMode, ThemeMode.dark);
  });

  test('旧请求失败不能撤销后续同值选择，失败不阻塞后续写入', () async {
    final storage = _AppearanceStorage()..gated = true;
    storage.failedWrites.add(0);
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    final first = expectLater(
      controller.setReadingFontSize(14),
      throwsStateError,
    );
    final second = controller.setReadingFontSize(18);
    final third = controller.setReadingFontSize(14);
    await _flush();
    storage.gates[0].complete();
    await first;
    await _flush();
    expect(controller.readingFontSize, 14);
    storage.gates[1].complete();
    await second;
    await _flush();
    storage.gates[2].complete();
    await third;
    expect(jsonDecode(storage.value!)['readingFontSize'], 14);
  });

  test('当前字号保存失败恢复最近一次成功值，保留已保存主题', () async {
    final storage = _AppearanceStorage();
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    await controller.setReadingFontSize(16);
    await controller.setThemeMode(ThemeMode.dark);
    storage.failedWrites.add(2);
    await expectLater(controller.setReadingFontSize(18), throwsStateError);
    expect(controller.readingFontSize, 16);
    expect(controller.themeMode, ThemeMode.dark);
  });

  test('主题保存失败不回滚成功的字号', () async {
    final storage = _AppearanceStorage();
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    await controller.setReadingFontSize(16);
    storage.failedWrites.add(1);
    await expectLater(
      controller.setThemeMode(ThemeMode.dark),
      throwsStateError,
    );
    expect(controller.readingFontSize, 16);
    expect(controller.themeMode, ThemeMode.system);
  });

  testWidgets('外观图标和文字均可切换，重复选择不保存', (tester) async {
    final storage = _AppearanceStorage();
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_page(controller));
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.dark);
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(storage.requests, hasLength(1));
    await tester.tap(find.byKey(const Key('appearance_theme_icon_1')));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.light);
    await tester.tap(find.text('跟随系统'));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.system);
    expect(storage.requests, hasLength(3));
  });

  testWidgets('真实主题链路切换浅深色及跟随系统，保留字号选择', (tester) async {
    final controller = await _controller(_AppearanceStorage());
    addTearDown(controller.dispose);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: controller.themeMode,
          home: AppearanceSettingsPage(controller: controller),
        ),
      ),
    );
    await tester.ensureVisible(_sizeControl);
    await _choose(tester, 18);
    await tester.pumpAndSettle();
    for (final label in ['深色', '浅色', '跟随系统']) {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text(label))).brightness,
        label == '浅色' ? Brightness.light : Brightness.dark,
      );
      expect(controller.readingFontSize, 18);
    }
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('跟随系统'))).brightness,
      Brightness.light,
    );
    expect(controller.themeMode, ThemeMode.system);
  });

  testWidgets('外观失败回退仅当前主题，字号成功值不受影响', (tester) async {
    final storage = _AppearanceStorage()..failedWrites.add(0);
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_page(controller));
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.system);
    expect(find.text('外观未保存，请重试'), findsOneWidget);
    storage.failedWrites.clear();
    await tester.ensureVisible(_sizeControl);
    await _choose(tester, 18);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('深色'));
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.readingFontSize, 18);
  });

  testWidgets('外观页三段选择默认中，待保存时小档预览立即生效', (tester) async {
    final storage = _AppearanceStorage()..gated = true;
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_page(controller));
    await tester.ensureVisible(_sizeControl);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(controller.readingFontSize, 16);
    for (final label in ['小', '中', '大']) {
      expect(find.text(label), findsOneWidget);
    }
    await _choose(tester, 14);
    expect(tester.widget<Text>(_preview).style?.fontSize, 14);
    expect(controller.readingFontSize, 14);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('appearance_reading_size_control')),
          )
          .height,
      greaterThanOrEqualTo(48),
    );
    storage.gates.single.complete();
    await tester.pumpAndSettle();
    expect(jsonDecode(storage.value!)['readingFontSize'], 14);
  });

  testWidgets('保存失败恢复选中项并显示固定可重试提示', (tester) async {
    final storage = _AppearanceStorage();
    storage.failedWrites.add(0);
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_page(controller));
    await tester.ensureVisible(_sizeControl);
    await _choose(tester, 14);
    await tester.pumpAndSettle();
    expect(controller.readingFontSize, 16);
    expect(find.text('字号未保存，请重试'), findsOneWidget);
    storage.failedWrites.clear();
    await _choose(tester, 14);
    await tester.pumpAndSettle();
    expect(controller.readingFontSize, 14);
    expect(jsonDecode(storage.value!)['readingFontSize'], 14);
  });

  testWidgets('旧字号请求失败不在新选择上显示过期错误', (tester) async {
    final storage = _AppearanceStorage()..gated = true;
    storage.failedWrites.add(0);
    final controller = await _controller(storage);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_page(controller));
    await tester.ensureVisible(_sizeControl);
    await _choose(tester, 14);
    await _choose(tester, 18);
    storage.gates[0].complete();
    await tester.pump();
    expect(find.text('字号未保存，请重试'), findsNothing);
    expect(controller.readingFontSize, 18);
    storage.gates[1].complete();
    await tester.pumpAndSettle();
    expect(jsonDecode(storage.value!)['readingFontSize'], 18);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final scale in [1.0, 1.3, 1.6, 2.0, 2.5, 3.0, 4.0]) {
      testWidgets('${theme.brightness} 320dp／$scale 倍字体分段按钮不重叠、同高且文字完整', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = await _controller(_AppearanceStorage());
        addTearDown(controller.dispose);
        await tester.pumpWidget(_page(controller, theme: theme, scale: scale));
        final modeSize = tester.getSize(_themeControl);
        final sizeSize = tester.getSize(_sizeControl);
        expect(modeSize, sizeSize);
        for (var i = 0; i < 3; i++) {
          final rect = tester.getRect(_themeButton(i));
          final label = tester.getRect(
            find.byKey(Key('appearance_theme_label_$i')),
          );
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(label.left, greaterThanOrEqualTo(rect.left - .01));
          expect(label.right, lessThanOrEqualTo(rect.right + .01));
          expect(label.top, greaterThanOrEqualTo(rect.top));
          expect(label.bottom, lessThanOrEqualTo(rect.bottom));
          if (i < 2) {
            expect(
              rect.right,
              closeTo(tester.getRect(_themeButton(i + 1)).left, .01),
            );
          }
          await tester.ensureVisible(_themeButton(i));
          await tester.pumpAndSettle();
          final visible = tester.getRect(_themeButton(i));
          await tester.tapAt(Offset(visible.left + 2, visible.center.dy));
          await tester.pumpAndSettle();
          expect(
            controller.themeMode,
            [ThemeMode.system, ThemeMode.light, ThemeMode.dark][i],
          );
        }
        await _choose(tester, 14);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(_preview).style!.fontSize, 14);
        expect(tester.getSize(_sizeControl).height, modeSize.height);
        await tester.ensureVisible(_preview);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
