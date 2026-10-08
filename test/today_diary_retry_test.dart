import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/screens/home_screen.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';

http.Response diaryResponse(String date) => http.Response(
  jsonEncode({
    'date': date,
    'title': date,
    'raw': '## 随手记\n- **08:00** 重试后的正文',
    'sections': <String, dynamic>{},
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final failure in ['500', '401', '403', 'network', 'json', 'type']) {
    testWidgets('今天页区分 $failure 且重试恢复后不误创建', (tester) async {
      final today = ApiClient.formatDate(DateTime.now());
      var requests = 0;
      var creates = 0;
      final client = ApiClient(
        ApiConfig(baseUrl: 'http://retry.test', token: 'fixture-credential'),
        httpClient: MockClient((request) async {
          if (request.method == 'POST') creates++;
          if (request.url.path != '/api/v1/diary/$today') {
            return http.Response('{}', 404);
          }
          requests++;
          if (requests > 1) return diaryResponse(today);
          if (failure == 'network') throw const SocketException('offline');
          if (failure == 'json') return http.Response('not-json', 200);
          if (failure == 'type') {
            return http.Response('{"sections":{"notes":1}}', 200);
          }
          return http.Response(
            '{"error":"sensitive-fixture"}',
            int.parse(failure),
          );
        }),
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(MaterialApp(home: HomeScreen(apiClient: client)));
      await tester.pumpAndSettle();
      final message = switch (failure) {
        '500' => '服务器错误（500），请稍后重试',
        '401' || '403' => '认证失败，请检查连接设置后重试',
        'network' => '无法连接服务器，此日记尚未缓存，连接后请重试',
        _ => '服务器返回的日记数据无法解析，请重试或检查服务器版本',
      };
      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('sensitive-fixture'), findsNothing);
      expect(creates, 0);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(creates, 0);
      expect(find.textContaining('重试后的正文'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
    });
  }

  testWidgets('明确404后创建今天并重新读取，历史预热不创建', (tester) async {
    final today = ApiClient.formatDate(DateTime.now());
    final calls = <String>[];
    var created = false;
    final client = ApiClient(
      ApiConfig(baseUrl: 'http://retry.test', token: 'fixture-credential'),
      httpClient: MockClient((request) async {
        if (request.url.path.startsWith('/api/v1/diary/')) {
          calls.add('${request.method} ${request.url.path}');
        }
        if (request.url.path == '/api/v1/diary/create') {
          expect(jsonDecode(request.body)['date'], today);
          created = true;
          return http.Response('{}', 200);
        }
        if (request.url.path == '/api/v1/diary/$today' && created) {
          return diaryResponse(today);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(apiClient: client)));
    await tester.pumpAndSettle();
    expect(calls.take(3), [
      'GET /api/v1/diary/$today',
      'POST /api/v1/diary/create',
      'GET /api/v1/diary/$today',
    ]);
    expect(calls.where((call) => call.startsWith('POST')), hasLength(1));
    expect(find.textContaining('重试后的正文'), findsOneWidget);
  });

  for (final status in [500, 401, 403]) {
    testWidgets('明确404但创建返回$status时显示真实原因并可重试', (tester) async {
      var creates = 0;
      final client = ApiClient(
        ApiConfig(baseUrl: 'http://retry.test', token: 'fixture-credential'),
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/diary/create') {
            creates++;
            return http.Response('{}', status);
          }
          return http.Response('{}', 404);
        }),
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(MaterialApp(home: HomeScreen(apiClient: client)));
      await tester.pumpAndSettle();
      expect(
        find.text(status == 500 ? '服务器错误（500），请稍后重试' : '认证失败，请检查连接设置后重试'),
        findsOneWidget,
      );
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(creates, 2);
      expect(find.textContaining('此日记尚未缓存'), findsNothing);
    });
  }
}
