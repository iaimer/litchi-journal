import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/main.dart' as app;
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';

const _fabKey = Key('quick_record_fab');

ApiClient _pendingDiaryClient(Completer<http.Response> diary) => ApiClient(
  ApiConfig(baseUrl: 'http://example.invalid', token: 'fab-test'),
  httpClient: MockClient((request) async {
    if (request.url.path.startsWith('/api/v1/diary/')) return diary.future;
    return http.Response('{}', 404);
  }),
);

double _paintedOpacity(WidgetTester tester) {
  RenderObject? current = tester.renderObject(find.byKey(_fabKey));
  var opacity = 1.0;
  while (current != null) {
    if (current is RenderOpacity) opacity *= current.opacity;
    if (current is RenderAnimatedOpacity) opacity *= current.opacity.value;
    current = current.parent;
  }
  return opacity;
}

void main() {
  testWidgets('冷启动等待日记期间加号始终不透明，验证完成后开放记录', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final diary = Completer<http.Response>();
    final client = _pendingDiaryClient(diary);
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: app.MainScreen(apiClient: client, onApiConfigChanged: (_) {}),
      ),
    );
    for (final elapsed in [Duration.zero, const Duration(milliseconds: 300)]) {
      await tester.pump(elapsed);
      expect(_paintedOpacity(tester), 1);
    }
    await tester.tap(find.byKey(_fabKey), warnIfMissed: false);
    await tester.pump();
    expect(find.byKey(const Key('quick_record_reflection')), findsNothing);
    diary.complete(
      http.Response(
        jsonEncode({
          'date': '2026-10-26',
          'raw': '### 💡 觉察与迭代\n',
          'sections': {},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpAndSettle();
    expect(_paintedOpacity(tester), 1);
    await tester.tap(find.byKey(_fabKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_record_reflection')), findsOneWidget);
  });
}
