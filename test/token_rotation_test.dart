import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/screens/remote_api_page.dart';

void main() {
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
      await tester.tap(find.text('更换 Token'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'x' * 31);
      await tester.tap(find.widgetWithText(FilledButton, '验证并保存'));
      await tester.pumpAndSettle();
      expect(tested, isEmpty);
      await tester.enterText(find.byType(TextField), fresh);
      await tester.tap(find.widgetWithText(FilledButton, '验证并保存'));
      await tester.pumpAndSettle();
      expect(changed, isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'api_token') == old,
        isTrue,
      );
      status = 200;
      await tester.tap(find.widgetWithText(FilledButton, '验证并保存'));
      await tester.pumpAndSettle();
      expect(changed?.token == fresh, isTrue);
      expect(await const FlutterSecureStorage().read(key: 'unrelated'), '保留');
      await tester.tap(find.text('修改服务器地址'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'https://new.example');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(tested.last.token == fresh, isTrue);
      expect(changed?.baseUrl, 'https://new.example');
    } finally {
      current.dispose();
    }
  });
}
