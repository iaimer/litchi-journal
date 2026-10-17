part of '../widget_test.dart';

void registerSettingsTests() {
  group('PolishPromptPage', () {
    testWidgets('uses 今日回顾 copy and default journal reviewer prompt', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});

      await tester.pumpWidget(const MaterialApp(home: PolishPromptPage()));
      await tester.pumpAndSettle();

      expect(find.text('今日回顾提示词'), findsOneWidget);
      expect(find.text('用于生成「今日回顾」模块的每日总结和建议。'), findsOneWidget);
      expect(find.text('恢复默认今日回顾提示词'), findsOneWidget);
      expect(find.text('人生教练提示词'), findsNothing);
      expect(find.text('恢复默认人生教练提示词'), findsNothing);

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[1].controller?.text, contains('日记回顾者'));
      expect(fields[1].controller?.text, isNot(contains('人生教练')));
    });
  });

  group('SettingsScreen', () {
    Widget buildScreen({AIConfigRepository? aiRepo}) {
      return MaterialApp(
        home: SettingsScreen(
          apiConfig: ApiConfig(
            baseUrl: 'https://obsidian.femkits.org',
            token: 'secret-token',
          ),
        ),
      );
    }

    testWidgets('shows AI section and connection info', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.text('AI 服务配置'), findsOneWidget);
      expect(find.text('启用 AI 润色'), findsOneWidget);
      expect(find.text('快速选择预设'), findsOneWidget);
      expect(find.text('保存 AI 配置'), findsOneWidget);
    });

    testWidgets('does not show plain text Token', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.text('secret-token'), findsNothing);
    });

    testWidgets('toggling AI switch disables AI fields', (tester) async {
      await tester.pumpWidget(buildScreen());

      // Initially disabled: skip server address + Token (which is _ReadOnlyField, not TextField)
      // Then AI fields: name (0), baseUrl (1), apiKey (2), model (3), prompt (4)
      final textFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();

      expect(textFields[0].enabled, isFalse); // name
      expect(textFields[1].enabled, isFalse); // baseUrl
      expect(textFields[2].enabled, isFalse); // apiKey
      expect(textFields[3].enabled, isFalse); // model

      await tester.tap(find.byKey(const ValueKey('ai_enabled_toggle')));
      await tester.pump();

      final enabledFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();

      expect(enabledFields[0].enabled, isTrue);
      expect(enabledFields[1].enabled, isTrue);
      expect(enabledFields[2].enabled, isTrue);
      expect(enabledFields[3].enabled, isTrue);
    });

    testWidgets('disabled fields preserve content', (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.byKey(const ValueKey('ai_enabled_toggle')));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Base URL'),
        'https://api.test.com',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Model'), 'gpt-4o');
      await tester.pump();

      // Disable and re-enable
      await tester.tap(find.byKey(const ValueKey('ai_enabled_toggle')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ai_enabled_toggle')));
      await tester.pump();

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Base URL'))
            .controller
            ?.text,
        'https://api.test.com',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Model'))
            .controller
            ?.text,
        'gpt-4o',
      );
    });

    testWidgets('API Key field uses obscureText', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.tap(find.byKey(const ValueKey('ai_enabled_toggle')));
      await tester.pump();

      final apiKeyField = find.widgetWithText(TextField, 'API Key');
      expect(tester.widget<TextField>(apiKeyField).obscureText, isTrue);

      await tester.tap(_floraIcon(FloraIcons.eye).last);
      await tester.pump();
      expect(tester.widget<TextField>(apiKeyField).obscureText, isFalse);
    });

    testWidgets('preset chip fills name, baseUrl, and model', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.tap(find.byKey(const ValueKey('ai_enabled_toggle')));
      await tester.pump();

      await tester.tap(find.text('DeepSeek'));
      await tester.pump();

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '服务商名称'))
            .controller
            ?.text,
        'DeepSeek',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Base URL'))
            .controller
            ?.text,
        'https://api.deepseek.com',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Model'))
            .controller
            ?.text,
        'deepseek-v4-flash',
      );
    });

    testWidgets('test connection button verifies current AI fields', (
      tester,
    ) async {
      final service = PolisherService(
        httpClient: _CapturingClient(
          responseBody: '{"choices":[{"message":{"content":"OK"}}]}',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            apiConfig: ApiConfig(
              baseUrl: 'https://obsidian.femkits.org',
              token: 'secret-token',
            ),
            polisherService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('ai_test_connection')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('ai_enabled_toggle')));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Base URL'),
        'https://opencode.ai/zen/go',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'API Key'),
        'go-test-key',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Model'),
        'deepseek-v4-flash',
      );

      await tester.tap(find.byKey(const ValueKey('ai_test_connection')));
      await tester.pumpAndSettle();

      expect(find.text('连接成功'), findsOneWidget);
    });

    testWidgets('Server address and Token not editable', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.text('https://obsidian.femkits.org'), findsNothing);
      expect(find.text('secret-token'), findsNothing);
    });

    testWidgets('shows polish and coach prompt fields with labels', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.tap(find.byKey(const ValueKey('ai_enabled_toggle')));
      await tester.pump();

      expect(find.text('润色提示词'), findsNothing);
      expect(find.text('人生教练提示词'), findsNothing);
      expect(find.text('恢复默认润色提示词'), findsNothing);
      expect(find.text('恢复默认人生教练提示词'), findsNothing);
    });
  });
}
