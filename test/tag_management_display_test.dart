import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/models/default_tag_config.dart';
import 'package:litchi_journal_flutter/models/tag_settings.dart';
import 'package:litchi_journal_flutter/screens/tag_settings_page.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';

ThemeData _previewTheme(bool dark) {
  final theme = dark ? AppTheme.dark : AppTheme.light;
  if (const String.fromEnvironment('TAG_PREVIEW_FONT').isEmpty) return theme;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'TagPreview'),
    textButtonTheme: TextButtonThemeData(
      style: theme.textButtonTheme.style?.copyWith(
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'TagPreview', fontSize: 16),
        ),
      ),
    ),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'TagPreview',
      ),
    ),
  );
}

Future<void> _mount(
  WidgetTester tester,
  TagSettings settings, {
  bool dark = false,
  bool accessible = false,
}) async {
  await tester.binding.setSurfaceSize(Size(accessible ? 320 : 390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('preview'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _previewTheme(dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            highContrast: accessible,
            textScaler: TextScaler.linear(accessible ? 2 : 1),
          ),
          child: child!,
        ),
        home: TagSettingsPage(
          initialSettings: settings,
          tagConfig: DefaultTagConfig.value,
        ),
      ),
    ),
  );
}

Future<void> _savePreview(WidgetTester tester, bool dark) async {
  const output = String.fromEnvironment('TAG_PREVIEW_DIR');
  if (output.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$output/${dark ? 'dark' : 'light'}.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void _expectMenu(
  WidgetTester tester, {
  bool renamed = false,
  bool enabled = true,
  bool dark = false,
  bool accessible = false,
}) {
  expect(find.text('取消'), findsNothing);
  expect(find.text(enabled ? '停用' : '启用'), findsOneWidget);
  expect(find.text('恢复默认'), renamed ? findsOneWidget : findsNothing);
  final dividers = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(Divider),
  );
  expect(dividers, findsNWidgets(renamed ? 4 : 3));
  final theme = dark ? AppTheme.dark : AppTheme.light;
  for (final divider in tester.widgetList<Divider>(dividers)) {
    expect(divider.thickness, 1);
    expect(
      divider.color,
      accessible ? theme.dividerColor : theme.dividerColor.withAlpha(120),
    );
  }
  expect(tester.takeException(), isNull);
}

String _configureEntry(TagSettings settings, String kind, bool modified) {
  final domain = settings.domainSettings.first;
  final dynamic entry = switch (kind) {
    '领域' => domain,
    '主题' => domain.topics.first,
    _ => settings.methodSettings.first,
  };
  if (modified) {
    entry.displayName = '自定义$kind';
    entry.enabled = false;
  }
  return entry.displayName as String;
}

Future<void> _openEntry(WidgetTester tester, String name) async {
  await tester.tap(find.text(name).first);
  await tester.pumpAndSettle();
}

Future<void> _cancelAction(
  WidgetTester tester,
  String name,
  String action,
) async {
  await _openEntry(tester, name);
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
  if (action == '编辑') {
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '未保存名称');
    await tester.binding.handlePopRoute();
  } else {
    expect(find.text('永久删除「$name」？'), findsOneWidget);
    await tester.tap(find.text('取消'));
  }
  await tester.pumpAndSettle();
  expect(find.byType(BottomSheet), findsNothing);
}

void main() {
  testWidgets('删除已展开领域后后续领域保持收起', (tester) async {
    final settings = TagSettings.fromTagConfig(DefaultTagConfig.value);
    final first = settings.domainSettings[0];
    final next = settings.domainSettings[1];
    await _mount(tester, settings);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('展开').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(first.displayName));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '永久删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final nextCard = find.byKey(ValueKey('tag_domain_${next.key}'));
    expect(nextCard, findsOneWidget);
    for (final topic in next.topics) {
      expect(
        find.descendant(of: nextCard, matching: find.text(topic.displayName)),
        findsNothing,
      );
    }
    await tester.pumpAndSettle();
  });
  testWidgets('领域展开中下方卡片连续下移，收起开始子项不可点击', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final settings = TagSettings.fromTagConfig(DefaultTagConfig.value);
    await _mount(tester, settings);
    await tester.pumpAndSettle();
    final next = find.text(settings.domainSettings[1].displayName).first;
    final before = tester.getTopLeft(next).dy;
    await tester.tap(find.byTooltip('展开').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final during = tester.getTopLeft(next).dy;
    await tester.pump(const Duration(milliseconds: 250));
    final after = tester.getTopLeft(next).dy;
    expect(during, greaterThan(before));
    expect(during, lessThan(after));
    await tester.tap(find.byTooltip('收起').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(next).dy, inExclusiveRange(before, after));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(next).dy, before);
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  setUpAll(() async {
    const path = String.fromEnvironment('TAG_PREVIEW_FONT');
    if (path.isEmpty) return;
    final loader = FontLoader('TagPreview');
    loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });
  for (final dark in [false, true]) {
    for (final accessible in [false, true]) {
      testWidgets('标签操作展示 dark=$dark accessible=$accessible', (tester) async {
        final settings = TagSettings.fromTagConfig(DefaultTagConfig.value);
        final name = settings.domainSettings.first.displayName;
        final before = jsonEncode(settings.toJson());
        await _mount(tester, settings, dark: dark, accessible: accessible);
        expect(find.text('#$name'), findsNothing);
        await _openEntry(tester, name);
        _expectMenu(tester, dark: dark, accessible: accessible);
        if (!accessible) await _savePreview(tester, dark);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(jsonEncode(settings.toJson()), before);
        expect(
          await const FlutterSecureStorage().read(key: 'tag_settings'),
          isNull,
        );
        await _openEntry(tester, name);
        expect(find.text('停用'), findsOneWidget);
      });
    }
  }
  for (final kind in ['领域', '主题', '方法']) {
    for (final modified in [false, true]) {
      testWidgets('$kind 名称与确认取消 modified=$modified', (tester) async {
        final settings = TagSettings.fromTagConfig(DefaultTagConfig.value);
        final name = _configureEntry(settings, kind, modified);
        final before = jsonEncode(settings.toJson());
        await _mount(tester, settings);
        if (kind == '主题') {
          await tester.tap(find.byTooltip('展开').first);
          await tester.pumpAndSettle();
        } else if (kind == '方法') {
          await tester.tap(find.text('方法'));
          await tester.pumpAndSettle();
        }
        expect(find.text(name), findsOneWidget);
        expect(find.text('#$name'), findsNothing);
        await _openEntry(tester, name);
        _expectMenu(tester, renamed: modified, enabled: !modified);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        await _cancelAction(tester, name, '编辑');
        await _cancelAction(tester, name, '永久删除');
        expect(jsonEncode(settings.toJson()), before);
        expect(
          await const FlutterSecureStorage().read(key: 'tag_settings'),
          isNull,
        );
      });
    }
  }
}
