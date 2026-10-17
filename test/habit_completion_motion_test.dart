import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/models/habit_settings.dart';
import 'package:litchi_journal_flutter/services/markdown_parser.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/habit_card.dart';

const _captureKey = ValueKey('habit_motion_capture');
const _preview = bool.fromEnvironment('WRITE_HABIT_PREVIEW');
const _previewDir = '/tmp/litchi-habit-motion-preview';

HabitSection _section(String rows) => const MarkdownParser()
    .parse('## 习惯打卡\n$rows')
    .sections
    .whereType<HabitSection>()
    .single;

class _Harness extends StatefulWidget {
  final HabitSection section;
  final Future<bool> Function(HabitStatus) save;
  final HabitSettings settings;
  final bool dark;
  final double scale;

  const _Harness({
    super.key,
    required this.section,
    required this.save,
    this.settings = HabitSettings.defaults,
    this.dark = false,
    this.scale = 1,
  });

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  void update(VoidCallback action) => setState(action);
  bool reduced = false;
  bool ticking = true;
  late HabitSection section = widget.section;
  late HabitSettings settings = widget.settings;
  DateTime date = DateTime(2026, 10, 17);

  @override
  Widget build(BuildContext context) {
    var theme = widget.dark ? AppTheme.dark : AppTheme.light;
    if (_preview) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'HabitPreview'),
      );
    }
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduced,
              textScaler: TextScaler.linear(widget.scale),
            ),
            child: TickerMode(
              enabled: ticking,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: _captureKey,
                  child: HabitCard(
                    section: section,
                    diaryDate: date,
                    habitSettings: settings,
                    activeHabitKeys: settings.activeKeys.toSet(),
                    onUpdate: widget.save,
                    onCustomCheckboxToggle: (_, _) =>
                        widget.save(HabitStatus.fromHabitSection(section)),
                    onStartDuration: (_) async => true,
                    onDurationUpdate: (_, _, _) =>
                        widget.save(HabitStatus.fromHabitSection(section)),
                    onCustomDurationUpdate: (_, _, _) =>
                        widget.save(HabitStatus.fromHabitSection(section)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<img.Image> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      return img.decodePng(bytes.buffer.asUint8List())!;
    } finally {
      image.dispose();
    }
  }))!;
}

Future<img.Image> _mark(WidgetTester tester, String key) async {
  final image = await _pixels(tester);
  final origin = tester.getRect(find.byKey(_captureKey)).topLeft;
  final center =
      tester.getCenter(find.byKey(ValueKey('habit_status_$key'))) - origin;
  return img.copyCrop(
    image,
    x: ((center.dx - 14) * 3).round(),
    y: ((center.dy - 14) * 3).round(),
    width: 84,
    height: 84,
  );
}

int _white(img.Image image) =>
    image.where((p) => p.r > 220 && p.g > 220 && p.b > 220 && p.a > 220).length;

int _changed(img.Image a, img.Image b, {bool outside = false}) {
  var count = 0;
  for (var y = 0; y < a.height; y++) {
    for (var x = 0; x < a.width; x++) {
      if (outside &&
          (Offset(x.toDouble(), y.toDouble()) - const Offset(42, 42)).distance <
              31) {
        continue;
      }
      final p = a.getPixel(x, y);
      final q = b.getPixel(x, y);
      if ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs() > 15) {
        count++;
      }
    }
  }
  return count;
}

Future<void> _mount(
  WidgetTester tester,
  _Harness harness, {
  double width = 393,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(harness);
  await tester.pumpAndSettle();
}

Future<void> _record(WidgetTester tester, String key, int value) async {
  if (key == 'water') {
    await tester.tap(find.byKey(const ValueKey('habit_progress_water')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+250'));
  } else if (key == 'steps') {
    await tester.tap(find.byKey(const ValueKey('habit_progress_steps')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('habit_steps_input')),
      '$value',
    );
    await tester.tap(find.byKey(const ValueKey('habit_steps_save')));
  } else if (key == 'custom_check') {
    await tester.tap(find.text('晨间习惯'));
  } else {
    await tester.longPress(find.byKey(ValueKey('duration_row_$key')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '$value');
    await tester.tap(find.text('设为'));
  }
  await tester.pump();
  await tester.pump();
}

Future<void> _advance(WidgetTester tester, int milliseconds) async {
  for (var elapsed = 0; elapsed < milliseconds; elapsed += 20) {
    await tester.pump(
      Duration(milliseconds: (milliseconds - elapsed).clamp(0, 20)),
    );
  }
}

void _expectFinalMark(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byKey(
        const ValueKey('habit_status_supplements'),
        skipOffstage: false,
      ),
      matching: find.byType(CustomPaint, skipOffstage: false),
      skipOffstage: false,
    ),
  );
  final dynamic painter = paint.painter;
  expect(painter.fill, 1);
  expect(painter.stroke, 1);
  expect(painter.strokeOpacity, 1);
  expect(painter.celebration, 1);
}

void main() {
  for (final key in ['reading', 'language']) {
    final label = key == 'reading' ? '阅读/亲子共读' : '学语言';
    for (final saved in [true, false]) {
      testWidgets('$key 提高目标后再次达标${saved ? '成功庆祝' : '失败回滚'}', (tester) async {
        final pending = Completer<bool>();
        await _mount(
          tester,
          _Harness(
            section: _section('- [x] $label 5 分钟'),
            settings: HabitSettings.defaults.copyWith(
              durationDailyTargetMap: {key: 10},
            ),
            save: (_) => pending.future,
          ),
        );
        final before = await _mark(tester, key);
        await _record(tester, key, 10);
        await _advance(tester, 120);
        final short = await _mark(tester, key);
        await _advance(tester, 280);
        final complete = await _mark(tester, key);
        expect(_white(short), lessThan(_white(complete)));
        await _advance(tester, 80);
        expect(_changed(complete, await _mark(tester, key)), 0);
        pending.complete(saved);
        await tester.pump();
        await tester.pump();
        await _advance(tester, 80);
        final result = await _mark(tester, key);
        expect(
          _changed(complete, result, outside: true),
          saved ? greaterThan(0) : 0,
        );
        await tester.pumpAndSettle();
        if (!saved) {
          expect(_changed(before, await _mark(tester, key)), 0);
          expect(find.text('更新失败'), findsOneWidget);
        }
      });
    }

    for (final legacy in [false, true]) {
      testWidgets('$key ${legacy ? '旧勾选无分钟' : '降低目标后已达标'}不补播动画', (
        tester,
      ) async {
        await _mount(
          tester,
          _Harness(
            section: _section(legacy ? '- [x] $label' : '- [ ] $label 10 分钟'),
            settings: HabitSettings.defaults.copyWith(
              durationDailyTargetMap: {key: 5},
            ),
            save: (_) async => true,
          ),
        );
        final before = await _mark(tester, key);
        await _record(tester, key, legacy ? 5 : 11);
        for (final elapsed in [120, 280, 80, 140]) {
          await _advance(tester, elapsed);
          expect(_changed(before, await _mark(tester, key)), 0);
        }
        await tester.pumpAndSettle();
      });
    }

    testWidgets('$key 纯打卡仍按勾选值触发动画', (tester) async {
      await _mount(
        tester,
        _Harness(
          section: _section('- [ ] $label'),
          settings: HabitSettings.defaults.copyWith(
            trackingTypeMap: {key: HabitTrackingType.checkbox},
            durationDailyTargetMap: {key: 10},
          ),
          save: (_) async => true,
        ),
      );
      await tester.tap(find.byKey(ValueKey('habit_status_$key')));
      await tester.pump();
      await _advance(tester, 120);
      final short = await _mark(tester, key);
      await _advance(tester, 280);
      expect(_white(short), lessThan(_white(await _mark(tester, key))));
      await tester.pumpAndSettle();
    });
  }

  for (final scenario in [
    (key: 'water', raw: '- 饮水 1250 mL', target: 0, value: 1500),
    (key: 'steps', raw: '- 运动 5999 步', target: 0, value: 6000),
    (key: 'reading', raw: '- [ ] 阅读/亲子共读 0 分钟', target: 10, value: 10),
    (key: 'reading', raw: '- [ ] 阅读/亲子共读 0 分钟', target: 0, value: 1),
    (key: 'custom_read', raw: '- [ ] 阅读/亲子共读 0 分钟', target: 10, value: 10),
    (key: 'custom_read', raw: '- [ ] 阅读/亲子共读 0 分钟', target: 0, value: 1),
    (key: 'custom_check', raw: '- [ ] 补充剂', target: 0, value: 1),
  ]) {
    testWidgets('${scenario.key} 目标${scenario.target}完成只在成功后庆祝', (
      tester,
    ) async {
      final pending = Completer<bool>();
      final settings = HabitSettings.defaults.copyWith(
        statusMap: {
          'water': true,
          'steps': true,
          'reading': true,
          'supplements': true,
          'custom_read': true,
          'custom_check': true,
        },
        extraHabits: {'custom_read': '专注阅读', 'custom_check': '晨间习惯'},
        trackingTypeMap: {'custom_read': HabitTrackingType.duration},
        durationDailyTargetMap: scenario.target == 0
            ? {}
            : {scenario.key: scenario.target},
      );
      await _mount(
        tester,
        _Harness(
          section: _section(scenario.raw),
          settings: settings,
          save: (_) => pending.future,
        ),
      );
      final before = await _mark(tester, scenario.key);
      await _record(tester, scenario.key, scenario.value);
      await tester.pump(const Duration(milliseconds: 120));
      final short = await _mark(tester, scenario.key);
      await tester.pump(const Duration(milliseconds: 280));
      final completed = await _mark(tester, scenario.key);
      expect(_changed(before, short), greaterThan(0));
      expect(_white(short), lessThan(_white(completed)));
      await tester.pump(const Duration(seconds: 1));
      expect(_changed(completed, await _mark(tester, scenario.key)), 0);
      pending.complete(true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        _changed(completed, await _mark(tester, scenario.key), outside: true),
        greaterThan(0),
      );
      await tester.pumpAndSettle();
    });
  }

  for (final scenario in [
    (key: 'water', raw: '- 饮水 250 mL', value: 500),
    (key: 'water', raw: '- 饮水 1500 mL', value: 1750),
    (key: 'steps', raw: '- 运动 3000 步', value: 4000),
    (key: 'steps', raw: '- 运动 6000 步', value: 6500),
    (key: 'steps', raw: '- 运动 3000 步', value: 0),
    (key: 'steps', raw: '- 运动 6000 步', value: 6000),
    (key: 'reading', raw: '- [x] 阅读/亲子共读 10 分钟', value: 15),
    (key: 'reading', raw: '- [ ] 阅读/亲子共读 0 分钟', value: 5),
    (key: 'reading', raw: '- [x] 阅读/亲子共读 15 分钟', value: 0),
  ]) {
    testWidgets('${scenario.key}普通数值更新到${scenario.value}不庆祝', (tester) async {
      final settings = HabitSettings.defaults.copyWith(
        durationDailyTargetMap: {'reading': 10},
      );
      await _mount(
        tester,
        _Harness(
          section: _section(scenario.raw),
          settings: settings,
          save: (_) async => true,
        ),
      );
      final before = await _mark(tester, scenario.key);
      await _record(tester, scenario.key, scenario.value);
      for (final elapsed in [120, 280, 80, 140]) {
        await _advance(tester, elapsed);
        expect(
          _changed(before, await _mark(tester, scenario.key), outside: true),
          0,
        );
      }
      await tester.pumpAndSettle();
      final completed = await _mark(tester, scenario.key);
      await tester.pump(const Duration(milliseconds: 120));
      expect(_changed(completed, await _mark(tester, scenario.key)), 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_changed(completed, await _mark(tester, scenario.key)), 0);
    });
  }

  for (final key in ['water', 'steps', 'reading', 'custom_check']) {
    testWidgets('$key保存失败恢复原状态且不庆祝', (tester) async {
      final pending = Completer<bool>();
      final settings = HabitSettings.defaults.copyWith(
        statusMap: {
          'water': true,
          'steps': true,
          'reading': true,
          'custom_check': true,
        },
        extraHabits: {'custom_check': '晨间习惯'},
      );
      final raw = key == 'water'
          ? '- 饮水 1250 mL'
          : key == 'steps'
          ? '- 运动 5999 步'
          : '- [ ] 阅读/亲子共读 0 分钟';
      await _mount(
        tester,
        _Harness(
          section: _section(raw),
          settings: settings,
          save: (_) => pending.future,
        ),
      );
      final before = await _mark(tester, key);
      await _record(tester, key, key == 'steps' ? 6000 : 1);
      await _advance(tester, 120);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(_changed(before, await _mark(tester, key)), 0);
      expect(find.text('更新失败'), findsOneWidget);
    });
  }

  testWidgets('逐笔实际像素依次出现，保存提前成功仍等待画完', (tester) async {
    final pending = Completer<bool>();
    await _mount(
      tester,
      _Harness(section: _section('- [ ] 补充剂'), save: (_) => pending.future),
    );
    final before = await _mark(tester, 'supplements');
    final rect = tester.getRect(
      find.byKey(const ValueKey('habit_status_supplements')),
    );
    await tester.tap(find.text('补充剂'));
    await tester.pump();
    pending.complete(true);
    await tester.pump();
    final zero = await _mark(tester, 'supplements');
    await tester.pump(const Duration(milliseconds: 120));
    final short = await _mark(tester, 'supplements');
    await tester.pump(const Duration(milliseconds: 140));
    final partial = await _mark(tester, 'supplements');
    await _advance(tester, 140);
    final complete = await _mark(tester, 'supplements');
    await tester.pump();
    await _advance(tester, 80);
    final burst = await _mark(tester, 'supplements');
    await _advance(tester, 180);
    final settled = await _mark(tester, 'supplements');
    expect(_changed(before, zero), 0);
    expect(_white(short), greaterThan(0));
    expect(_white(partial), greaterThan(_white(short)));
    expect(_white(complete), greaterThan(_white(partial)));
    expect(_changed(short, settled, outside: true), 0);
    expect(_changed(burst, settled, outside: true), greaterThan(0));
    expect(
      tester.getRect(find.byKey(const ValueKey('habit_status_supplements'))),
      rect,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(_changed(settled, await _mark(tester, 'supplements')), 0);
  });

  testWidgets('慢请求画完静候，成功才庆祝且重复点击不并发', (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    await _mount(
      tester,
      _Harness(
        section: _section('- [ ] 补充剂'),
        save: (_) {
          calls++;
          return pending.future;
        },
      ),
    );
    await tester.tap(find.text('补充剂'));
    await tester.pump();
    await tester.tap(find.text('补充剂'));
    await tester.pump(const Duration(milliseconds: 500));
    final waiting = await _mark(tester, 'supplements');
    await tester.pump(const Duration(seconds: 2));
    expect(_changed(waiting, await _mark(tester, 'supplements')), 0);
    expect(calls, 1);
    pending.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      _changed(waiting, await _mark(tester, 'supplements'), outside: true),
      greaterThan(0),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('失败冻结半勾淡出，不倒画或庆祝', (tester) async {
    final pending = Completer<bool>();
    await _mount(
      tester,
      _Harness(section: _section('- [ ] 补充剂'), save: (_) => pending.future),
    );
    final before = await _mark(tester, 'supplements');
    await tester.tap(find.text('补充剂'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final short = await _mark(tester, 'supplements');
    pending.complete(false);
    await tester.pump();
    await tester.pump();
    expect(_changed(short, await _mark(tester, 'supplements')), 0);
    await _advance(tester, 80);
    final fading = await _mark(tester, 'supplements');
    expect(_changed(fading, before), greaterThan(0));
    expect(_changed(short, fading, outside: true), 0);
    await _advance(tester, 100);
    expect(_changed(before, await _mark(tester, 'supplements')), 0);
    expect(find.text('更新失败'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  for (final interruption in [
    'reduce',
    'ticker',
    'date',
    'archive',
    'background',
    'route',
  ]) {
    for (final scenario in [
      (name: '画勾中', milliseconds: 120, earlySuccess: false, lateSuccess: false),
      (
        name: '恢复后保存成功',
        milliseconds: 120,
        earlySuccess: false,
        lateSuccess: true,
      ),
      (name: '庆祝中', milliseconds: 480, earlySuccess: true, lateSuccess: false),
    ]) {
      testWidgets('$interruption ${scenario.name}立即结束且不补播', (tester) async {
        addTearDown(() {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        });
        final key = GlobalKey<_HarnessState>();
        final pending = Completer<bool>();
        await _mount(
          tester,
          _Harness(
            key: key,
            section: _section('- [ ] 补充剂'),
            save: (_) => pending.future,
          ),
        );
        await tester.tap(find.text('补充剂'));
        await tester.pump();
        await tester.pump();
        if (scenario.earlySuccess) {
          pending.complete(true);
          await tester.pump();
          await tester.pump();
        }
        await _advance(tester, scenario.milliseconds);
        if (interruption == 'background') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        } else if (interruption == 'route') {
          Navigator.of(tester.element(find.byType(HabitCard))).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('其他页面')),
            ),
          );
        } else {
          key.currentState!.update(() {
            if (interruption == 'reduce') key.currentState!.reduced = true;
            if (interruption == 'ticker') key.currentState!.ticking = false;
            if (interruption == 'date') {
              key.currentState!.date = DateTime(2026, 10, 18);
            }
            if (interruption == 'archive') {
              key.currentState!.settings = HabitSettings.defaults.copyWith(
                statusMap: {'supplements': false},
              );
            }
          });
        }
        await tester.pump();
        if (interruption == 'archive') {
          expect(
            find.byKey(const ValueKey('habit_status_supplements')),
            findsNothing,
          );
        } else {
          _expectFinalMark(tester);
        }
        if (!scenario.earlySuccess && !scenario.lateSuccess) {
          pending.complete(true);
          await tester.pump();
        }
        await _advance(tester, 400);
        if (interruption != 'archive') _expectFinalMark(tester);
        if (interruption == 'background') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        } else if (interruption == 'route') {
          Navigator.of(tester.element(find.text('其他页面'))).pop();
        } else {
          key.currentState!.update(() {
            key.currentState!.reduced = false;
            key.currentState!.ticking = true;
            if (interruption == 'archive') {
              key.currentState!.settings = HabitSettings.defaults;
            }
          });
        }
        await tester.pump();
        _expectFinalMark(tester);
        final resumed = await _mark(tester, 'supplements');
        if (scenario.lateSuccess) {
          pending.complete(true);
          await tester.pump();
        }
        for (final elapsed in [20, 60, 140, 180, 220]) {
          await _advance(tester, elapsed);
          _expectFinalMark(tester);
          expect(_changed(resumed, await _mark(tester, 'supplements')), 0);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets('加载与后台同步直接显示完整勾，不触发动画', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await _mount(
      tester,
      _Harness(
        key: key,
        section: _section('- [x] 补充剂'),
        save: (_) async => true,
      ),
    );
    final initial = await _mark(tester, 'supplements');
    key.currentState!.update(() {
      key.currentState!.section = _section('- [ ] 补充剂');
    });
    await tester.pump();
    key.currentState!.update(() {
      key.currentState!.section = _section('- [x] 补充剂');
    });
    await tester.pump();
    expect(_changed(initial, await _mark(tester, 'supplements')), 0);
    await tester.pump(const Duration(milliseconds: 120));
    expect(_changed(initial, await _mark(tester, 'supplements')), 0);
  });

  testWidgets('取消后重新完成仍逐笔绘制并只庆祝一次', (tester) async {
    await _mount(
      tester,
      _Harness(section: _section('- [ ] 补充剂'), save: (_) async => true),
    );
    await tester.tap(find.text('补充剂'));
    await tester.pumpAndSettle();
    final completed = await _mark(tester, 'supplements');
    await tester.tap(find.text('补充剂'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('补充剂'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      _white(await _mark(tester, 'supplements')),
      lessThan(_white(completed)),
    );
    await tester.pump(const Duration(milliseconds: 360));
    expect(
      _changed(completed, await _mark(tester, 'supplements'), outside: true),
      greaterThan(0),
    );
    await tester.pumpAndSettle();
  });

  for (final dark in [false, true]) {
    testWidgets('${dark ? '深色' : '浅色'}窄屏大字体布局稳定', (tester) async {
      await _mount(
        tester,
        _Harness(
          dark: dark,
          scale: 1.3,
          section: _section('- 饮水 1250 mL\n- 运动 6000 步\n- [ ] 补充剂'),
          save: (_) async => true,
        ),
        width: 320,
      );
      final before = tester.getRect(find.byType(HabitCard));
      final track = tester.getRect(
        find.byKey(const ValueKey('habit_progress_track_饮水')),
      );
      await tester.tap(find.text('补充剂'));
      await tester.pump();
      for (final delta in [120, 140, 140, 80, 140]) {
        await tester.pump(Duration(milliseconds: delta));
        expect(tester.getRect(find.byType(HabitCard)), before);
        expect(
          tester.getRect(find.byKey(const ValueKey('habit_progress_track_饮水'))),
          track,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  if (_preview) {
    for (final dark in [false, true]) {
      testWidgets('导出${dark ? '深色' : '浅色'}真实动效预览', (tester) async {
        await tester.runAsync(() async {
          final loader = FontLoader('HabitPreview');
          loader.addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  '/System/Library/Fonts/Hiragino Sans GB.ttc',
                ).readAsBytes(),
              ),
            ),
          );
          await loader.load();
          await Directory(_previewDir).create(recursive: true);
        });
        await _mount(
          tester,
          _Harness(
            dark: dark,
            section: _section(
              '- 饮水 750 mL\n- 运动 3000 步\n- [ ] 阅读/亲子共读\n- [ ] 学语言\n- [ ] 补充剂',
            ),
            save: (_) async => true,
          ),
        );
        final theme = dark ? 'dark' : 'light';
        final frames = <img.Image>[];
        await tester.tap(find.text('补充剂'));
        await tester.pump();
        for (var ms = 0; ms <= 1000; ms += 20) {
          if (ms > 0) await tester.pump(const Duration(milliseconds: 20));
          final frame = await _pixels(tester);
          frames.add(frame);
          if ([0, 120, 260, 400, 480, 620].contains(ms)) {
            await tester.runAsync(
              () async => File(
                '$_previewDir/$theme-$ms.png',
              ).writeAsBytes(img.encodePng(frame)),
            );
          }
        }
        await tester.runAsync(() async {
          final encoder = img.GifEncoder(repeat: 0);
          for (final frame in frames) {
            encoder.addFrame(frame, duration: 2);
          }
          encoder.addFrame(frames.last, duration: 80);
          await File('$_previewDir/$theme.gif').writeAsBytes(encoder.finish()!);
          final selected = [0, 6, 13, 20, 24, 31];
          final width = frames.first.width;
          final height = frames.first.height;
          final board = img.Image(width: width * 3, height: (height + 48) * 2);
          img.fill(
            board,
            color: dark
                ? img.ColorRgb8(31, 27, 24)
                : img.ColorRgb8(247, 242, 234),
          );
          for (var i = 0; i < selected.length; i++) {
            final x = i % 3 * width;
            final y = i ~/ 3 * (height + 48);
            img.drawString(
              board,
              '${selected[i] * 20} ms',
              font: img.arial24,
              x: x + 24,
              y: y + 8,
              color: dark
                  ? img.ColorRgb8(235, 225, 210)
                  : img.ColorRgb8(90, 74, 54),
            );
            img.compositeImage(
              board,
              frames[selected[i]],
              dstX: x,
              dstY: y + 48,
            );
          }
          await File(
            '$_previewDir/$theme-storyboard.png',
          ).writeAsBytes(img.encodePng(board));
        });
      });
    }
  }
}
