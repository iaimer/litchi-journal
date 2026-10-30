import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:litchi_journal_flutter/models/default_tag_config.dart';
import 'package:litchi_journal_flutter/models/tag_settings.dart';
import 'package:litchi_journal_flutter/screens/reading_cache_page.dart';
import 'package:litchi_journal_flutter/screens/tag_settings_page.dart';
import 'package:litchi_journal_flutter/services/reading_cache_repository.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';

class _PreviewCache extends ReadingCacheRepository {
  @override
  Future<ReadingCacheUsage> usage() async =>
      const ReadingCacheUsage(145920, 3774874);
}

void main() {
  const output = String.fromEnvironment('SETTINGS_PREVIEW');
  setUpAll(() async {
    const fontPath = String.fromEnvironment('SETTINGS_FONT');
    if (fontPath.isEmpty) return;
    for (final family in ['SettingsPreview', 'Ahem', 'Roboto']) {
      final loader = FontLoader(family);
      loader.addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final dark in [false, true]) {
    for (final tags in [false, true]) {
      testWidgets(
        '设置真实预览 ${dark ? "dark" : "light"} ${tags ? "tags" : "cache"}',
        (tester) async {
          FlutterSecureStorage.setMockInitialValues({});
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.reset);
          final base = dark ? AppTheme.dark : AppTheme.light;
          final theme = base.copyWith(
            appBarTheme: base.appBarTheme.copyWith(
              titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
                fontFamily: 'SettingsPreview',
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: base.textButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'SettingsPreview', fontSize: 16),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: base.outlinedButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'SettingsPreview', fontSize: 16),
                ),
              ),
            ),

            textTheme: base.textTheme.apply(
              fontFamily: const String.fromEnvironment('SETTINGS_FONT').isEmpty
                  ? null
                  : 'SettingsPreview',
            ),
          );
          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('settings_preview'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: tags
                    ? TagSettingsPage(
                        initialSettings: TagSettings.fromTagConfig(
                          DefaultTagConfig.value,
                        ),
                        tagConfig: DefaultTagConfig.value,
                      )
                    : ReadingCachePage(repository: _PreviewCache()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (tags) {
            await tester.tap(find.text('亲子'));
            await tester.pumpAndSettle();
            expect(find.text('永久删除'), findsOneWidget);
          } else {
            for (final label in ['清除图片缓存', '清除全部阅读缓存']) {
              final button = find.widgetWithText(OutlinedButton, label);
              expect(button, findsOneWidget);
              final context = tester.element(button);
              final widget = tester.widget<OutlinedButton>(button);
              final shape =
                  (widget.style?.shape ??
                              Theme.of(
                                context,
                              ).outlinedButtonTheme.style!.shape)!
                          .resolve({})
                      as RoundedRectangleBorder;
              expect(shape.borderRadius, BorderRadius.circular(12));
            }
          }
          if (!tags) {
            final left = tester.getRect(
              find.widgetWithText(OutlinedButton, '清除图片缓存'),
            );
            final right = tester.getRect(
              find.widgetWithText(OutlinedButton, '清除全部阅读缓存'),
            );
            expect(left.top, closeTo(right.top, .01));
            expect(left.width, closeTo(right.width, .01));
            expect(right.left - left.right, closeTo(12, .01));
          }
          expect(tester.takeException(), isNull);
          if (output.isNotEmpty) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('settings_preview')),
            );
            await tester.runAsync(() async {
              await Directory(output).create(recursive: true);
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '$output/${tags ? "tags" : "cache"}-${dark ? "dark" : "light"}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        },
      );
    }
  }
}
