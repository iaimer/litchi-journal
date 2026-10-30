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
import 'package:litchi_journal_flutter/screens/remote_api_page.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/screens/tag_settings_page.dart';
import 'package:litchi_journal_flutter/services/reading_cache_repository.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';

class _PreviewCache extends ReadingCacheRepository {
  @override
  Future<ReadingCacheUsage> usage() async =>
      const ReadingCacheUsage(145920, 3774874);
}

ThemeData _previewTheme(bool dark) {
  final base = dark ? AppTheme.dark : AppTheme.light;
  final font = const String.fromEnvironment('SETTINGS_FONT').isEmpty
      ? null
      : 'SettingsPreview';
  final text = WidgetStatePropertyAll(
    TextStyle(fontFamily: font, fontSize: 16),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: font),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: font,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(textStyle: text),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: base.elevatedButtonTheme.style?.copyWith(textStyle: text),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.copyWith(textStyle: text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(textStyle: text),
    ),
  );
}

Future<void> _export(WidgetTester tester, String output, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('settings_preview')),
  );
  await tester.runAsync(() async {
    await Directory(output).create(recursive: true);
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
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
    for (final scale in [1.0, 2.0]) {
      testWidgets('服务器连接表单预览 dark=$dark scale=$scale', (tester) async {
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('server_preview'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _previewTheme(dark),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: RemoteApiPage(
                apiConfig: ApiConfig(
                  baseUrl: 'https://journal.example',
                  token: 'x' * 32,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final left = tester.getRect(
          find.widgetWithText(OutlinedButton, '测试连接'),
        );
        final right = tester.getRect(find.widgetWithText(ElevatedButton, '保存'));
        expect(left.top, right.top);
        expect(left.size, right.size);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('server_token')))
              .obscureText,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        if (output.isNotEmpty && scale == 1) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('server_preview')),
          );
          await tester.runAsync(() async {
            await Directory(output).create(recursive: true);
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$output/server-${dark ? "dark" : "light"}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
  for (final dark in [false, true]) {
    for (final tags in [false, true]) {
      testWidgets(
        '设置真实预览 ${dark ? "dark" : "light"} ${tags ? "tags" : "cache"}',
        (tester) async {
          FlutterSecureStorage.setMockInitialValues({});
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.reset);
          final theme = _previewTheme(dark);
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
            final restore = find.widgetWithText(OutlinedButton, '恢复全部默认');
            await tester.scrollUntilVisible(
              restore,
              400,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pumpAndSettle();
            expect(tester.getSize(restore).width, 358);
            if (output.isNotEmpty) {
              await _export(
                tester,
                output,
                'tags-list-${dark ? "dark" : "light"}',
              );
            }
            await tester.scrollUntilVisible(
              find.text('亲子'),
              -400,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('亲子'));
            await tester.pumpAndSettle();
            expect(find.text('永久删除'), findsOneWidget);
            final lastAction = tester.getRect(
              find.widgetWithText(TextButton, '永久删除'),
            );
            final sheet = tester.getRect(find.byType(BottomSheet));
            expect(lastAction.bottom, closeTo(sheet.bottom, .01));
          } else {
            for (final label in ['清除图片缓存', '清除全部阅读缓存']) {
              final button = find.widgetWithText(
                label == '清除图片缓存' ? OutlinedButton : ElevatedButton,
                label,
              );
              expect(button, findsOneWidget);
              final context = tester.element(button);
              final widget = tester.widget<ButtonStyleButton>(button);
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
              find.widgetWithText(ElevatedButton, '清除全部阅读缓存'),
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
