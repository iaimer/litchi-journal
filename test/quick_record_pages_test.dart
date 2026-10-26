import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/main.dart' as app;
import 'package:litchi_journal_flutter/screens/read_only_diary_screen.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_dock.dart';
import 'package:litchi_journal_flutter/widgets/quick_record_backdrop.dart';
import 'package:litchi_journal_flutter/widgets/quick_record_menu.dart';

const _writePreview = bool.fromEnvironment('WRITE_MENU_PREVIEW');
const _previewFont = String.fromEnvironment('MENU_PREVIEW_FONT');
const _previewKey = Key('menu_page_preview');

ApiClient _client({bool timedNote = true}) => ApiClient(
  ApiConfig(baseUrl: 'http://example.invalid', token: 'menu-test'),
  httpClient: MockClient((request) async {
    if (request.url.path.startsWith('/api/v1/diary/')) {
      return http.Response(
        jsonEncode({
          'date': request.url.path.split('/').last,
          'raw':
              '${timedNote ? '## ✍️ 随手记 & 灵感\n- **08:25** 记录今天的小事，让生活慢下来。 #生活\n\n' : ''}### 💡 觉察与迭代\n- 走了一会儿，心情放松了。\n\n## ✨ 每日小确幸\n- 回家的路上看到一束阳光。',
          'sections': {},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (request.url.path == '/api/v1/history/gallery') {
      return http.Response('{"months":[],"nextCursor":null}', 200);
    }
    if (request.url.path == '/api/v1/stats/habit') {
      return http.Response('[]', 200);
    }
    return http.Response('{}', 404);
  }),
);

Future<void> _mount(
  WidgetTester tester, {
  bool historical = false,
  bool dark = false,
  bool highContrast = false,
  double scale = 1,
  Size size = const Size(320, 700),
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // 3 倍字的菜单矩阵用无时间正文，隔离既有时间轴行的超大字溢出。
  final client = _client(timedNote: scale < 3);
  addTearDown(client.dispose);
  final baseTheme = dark ? AppTheme.dark : AppTheme.light;
  final theme = _writePreview
      ? baseTheme.copyWith(
          textTheme: baseTheme.textTheme.apply(fontFamily: 'MenuPreview'),
        )
      : baseTheme;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          padding: const EdgeInsets.only(top: 24, bottom: 24),
          highContrast: highContrast,
          textScaler: TextScaler.linear(scale),
        ),
        child: RepaintBoundary(key: _previewKey, child: child!),
      ),
      home: historical
          ? ReadOnlyDiaryScreen(date: DateTime(2026, 10, 20), apiClient: client)
          : app.MainScreen(apiClient: client, onApiConfigChanged: (_) {}),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _fab(bool historical) => find.byKey(
  Key(historical ? 'historical_quick_record_fab' : 'quick_record_fab'),
);
List<Finder> _entries(bool historical) => [
  for (final name in ['happiness', 'reflection', 'quick_note'])
    find.byKey(Key('${historical ? 'historical_' : ''}quick_record_$name')),
];

void main() {
  for (final historical in [false, true]) {
    for (final dark in [false, true]) {
      for (final highContrast in [false, true]) {
        for (final scale in [1.0, 1.3, 2.0, 3.0]) {
          testWidgets(
            '实际页面历史=$historical dark=$dark 对比=$highContrast 字体=$scale',
            (tester) async {
              await _mount(
                tester,
                historical: historical,
                dark: dark,
                highContrast: highContrast,
                scale: scale,
              );
              final anchor = tester.getRect(_fab(historical));
              await tester.tap(_fab(historical));
              await tester.pumpAndSettle();
              final rows = _entries(historical).map(tester.getRect).toList();
              for (final row in rows) {
                expect(row.left, greaterThanOrEqualTo(15.99));
                expect(row.right, lessThanOrEqualTo(304.01));
                expect(row.top, greaterThanOrEqualTo(24));
                expect(row.height, greaterThanOrEqualTo(55.99));
              }
              expect(rows[0].bottom, closeTo(rows[1].top, .01));
              expect(rows[1].bottom, closeTo(rows[2].top, .01));
              await tester.ensureVisible(_entries(historical).last);
              expect(
                tester.getRect(_entries(historical).last).bottom + 8,
                closeTo(anchor.bottom, .01),
              );
              if (!historical) {
                expect(
                  tester.getRect(_entries(historical).last).bottom,
                  lessThan(tester.getRect(find.byType(FloraDock)).top),
                );
              } else {
                expect(anchor.bottom, closeTo(660, .01));
              }
              await tester.tapAt(const Offset(20, 350));
              await tester.pump();
              expect(
                find.descendant(
                  of: find.byType(QuickRecordBackdrop),
                  matching: find.byType(BackdropFilter),
                ),
                findsNothing,
              );
              await tester.pumpAndSettle();
              expect(_entries(historical).first, findsNothing);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  testWidgets('历史菜单独立滚动，不占用正文的主滚动控制器', (tester) async {
    await _mount(
      tester,
      historical: true,
      scale: 3,
      size: const Size(320, 400),
    );
    final reading = PrimaryScrollController.of(tester.element(_fab(true)));
    expect(reading.positions, hasLength(1));
    final readingOffset = reading.offset;
    await tester.tap(_fab(true));
    await tester.pumpAndSettle();
    expect(reading.positions, hasLength(1));
    final menuScroll = find.descendant(
      of: find.byType(QuickRecordMenu),
      matching: find.byType(Scrollable),
    );
    await tester.drag(menuScroll, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(menuScroll).position.pixels,
      greaterThan(0),
    );
    expect(reading.offset, readingOffset);
  });

  testWidgets('历史详情展开时返回按钮一次操作返回上一页', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = _client();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReadOnlyDiaryScreen(
                  date: DateTime(2026, 10, 20),
                  apiClient: client,
                ),
              ),
            ),
            child: const Text('打开历史'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开历史'));
    await tester.pumpAndSettle();
    await tester.tap(_fab(true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadOnlyDiaryScreen), findsNothing);
    expect(find.text('打开历史'), findsOneWidget);
  });

  if (_writePreview) {
    setUpAll(() async {
      if (_previewFont.isEmpty) {
        throw StateError('请显式指定 MENU_PREVIEW_FONT 中文字体路径');
      }
      final font = FontLoader('MenuPreview');
      font.addFont(
        Future.value(
          ByteData.sublistView(await File(_previewFont).readAsBytes()),
        ),
      );
      await font.load();
    });
    for (final historical in [false, true]) {
      for (final dark in [false, true]) {
        for (final open in [false, true]) {
          testWidgets('导出菜单预览 history=$historical dark=$dark open=$open', (
            tester,
          ) async {
            await _mount(
              tester,
              historical: historical,
              dark: dark,
              size: const Size(390, 844),
            );
            if (open) {
              await tester.tap(_fab(historical));
              await tester.pumpAndSettle();
            }
            await tester.runAsync(
              () => _savePreview(
                tester,
                '${historical ? 'history' : 'today'}-${dark ? 'dark' : 'light'}-${open ? 'open' : 'closed'}',
              ),
            );
          });
        }
      }
    }
  }
}

Future<void> _savePreview(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  final frame = await boundary.toImage(pixelRatio: 2);
  try {
    final bytes = (await frame.toByteData(format: ui.ImageByteFormat.png))!;
    final dir = await Directory(
      'build/quick-record-menu-preview',
    ).create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(bytes.buffer.asUint8List());
  } finally {
    frame.dispose();
  }
}
