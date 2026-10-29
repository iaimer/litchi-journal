import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/reading_cache_status.dart';

Future<void> _mount(
  WidgetTester tester, {
  required double width,
  required double scale,
  required bool dark,
  String? message,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: (dark ? AppTheme.dark : AppTheme.light).copyWith(
        textTheme: (dark ? AppTheme.dark : AppTheme.light).textTheme.apply(
          fontFamily: const String.fromEnvironment('CACHE_PREVIEW_FONT').isEmpty
              ? null
              : 'CachePreview',
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          highContrast: scale == 4,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: RepaintBoundary(
            key: const Key('cache_preview'),
            child: ReadingCacheStatus(message: message),
          ),
        ),
      ),
    ),
  );
}

Future<void> _preview(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('CACHE_PREVIEW_DIR');
  if (output.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('cache_preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$output/$name.png').writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    const path = String.fromEnvironment('CACHE_PREVIEW_FONT');
    if (path.isEmpty) return;
    final loader = FontLoader('CachePreview');
    loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0, 3.0, 4.0]) {
      for (final dark in [false, true]) {
        testWidgets('缓存提示单行 width=$width scale=$scale dark=$dark', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          await _mount(tester, width: width, scale: scale, dark: dark);
          expect(find.text('正在显示本地缓存'), findsOneWidget);
          expect(find.text('重试'), findsNothing);
          expect(find.textContaining('上次更新'), findsNothing);
          final text = tester.widget<Text>(find.text('正在显示本地缓存'));
          expect(text.maxLines, 1);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text('正在显示本地缓存'),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final fitted = find.ancestor(
            of: find.text('正在显示本地缓存'),
            matching: find.byType(FittedBox),
          );
          expect(tester.widget<FittedBox>(fitted).fit, BoxFit.scaleDown);
          final box = tester.getRect(fitted);
          expect(box.right, lessThanOrEqualTo(width - 16));
          final paintedText = tester.getRect(find.text('正在显示本地缓存'));
          expect(paintedText.right, lessThanOrEqualTo(box.right + 0.01));
          expect(paintedText.left, greaterThanOrEqualTo(box.left - 0.01));
          expect(find.bySemanticsLabel('正在显示本地缓存'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (width == 390 && scale == 1) {
            await _preview(tester, dark ? 'dark' : 'light');
          }
          semantics.dispose();
        });
      }
    }
  }
  for (final dark in [false, true]) {
    testWidgets('提示条实际颜色对比度 dark=$dark', (tester) async {
      await _mount(tester, width: 390, scale: 1, dark: dark);
      final text = tester.widget<Text>(find.text('正在显示本地缓存'));
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ReadingCacheStatus),
          matching: find.byType(Container),
        ),
      );
      final background = (container.decoration! as BoxDecoration).color!;
      final a = text.style!.color!.computeLuminance();
      final b = background.computeLuminance();
      expect(
        ((a > b ? a : b) + 0.05) / ((a < b ? a : b) + 0.05),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
  testWidgets('长错误完整显示并取代缓存文案', (tester) async {
    const message = '服务器返回的日记数据无法解析，请重试或检查服务器版本';
    await _mount(tester, width: 320, scale: 4, dark: false, message: message);
    expect(find.text('正在显示本地缓存'), findsNothing);
    final text = tester.widget<Text>(find.text(message));
    expect(text.maxLines, 1);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(
      tester
          .renderObject<RenderParagraph>(find.text(message))
          .didExceedMaxLines,
      isFalse,
    );
    expect(tester.takeException(), isNull);
    await _preview(tester, 'long-error');
  });
}
