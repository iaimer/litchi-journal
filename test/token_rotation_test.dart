import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/screens/remote_api_page.dart';

void main() {
  testWidgets('测试只验证当前表单，修改后保存重新验证', (tester) async {
    final old = 'o' * 32;
    final initial = ApiConfig(baseUrl: 'https://old.example', token: old);
    FlutterSecureStorage.setMockInitialValues({
      'api_token': old,
      'api_base_url': initial.baseUrl,
    });
    final tested = <ApiConfig>[];
    ApiConfig? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteApiPage(
          apiConfig: initial,
          onConfigChanged: (value) => changed = value,
          createApiClient: (config) {
            tested.add(config);
            return ApiClient(
              config,
              httpClient: MockClient((_) async => http.Response('{}', 200)),
            );
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('server_url')),
      'https://tested.example',
    );
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();
    expect(changed, isNull);
    expect((await ApiConfig.load())!.baseUrl, initial.baseUrl);
    expect(tested.length, 1);
    expect(tested.single.token == old, isTrue);
    await tester.enterText(
      find.byKey(const Key('server_url')),
      'https://changed.example',
    );
    await tester.pump();
    expect(find.text('连接成功'), findsNothing);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(tested.length, 2);
    expect(changed!.baseUrl, 'https://changed.example');
    expect(changed!.token == old, isTrue);
  });

  testWidgets('在途旧结果不回填，测试按钮防止重复请求且不保存', (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    ApiConfig? changed;
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteApiPage(
          apiConfig: ApiConfig(baseUrl: 'https://old.example', token: 'o' * 32),
          onConfigChanged: (value) => changed = value,
          createApiClient: (config) => ApiClient(
            config,
            httpClient: MockClient((_) {
              requests++;
              return pending.future;
            }),
          ),
        ),
      ),
    );
    await tester.tap(find.text('测试连接'));
    await tester.pump();
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    tester
            .widget<TextField>(find.byKey(const Key('server_url')))
            .controller!
            .text =
        'https://changed.example';
    pending.complete(http.Response('{}', 200));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('连接成功'), findsNothing);
    expect(changed, isNull);
    expect(await ApiConfig.load(), isNull);
  });

  testWidgets('无效服务器地址与空凭据不会发起验证', (tester) async {
    var created = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteApiPage(
          apiConfig: ApiConfig(baseUrl: 'https://old.example', token: ''),
          createApiClient: (config) {
            created++;
            return ApiClient(config);
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('server_url')),
      'file:///private/tmp',
    );
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();
    expect(created, 0);
    await tester.enterText(
      find.byKey(const Key('server_url')),
      'https://valid.example',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(created, 0);
  });

  testWidgets('更换Token先验证再保存，失败不改配置，成功后修改地址复用新Token', (tester) async {
    final old = 'o' * 32;
    final fresh = 'n' * 32;
    FlutterSecureStorage.setMockInitialValues({
      'api_token': old,
      'api_base_url': 'https://old.example',
      'unrelated': '保留',
    });
    var status = 401;
    ApiConfig? changed;
    final tested = <ApiConfig>[];
    final current = ApiClient(
      ApiConfig(baseUrl: 'https://old.example', token: old),
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteApiPage(
            apiConfig: ApiConfig(baseUrl: current.baseUrl, token: ''),
            apiClient: current,
            onConfigChanged: (config) => changed = config,
            createApiClient: (config) {
              tested.add(config);
              return ApiClient(
                config,
                httpClient: MockClient(
                  (_) async => http.Response('{}', status),
                ),
              );
            },
          ),
        ),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('server_token')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('server_token')))
            .obscureText,
        isTrue,
      );
      await tester.enterText(find.byKey(const Key('server_token')), 'x' * 31);
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();
      expect(tested, isEmpty);
      await tester.enterText(find.byKey(const Key('server_token')), fresh);
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();
      expect(changed, isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'api_token') == old,
        isTrue,
      );
      status = 200;
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();
      expect(changed?.token == fresh, isTrue);
      expect(await const FlutterSecureStorage().read(key: 'unrelated'), '保留');
      await tester.enterText(
        find.byKey(const Key('server_url')),
        'https://new.example',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();
      expect(tested.last.token == fresh, isTrue);
      expect(changed?.baseUrl, 'https://new.example');
    } finally {
      current.dispose();
    }
  });
}
