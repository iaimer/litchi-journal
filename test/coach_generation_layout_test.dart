import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:litchi_journal_flutter/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/models/ai_config.dart';
import 'package:litchi_journal_flutter/screens/home_screen.dart';
import 'package:litchi_journal_flutter/services/ai_config_repository.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/polisher_service.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';

class DelayedCoach extends PolisherService {
  final response = Completer<String>();
  int calls = 0;
  String? receivedContext;
  @override
  Future<String> generateCoach({
    required String diaryContext,
    required AIConfig config,
  }) {
    calls++;
    receivedContext = diaryContext;
    return response.future;
  }
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
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('胶囊与固定加号适配 width=$width scale=$scale dark=$dark', (
          tester,
        ) async {
          FlutterSecureStorage.setMockInitialValues({});
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final client = ApiClient(
            ApiConfig(baseUrl: 'http://example.invalid', token: 'test'),
            httpClient: MockClient(
              (request) async => http.Response(
                jsonEncode({
                  'date': '2026-10-30',
                  'raw': '## 随手记\n- **12:00** 今天散步\n',
                  'sections': {},
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
            ),
          );
          addTearDown(client.dispose);
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
                        textTheme: theme.textTheme.apply(
                          fontFamily: 'LayoutPreview',
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: theme.textButtonTheme.style?.copyWith(
                            textStyle: const WidgetStatePropertyAll(
                              TextStyle(
                                fontFamily: 'LayoutPreview',
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: app.MainScreen(
                  apiClient: client,
                  onApiConfigChanged: (_) {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final fab = tester.getRect(find.byKey(const Key('quick_record_fab')));
          final capsule = tester.getRect(
            find.byKey(const ValueKey('generate_coach_capsule')),
          );
          expect(fab.width, closeTo(56, 0.01));
          expect(fab.height, closeTo(56, 0.01));
          expect(capsule.right, lessThanOrEqualTo(fab.left - 16));
          final personal = tester.getRect(
            find.byKey(const ValueKey('diary_group_personal')),
          );
          expect(capsule.top, greaterThanOrEqualTo(personal.bottom));
          expect(capsule.top - personal.bottom, lessThanOrEqualTo(16));
          expect(
            find.ancestor(
              of: find.byKey(const ValueKey('generate_coach_capsule')),
              matching: find.byType(Scrollable),
            ),
            findsOneWidget,
          );
          expect(capsule.height, greaterThanOrEqualTo(48));
          final label = tester.widget<Text>(find.text('生成今日回顾'));
          expect(label.maxLines, 1);
          expect(label.softWrap, isFalse);
          if ((width == 390 && scale == 1) || (width == 320 && scale == 2)) {
            await _savePreview(
              tester,
              'home-${dark ? 'dark' : 'light'}-${width.toInt()}-${scale.toInt()}',
            );
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('首次生成胶囊紧随生活记录并随正文滚动，加号不动', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final paragraphs = List.generate(
      16,
      (i) => '一段用于滚动验证的旧日记正文$i。',
    ).join('\n\n');
    final client = ApiClient(
      ApiConfig(baseUrl: 'http://example.invalid', token: 'test'),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'date': '2026-10-30',
            'raw': '## 随手记\n- **12:00** 生活记录\n## 旧章节\n$paragraphs',
            'sections': {},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(apiClient: client),
      ),
    );
    await tester.pumpAndSettle();
    final capsule = find.byKey(const ValueKey('generate_coach_capsule'));
    final fab = find.byKey(const Key('quick_record_fab'));
    final original = tester.getRect(capsule);
    final fixedFab = tester.getRect(fab);
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(tester.getRect(capsule).top, lessThan(original.top - 100));
    expect(tester.getRect(fab), fixedFab);
  });
  for (final nextDay in [false, true]) {
    testWidgets('生成期间切回等待最新读取，跨日丢弃旧生成 nextDay=$nextDay', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await AIConfigRepository().saveAIConfig(
        const AIConfig(
          enabled: true,
          baseUrl: 'https://example.invalid/v1',
          apiKey: 'test',
          model: 'test',
        ),
      );
      var now = DateTime(2026, 10, 30);
      var active = true;
      var reads = 0;
      var saves = 0;
      final firstRead = Completer<http.Response>();
      final lastRead = Completer<http.Response>();
      final raw = '## 随手记\n- **12:00** 散步\n';
      http.Response diary(String text) => http.Response(
        jsonEncode({
          'date': ApiClient.formatDate(now),
          'raw': text,
          'sections': {},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      final client = ApiClient(
        ApiConfig(baseUrl: 'http://example.invalid', token: 'test'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/lizhi-says')) {
            saves++;
            return http.Response('{}', 200);
          }
          if (request.url.path.endsWith('/tomorrow')) {
            return http.Response('{}', 200);
          }
          if (request.url.path.contains('/diary/')) {
            reads++;
            if (reads == 1) return diary(raw);
            return reads == 2 ? firstRead.future : lastRead.future;
          }
          return http.Response('{}', 404);
        }),
      );
      final coach = DelayedCoach();
      addTearDown(client.dispose);
      addTearDown(coach.dispose);
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return HomeScreen(
                apiClient: client,
                polisherService: coach,
                now: () => now,
                active: active,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('生成今日回顾'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      if (!nextDay) {
        coach.response.complete('📌 模式识别\n已生成回顾');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
      }
      update(() => active = false);
      await tester.pump();
      if (nextDay) now = now.add(const Duration(days: 1));
      update(() => active = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      if (nextDay) {
        coach.response.complete('📌 模式识别\n旧日回顾');
        await tester.pump();
        firstRead.complete(diary('## 随手记\n- **12:00** 新的一天\n'));
        await tester.pumpAndSettle();
        expect(saves, 0);
        expect(find.text('新的一天'), findsOneWidget);
        expect(find.text('旧日回顾'), findsNothing);
      } else {
        firstRead.complete(diary('$raw\n### 人生教练\n已生成回顾\n'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('正在生成今日回顾…'), findsOneWidget);
        lastRead.complete(diary('$raw\n### 人生教练\n已生成回顾\n'));
        await tester.pumpAndSettle();
        expect(find.text('已生成回顾'), findsOneWidget);
        expect(find.text('正在生成今日回顾…'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final mode in ['success', 'partial', 'refresh', 'auth', 'ai']) {
    final failTomorrow = mode == 'partial';
    testWidgets('生成立即展开且成功或部分失败均保持加号位置 mode=$mode', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await AIConfigRepository().saveAIConfig(
        const AIConfig(
          enabled: true,
          baseUrl: 'https://example.invalid/v1',
          apiKey: 'test',
          model: 'test',
        ),
      );
      var raw =
          '## 随手记\n- **12:00** 今天散步\n<!-- litchi-entry-id:11111111-1111-4111-8111-111111111111 -->\n';
      final client = ApiClient(
        ApiConfig(baseUrl: 'http://example.invalid', token: 'test'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/lizhi-says')) {
            raw += '\n### 人生教练\n散步让你放松\n';
            return http.Response('{}', 200);
          }
          if (request.url.path.endsWith('/tomorrow')) {
            return http.Response('{}', failTomorrow ? 500 : 200);
          }
          if (raw.contains('人生教练') &&
              request.method == 'GET' &&
              (mode == 'refresh' || mode == 'auth')) {
            return http.Response('{}', mode == 'auth' ? 401 : 500);
          }
          if (request.url.path.contains('/diary/')) {
            return http.Response(
              jsonEncode({'date': '2026-10-30', 'raw': raw, 'sections': {}}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      final coach = DelayedCoach();
      addTearDown(client.dispose);
      addTearDown(coach.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(apiClient: client, polisherService: coach),
        ),
      );
      await tester.pumpAndSettle();
      final fab = find.byKey(const Key('quick_record_fab'));
      final before = tester.getRect(fab);
      await tester.tap(find.text('生成今日回顾'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('正在生成今日回顾…'), findsOneWidget);
      expect(tester.getRect(fab), before);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('generate_coach_capsule')),
            )
            .onPressed,
        isNull,
      );
      await tester.pump();
      expect(coach.calls, 1);
      expect(coach.receivedContext, contains('今天散步'));
      expect(coach.receivedContext, isNot(contains('<!--')));
      if (mode == 'ai') {
        coach.response.completeError(Exception('test failure'));
      } else {
        coach.response.complete(
          '📌 模式识别\n散步让你放松\n🎯 行动建议\n明天继续散步\n💬 暖心鼓励\n继续记录',
        );
      }
      await tester.pumpAndSettle();
      if (mode == 'refresh' || mode == 'auth' || mode == 'ai') {
        expect(
          find.textContaining(
            mode == 'auth'
                ? '认证失败'
                : mode == 'refresh'
                ? '已保存，但刷新失败'
                : '暂时无法生成',
          ),
          findsWidgets,
        );
        expect(tester.getRect(fab), before);
        return;
      }
      expect(find.text('散步让你放松'), findsOneWidget);
      expect(find.text('正在生成今日回顾…'), findsNothing);
      expect(find.text('生成今日回顾'), findsNothing);
      expect(tester.getRect(fab), before);
      if (failTomorrow) expect(find.textContaining('明日寄语保存失败'), findsWidgets);
    });
  }
}
