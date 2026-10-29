import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_sheet.dart';
import 'package:litchi_journal_flutter/widgets/habit_water_sheet.dart';

ThemeData _previewTheme(bool dark) {
  final theme = dark ? AppTheme.dark : AppTheme.light;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(
      fontFamily: const String.fromEnvironment('SHEET_FONT').isEmpty
          ? null
          : 'SheetPreview',
    ),
  );
}

void _openSheet(
  BuildContext context, {
  required bool water,
  required bool handle,
}) {
  if (water) {
    showHabitWaterSheet(
      context,
      current: 250,
      quickAmounts: [250, 475, 500],
      accentColor: Colors.blue,
      onQuickAmountsChanged: (_) async => true,
    );
    return;
  }
  showFloraSheet<void>(
    context: context,
    showDragHandle: handle,
    builder: (_) =>
        const SizedBox(key: Key('content'), width: 300, height: 120),
  );
}

Future<void> open(
  WidgetTester tester, {
  bool handle = true,
  bool dark = false,
  bool water = false,
  bool accessible = false,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('preview'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _previewTheme(dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(accessible ? 2 : 1),
            highContrast: accessible,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  _openSheet(context, water: water, handle: handle),
              child: const Text(
                '打开',
                style: TextStyle(
                  fontFamily: String.fromEnvironment('SHEET_FONT') == ''
                      ? null
                      : 'SheetPreview',
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    const fontPath = String.fromEnvironment('SHEET_FONT');
    if (fontPath.isEmpty) return;
    final loader = FontLoader('SheetPreview');
    loader.addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });
  for (final dark in [false, true]) {
    testWidgets('短横保留完整主题颜色 $dark', (tester) async {
      await open(tester, dark: dark);
      final handle = tester.widget<Container>(
        find.byKey(const Key('flora_sheet_handle')),
      );
      final expected =
          (dark ? AppTheme.dark : AppTheme.light).colorScheme.onSurfaceVariant;
      expect((handle.decoration! as BoxDecoration).color, expected);
    });
    testWidgets('紧凑头部尺寸与上下间距 $dark', (tester) async {
      await open(tester, dark: dark);
      final sheet = tester.getRect(find.byType(BottomSheet));
      final handle = tester.getRect(
        find.byKey(const Key('flora_sheet_handle')),
      );
      expect(handle.size, const Size(56, 4));
      expect(handle.center.dx, sheet.center.dx);
      expect(handle.top - sheet.top, 8);
      expect(
        tester.getTopLeft(find.byKey(const Key('content'))).dy - handle.bottom,
        8,
      );
      expect(sheet.height, 140);
    });
  }
  testWidgets('无短横不增加高度', (tester) async {
    await open(tester, handle: false);
    expect(find.byKey(const Key('flora_sheet_handle')), findsNothing);
    expect(tester.getSize(find.byType(BottomSheet)).height, 120);
  });
  testWidgets('饮水按钮保持高度及紧凑间距', (tester) async {
    const preview = String.fromEnvironment('SHEET_PREVIEW');
    if (preview.isNotEmpty) {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await open(
      tester,
      water: true,
      dark: const bool.fromEnvironment('SHEET_DARK'),
    );
    final handle = tester.getRect(find.byKey(const Key('flora_sheet_handle')));
    final button = tester.getRect(
      find.byKey(const ValueKey('habit_water_quick_250')),
    );
    expect(button.top - handle.bottom, 12);
    expect(button.height, 56);
    if (preview.isNotEmpty) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(preview).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('手动输入'));
    await tester.pumpAndSettle();
    expect(find.text('手动输入饮水量'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('窄屏大字高对比度与键盘过渡仍可操作', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);
    await open(tester, water: true, accessible: true);
    for (final label in ['+250', '+475', '+500', '手动输入', '清零', '自定义预设']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    await tester.tap(find.text('手动输入'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('添加').hitTestable(), findsOneWidget);
  });
  for (final systemBack in [false, true]) {
    testWidgets('遮罩或系统返回关闭 $systemBack', (tester) async {
      await open(tester);
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tapAt(const Offset(10, 10));
      }
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });
  }
  testWidgets('面板提供无障碍关闭动作', (tester) async {
    final semantics = tester.ensureSemantics();

    await open(tester);
    final node = tester.getSemantics(
      find.byKey(const Key('flora_sheet_dismiss')),
    );
    expect(
      node.getSemanticsData().hasAction(ui.SemanticsAction.dismiss),
      isTrue,
    );
    tester.binding.performSemanticsAction(
      ui.SemanticsActionEvent(
        type: ui.SemanticsAction.dismiss,
        viewId: tester.view.viewId,
        nodeId: node.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    semantics.dispose();
  });
  testWidgets('原生下拉回弹与关闭', (tester) async {
    await open(tester);
    await tester.drag(
      find.byKey(const Key('flora_sheet_handle')),
      const Offset(0, 8),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('flora_sheet_handle')),
      const Offset(0, 180),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}
