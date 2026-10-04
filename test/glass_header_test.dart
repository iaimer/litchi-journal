import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_app_bar.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';

const _image = Key('glass_pixels');
const _title = Key('glass_title');
const _stripe = Key('first_stripe');
const _settings = Key('glass_settings');

void _noop() {}

Future<Uint8List> _capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_image),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }))!;
}

double _variation(Uint8List pixels, int x, int start, int end) {
  var total = 0.0;
  for (var y = start; y < end; y++) {
    final offset = (y * 320 + x) * 4;
    final next = offset + 320 * 4;
    for (final channel in [0, 1, 2]) {
      total += (pixels[offset + channel] - pixels[next + channel]).abs();
    }
  }
  return total / (end - start);
}

List<int> _foregroundPixels(Uint8List pixels, Rect rect, Color color) {
  final positions = <int>[];
  for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
    for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
      final offset = (y * 320 + x) * 4;
      if (pixels[offset] == (color.r * 255).round() &&
          pixels[offset + 1] == (color.g * 255).round() &&
          pixels[offset + 2] == (color.b * 255).round()) {
        positions.add(offset);
      }
    }
  }
  return positions;
}

Future<ScrollController> _mount(
  WidgetTester tester, {
  required ThemeData theme,
  bool glass = true,
  bool highContrast = false,
  double scale = 1,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.binding.setSurfaceSize(const Size(320, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final dark = theme.brightness == Brightness.dark;
  final alpha = dark
      ? FloraGlass.navigationDarkOpacity
      : FloraGlass.navigationLightOpacity;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 24),
          highContrast: highContrast,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: RepaintBoundary(
        key: _image,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: glass
              ? FloraAppBar(
                  glassBackground: true,
                  title: const Text('记录', key: _title),
                  actions: const [
                    IconButton(
                      key: _settings,
                      onPressed: _noop,
                      tooltip: '设置',
                      icon: FloraIcon(FloraIcons.settings),
                    ),
                  ],
                )
              : AppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  flexibleSpace: ColoredBox(
                    color: theme.colorScheme.surface.withValues(alpha: alpha),
                  ),
                  title: const Text('记录', key: _title),
                  actions: const [
                    IconButton(
                      key: _settings,
                      onPressed: _noop,
                      tooltip: '设置',
                      icon: FloraIcon(FloraIcons.settings),
                    ),
                  ],
                ),
          body: ListView(
            controller: controller,
            padding: const EdgeInsets.only(top: 80),
            children: [
              for (var index = 0; index < 300; index++)
                SizedBox(
                  key: index == 16 ? _stripe : null,
                  height: 4,
                  child: ColoredBox(
                    color: index.isEven
                        ? const Color(0xFFE05269)
                        : const Color(0xFF368ACD),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('${theme.brightness} 顶部采样真实滚动内容，不只是透明填充', (tester) async {
      final plain = await _mount(tester, theme: theme, glass: false);
      plain.jumpTo(96);
      await tester.pumpAndSettle();
      final unfiltered = await _capture(tester);
      // 对照层使用相同透明度，只移除模糊，避免透明填充造成假通过。
      await tester.pumpWidget(const SizedBox.shrink());
      final blurred = await _mount(tester, theme: theme);
      final titleBefore = tester.getRect(find.byKey(_title));
      final emptyBackdrop = await _capture(tester);
      blurred.jumpTo(96);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_stripe)).top, lessThan(80));
      expect(tester.getRect(find.byKey(_title)), titleBefore);
      final filtered = await _capture(tester);
      final style = tester
          .widget<AppBar>(find.byType(AppBar))
          .systemOverlayStyle!;
      expect(
        style.statusBarIconBrightness,
        theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      );
      for (final key in [_title, _settings]) {
        final rect = tester.getRect(find.byKey(key));
        final referenceForeground = _foregroundPixels(
          unfiltered,
          rect,
          theme.colorScheme.onSurface,
        );
        expect(referenceForeground, isNotEmpty);
        expect(
          _foregroundPixels(filtered, rect, theme.colorScheme.onSurface),
          referenceForeground,
          reason: '只柔化背景，标题和图标实色边缘不可被模糊',
        );
      }
      final referenceVariation = _variation(unfiltered, 220, 30, 68);
      expect(referenceVariation, greaterThan(20));
      expect(
        _variation(filtered, 220, 30, 68),
        lessThan(referenceVariation * 0.2),
      );
      // 背景变化必须能透过顶部；标题外的正文仍保留清晰条纹。
      expect(
        filtered[(40 * 320 + 220) * 4],
        isNot(emptyBackdrop[(40 * 320 + 220) * 4]),
      );
      expect(_variation(filtered, 220, 120, 160), greaterThan(50));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('窄屏大字体顶部保留操作热区，高对比度无模糊', (tester) async {
    final controller = await _mount(
      tester,
      theme: AppTheme.light,
      highContrast: true,
      scale: 1.3,
    );
    controller.jumpTo(96);
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    final button = tester.getSize(find.byType(IconButton));
    expect(button.width, greaterThanOrEqualTo(48));
    expect(button.height, greaterThanOrEqualTo(48));
    expect(tester.getRect(find.byKey(_title)).top, greaterThanOrEqualTo(24));
    final pixels = await _capture(tester);
    expect(_variation(pixels, 220, 30, 68), 0);
    expect(tester.takeException(), isNull);
  });
}
