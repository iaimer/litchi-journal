import 'dart:async';
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
import 'package:litchi_journal_flutter/models/ai_config.dart';
import 'package:litchi_journal_flutter/screens/home_screen.dart';
import 'package:litchi_journal_flutter/screens/quick_capture_screen.dart';
import 'package:litchi_journal_flutter/services/ai_config_repository.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/polisher_service.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_dock.dart';
import 'package:litchi_journal_flutter/widgets/quick_record_backdrop.dart';

const _fab = Key('quick_record_fab');
const _capsule = ValueKey('generate_coach_capsule');
const _viewport = Key('home_reading_viewport');

class _DelayedCoach extends PolisherService {
  final response = Completer<String>();
  int calls = 0;

  @override
  Future<String> generateCoach({
    required String diaryContext,
    required AIConfig config,
  }) {
    calls++;
    return response.future;
  }
}

String _longRaw({bool coach = false}) {
  final notes = List.generate(
    16,
    (i) => '- **12:${i.toString().padLeft(2, '0')}** 用于验证滚动留白的长记录$i。',
  ).join('\n');
  return '## 随手记\n$notes\n${coach ? '\n### 人生教练\n散步让你放松\n' : ''}';
}

final _mutations = <String>[];

ApiClient _client(String Function() raw, {bool coachOnSave = false}) {
  var coachSaved = false;
  return ApiClient(
    ApiConfig(baseUrl: 'http://example.invalid', token: 'action-test'),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      if (request.method != 'GET') _mutations.add('${request.method} $path');
      if (path.endsWith('/lizhi-says')) {
        if (coachOnSave) coachSaved = true;
        return http.Response('{}', 200);
      }
      if (path.endsWith('/tomorrow')) return http.Response('{}', 200);
      if (path == '/api/v1/stats/habit') return http.Response('[]', 200);
      if (path == '/api/v1/history/gallery') {
        return http.Response('{"months":[],"nextCursor":null}', 200);
      }
      if (path.startsWith('/api/v1/diary/')) {
        final body = coachOnSave && coachSaved
            ? '${raw()}### 人生教练\n散步让你放松\n'
            : raw();
        return http.Response(
          jsonEncode({
            'date': ApiClient.formatDate(DateTime.now()),
            'raw': body,
            'sections': {},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 404);
    }),
  );
}

Future<_DelayedCoach> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
  String? raw,
  AIConfig? aiConfig,
  bool coachOnSave = false,
  bool homeOnly = false,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  if (aiConfig != null) {
    await AIConfigRepository().saveAIConfig(aiConfig);
  }
  _mutations.clear();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final coach = _DelayedCoach();
  final client = _client(() => raw ?? _longRaw(), coachOnSave: coachOnSave);
  addTearDown(client.dispose);
  addTearDown(coach.dispose);
  final theme = dark ? AppTheme.dark : AppTheme.light;
  const font = String.fromEnvironment('LITCHI_PREVIEW_FONT');
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('layout_preview'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: font.isEmpty
            ? theme
            : theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'LayoutPreview'),
                textButtonTheme: TextButtonThemeData(
                  style: theme.textButtonTheme.style?.copyWith(
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontFamily: 'LayoutPreview', fontSize: 16),
                    ),
                  ),
                ),
              ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: size,
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: homeOnly
            ? HomeScreen(apiClient: client, polisherService: coach)
            : app.MainScreen(apiClient: client, onApiConfigChanged: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return coach;
}

Finder _readingList() =>
    find.descendant(of: find.byKey(_viewport), matching: find.byType(ListView));

ScrollController _controller(WidgetTester tester) =>
    tester.widget<ListView>(_readingList()).controller!;

Future<void> _scrollToEnd(WidgetTester tester) async {
  final controller = _controller(tester);
  controller.jumpTo(controller.position.maxScrollExtent);
  await tester.pumpAndSettle();
}

Future<void> _savePreview(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('LITCHI_PREVIEW_DIR');
  if (output.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('layout_preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
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
    const font = String.fromEnvironment('LITCHI_PREVIEW_FONT');
    if (font.isEmpty) return;
    await (FontLoader(
      'LayoutPreview',
    )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
  });

  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0]) {
      testWidgets('提示卡与加号同为48dp，视口止于操作区上方16dp dark=$dark width=$width', (
        tester,
      ) async {
        await _mount(tester, size: Size(width, 844), dark: dark);
        final dock = tester.getRect(find.byType(FloraDock));
        final fab = tester.getRect(find.byKey(_fab));
        final capsule = tester.getRect(find.byKey(_capsule));
        expect(fab.size, const Size(48, 48));
        expect(fab.right, closeTo(width - 16, .01));
        expect(fab.bottom, closeTo(dock.top - 12, .01));
        expect(capsule.height, 48);
        expect(capsule.left, 16);
        expect(capsule.top, closeTo(fab.top, .01));
        expect(fab.left - capsule.right, closeTo(12, .01));
        final viewport = tester.getRect(find.byKey(_viewport));
        expect(viewport.bottom, closeTo(capsule.top - 16, .01));
        expect(dock.top - viewport.bottom, closeTo(76, .01));
        for (final label in ['回顾今天', '让小荔枝帮你整理这一天的点滴']) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, 1);
          expect(text.softWrap, isFalse);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final dark in [false, true]) {
    testWidgets('菜单展开时不保留固定占位，正文视口到导航上沿 dark=$dark', (tester) async {
      await _mount(tester, dark: dark);
      final dock = tester.getRect(find.byType(FloraDock));
      final capsule = tester.getRect(find.byKey(_capsule));
      final shownViewport = tester.getRect(find.byKey(_viewport));
      final shownPadding = tester.widget<ListView>(_readingList()).padding;
      expect((shownPadding as EdgeInsets).bottom, 16);
      await tester.tap(find.byKey(_fab));
      await tester.pumpAndSettle();
      expect(find.byKey(_capsule), findsNothing);
      final viewport = tester.getRect(find.byKey(_viewport));
      expect(viewport.bottom, closeTo(dock.top, .01));
      expect(
        (tester.widget<ListView>(_readingList()).padding as EdgeInsets).bottom,
        92,
      );
      final filter = tester.getRect(
        find.descendant(
          of: find.byType(QuickRecordBackdrop),
          matching: find.byType(BackdropFilter),
        ),
      );
      expect(filter.top, lessThan(capsule.top));
      expect(filter.bottom, closeTo(dock.top, .01));
      await _savePreview(
        tester,
        'home-actions-menu-${dark ? 'dark' : 'light'}',
      );
      // 从正文开始的按压会关闭菜单，但不能穿透滚动或打开记录页。
      final controller = _controller(tester);
      final offset = controller.offset;
      await tester.drag(
        _readingList(),
        const Offset(0, -240),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(controller.offset, offset);
      expect(find.byType(QuickCaptureScreen), findsNothing);
      expect(_mutations, isEmpty);
      // 再次展开后点击正文习惯行，只关闭菜单，不触发保存。
      await tester.tap(find.byKey(_fab));
      await tester.pumpAndSettle();
      await tester.tap(find.text('补充剂'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_mutations, isEmpty);
      expect(find.byType(QuickCaptureScreen), findsNothing);
      await tester.tap(find.byKey(_fab));
      await tester.pumpAndSettle();
      await tester.tapAt(Offset(20, filter.top + 40));
      await tester.pumpAndSettle();
      expect(find.byType(QuickCaptureScreen), findsNothing);
      expect(
        find.descendant(
          of: find.byType(QuickRecordBackdrop),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      expect(
        tester.getRect(find.byKey(_viewport)).bottom,
        closeTo(shownViewport.bottom, .01),
      );
      expect(tester.getRect(find.byKey(_capsule)).top, capsule.top);
      expect(
        (tester.widget<ListView>(_readingList()).padding as EdgeInsets).bottom,
        16,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('没有有效记录时按隐藏状态处理，不保留固定占位', (tester) async {
    final decoded =
        jsonDecode(
              File('test/fixtures/diary_templates.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final template = (decoded['current'] as List<dynamic>).cast<String>().join(
      '\n',
    );
    await _mount(tester, raw: template);
    expect(find.byKey(_capsule), findsNothing);
    final dock = tester.getRect(find.byType(FloraDock));
    expect(
      tester.getRect(find.byKey(_viewport)).bottom,
      closeTo(dock.top, .01),
    );
    expect(
      (tester.widget<ListView>(_readingList()).padding as EdgeInsets).bottom,
      92,
    );
    expect(tester.getRect(find.byKey(_fab)).size, const Size(48, 48));
    expect(tester.takeException(), isNull);
  });

  for (final (width, scale, dark) in [
    (320.0, 2.0, false),
    (390.0, 1.0, false),
    (390.0, 1.0, true),
  ]) {
    testWidgets('已生成回顾时隐藏占位，末条完整滚到加号上方 width=$width scale=$scale', (
      tester,
    ) async {
      await _mount(
        tester,
        size: Size(width, 844),
        scale: scale,
        dark: dark,
        raw: _longRaw(coach: true),
      );
      expect(find.byKey(_capsule), findsNothing);
      final dock = tester.getRect(find.byType(FloraDock));
      final viewport = tester.getRect(find.byKey(_viewport));
      expect(viewport.bottom, closeTo(dock.top, .01));
      final fab = tester.getRect(find.byKey(_fab));
      expect(fab.size, const Size(48, 48));
      await _scrollToEnd(tester);
      final last = tester.getRect(find.textContaining('长记录15'));
      expect(last.bottom, lessThanOrEqualTo(viewport.bottom + .01));
      expect(last.bottom, lessThanOrEqualTo(fab.top));
      expect(last.top, greaterThanOrEqualTo(viewport.top));
      await _savePreview(
        tester,
        'home-actions-generated-${dark ? 'dark' : 'light'}-${width.toInt()}',
      );
      await tester.tap(find.byKey(_fab));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 160));
      await tester.pumpAndSettle();
      expect(find.byKey(_capsule), findsNothing);
      expect(
        tester.getRect(find.byKey(_viewport)).bottom,
        closeTo(dock.top, .01),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('滚动到底开关菜单与连续点击保持位置稳定', (tester) async {
    await _mount(tester);
    await _scrollToEnd(tester);
    final controller = _controller(tester);
    final bottom = controller.offset;
    expect(bottom, greaterThan(0));
    await tester.tap(find.byKey(_fab));
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump(const Duration(milliseconds: 32));
    expect(controller.offset, closeTo(bottom, .01));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(bottom, .01));
    expect(find.byKey(_capsule), findsNothing);
    await tester.tapAt(const Offset(20, 160));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(controller.offset, closeTo(bottom, .01));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(bottom, .01));
    expect(find.byKey(_capsule), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(_fab));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tapAt(const Offset(20, 160));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(bottom, .01));
    expect(find.byKey(_capsule), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('生成成功立即结束来源副本并切换到隐藏状态', (tester) async {
    final coach = await _mount(
      tester,
      raw: '## 随手记\n- **12:00** 今天散步\n',
      aiConfig: const AIConfig(
        enabled: true,
        baseUrl: 'https://example.invalid/v1',
        apiKey: 'fixture',
        model: 'fixture',
      ),
      coachOnSave: true,
      homeOnly: true,
    );
    final fab = tester.getRect(find.byKey(_fab));
    await tester.tap(find.text('回顾今天'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    final overlay = find.byKey(const Key('coach_origin_overlay'));
    expect(overlay, findsOneWidget);
    for (var i = 0; i < 10 && coach.calls == 0; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(coach.calls, 1);
    coach.response.complete('📌 模式识别\n散步让你放松\n🎯 行动建议\n明天继续散步\n💬 暖心鼓励\n继续记录');
    var landed = false;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 1));
      if (find.text('散步让你放松').evaluate().isNotEmpty) {
        landed = true;
        break;
      }
    }
    expect(landed, isTrue);
    // 视口尺寸已经变化，不能继续播放落到旧位置的副本。
    expect(overlay, findsNothing);
    expect(find.byKey(_capsule), findsNothing);
    expect(
      tester.getRect(find.byKey(_viewport)).bottom,
      closeTo(fab.bottom + 12, .01),
    );
    expect(
      (tester.widget<ListView>(_readingList()).padding as EdgeInsets).bottom,
      92,
    );
    await tester.pumpAndSettle();
    expect(overlay, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('生成失败保留提示卡与独立操作区', (tester) async {
    final coach = await _mount(
      tester,
      raw: '## 随手记\n- **12:00** 今天散步\n',
      aiConfig: const AIConfig(
        enabled: true,
        baseUrl: 'https://example.invalid/v1',
        apiKey: 'fixture',
        model: 'fixture',
      ),
      homeOnly: true,
    );
    final capsule = tester.getRect(find.byKey(_capsule));
    await tester.tap(find.text('回顾今天'));
    await tester.pump();
    for (var i = 0; i < 10 && coach.calls == 0; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(coach.calls, 1);
    coach.response.completeError(Exception('fixture'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach_origin_overlay')), findsNothing);
    expect(find.byKey(_capsule), findsOneWidget);
    expect(find.textContaining('暂时无法生成'), findsWidgets);
    expect(tester.getRect(find.byKey(_capsule)).top, capsule.top);
    expect(
      tester.getRect(find.byKey(_viewport)).bottom,
      closeTo(capsule.top - 16, .01),
    );
    expect(
      (tester.widget<ListView>(_readingList()).padding as EdgeInsets).bottom,
      16,
    );
    expect(tester.takeException(), isNull);
  });
}
