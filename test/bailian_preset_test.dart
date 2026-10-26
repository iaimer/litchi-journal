import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/models/ai_config.dart';
import 'package:litchi_journal_flutter/models/default_tag_config.dart';
import 'package:litchi_journal_flutter/screens/ai_settings_screen.dart';
import 'package:litchi_journal_flutter/services/ai_config_repository.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/polisher_service.dart';
import 'package:litchi_journal_flutter/widgets/entry_type.dart';

const _baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
const _config = AIConfig(
  enabled: true,
  name: '阿里云百炼',
  baseUrl: _baseUrl,
  apiKey: 'test-key',
  model: 'qwen3.7-flash',
);
const _oldConfig = AIConfig(
  enabled: true,
  name: '本地 Ollama',
  baseUrl: 'http://localhost:11434',
  apiKey: 'existing-test-key',
  model: 'qwen2.5:7b',
  polishPrompt: '保留润色提示词',
  coachPrompt: '保留回顾提示词',
);

Finder _field(String label) => find.widgetWithText(TextField, label);

String? _fieldValue(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller?.text;

Future<void> _openSettings(
  WidgetTester tester, {
  PolisherService? service,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AiSettingsScreen(
        apiConfig: ApiConfig(
          baseUrl: 'https://example.com',
          token: 'test-token',
        ),
        polisherService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('百炼替换 Ollama 预设，其他预设不变', () {
    expect(aiPresets.map((preset) => preset.name), [
      'OpenAI API',
      'DeepSeek',
      'Moonshot',
      '阿里云百炼',
    ]);
    expect(aiPresets.map((preset) => preset.baseUrl), [
      'https://api.openai.com',
      'https://api.deepseek.com',
      'https://api.moonshot.cn',
      _baseUrl,
    ]);
    expect(aiPresets.map((preset) => preset.model), [
      'gpt-4o-mini',
      'deepseek-v4-flash',
      'moonshot-v1-8k',
      'qwen3.7-flash',
    ]);
  });

  for (final suffix in ['', '/', '///']) {
    test('百炼连接测试正确拼接地址并关闭思考（尾缀 $suffix）', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), '$_baseUrl/chat/completions');
        expect(request.headers['Authorization'] == 'Bearer test-key', isTrue);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'qwen3.7-flash');
        expect(body['enable_thinking'], isFalse);
        expect(body['max_tokens'], 16);
        expect(body.containsKey('thinking'), isFalse);
        expect(request.body.contains(_config.apiKey), isFalse);
        return http.Response('{"choices":[{"message":{"content":"OK"}}]}', 200);
      });
      final service = PolisherService(httpClient: client);
      addTearDown(service.dispose);
      final result = await service.testConnection(
        config: AIConfig(
          enabled: true,
          baseUrl: '$_baseUrl$suffix',
          apiKey: _config.apiKey,
          model: _config.model,
        ),
      );
      expect(result.success, isTrue);
    });
  }

  test('普通润色与回顾共用百炼非思考规则', () async {
    final bodies = <Map<String, dynamic>>[];
    final service = PolisherService(
      httpClient: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '正文 #亲子 #亲子沟通'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.dispose);
    await service.polish(
      content: '陪孩子聊天',
      entryType: EntryType.quickNote,
      tagConfig: DefaultTagConfig.value,
      config: _config,
    );
    await service.generateCoach(diaryContext: '今天陪孩子聊天', config: _config);
    expect(bodies, hasLength(2));
    expect(bodies.map((body) => body['max_tokens']), [512, 800]);
    for (final body in bodies) {
      expect(body['enable_thinking'], isFalse);
      expect(body['model'], 'qwen3.7-flash');
    }
  });

  final excludedEndpoints = [
    'https://gateway.example.com/compatible-mode/v1',
    'https://dashscope.aliyuncs.com.evil.example/compatible-mode/v1',
    'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
    'http://dashscope.aliyuncs.com/compatible-mode/v1',
    'https://dashscope.aliyuncs.com:8443/compatible-mode/v1',
    'https://dashscope.aliyuncs.com/v1',
    'https://dashscope.aliyuncs.com/other/compatible-mode/v1',
    '$_baseUrl?proxy=true',
    '$_baseUrl#other',
    'https://user@dashscope.aliyuncs.com/compatible-mode/v1',
    'http://localhost:11434',
  ];
  for (var i = 0; i < excludedEndpoints.length; i++) {
    test('其他端点不接收百炼参数（边界 $i）', () async {
      final service = PolisherService(
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('enable_thinking'), isFalse);
          expect(body['model'], 'qwen3.7-flash');
          return http.Response(
            '{"choices":[{"message":{"content":"OK"}}]}',
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      expect(
        (await service.testConnection(
          config: AIConfig(
            enabled: true,
            baseUrl: excludedEndpoints[i],
            apiKey: _config.apiKey,
            model: _config.model,
          ),
        )).success,
        isTrue,
      );
    });
  }

  for (final model in [
    'qwen3.8-flash',
    'qwen3.7-flash-other',
    'custom-model',
  ]) {
    test('其他模型保持用户选择且不接收百炼参数（$model）', () async {
      final service = PolisherService(
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], model);
          expect(body.containsKey('enable_thinking'), isFalse);
          return http.Response(
            '{"choices":[{"message":{"content":"OK"}}]}',
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      expect(
        (await service.testConnection(
          config: AIConfig(
            enabled: true,
            baseUrl: _baseUrl,
            apiKey: _config.apiKey,
            model: model,
          ),
        )).success,
        isTrue,
      );
    });
  }

  for (final status in [401, 403, 500, 503]) {
    test('连接错误使用通用提示且不泄露密钥或上游正文（$status）', () async {
      final service = PolisherService(
        httpClient: MockClient(
          (request) async =>
              http.Response('sensitive-upstream ${_config.apiKey}', status),
        ),
      );
      addTearDown(service.dispose);
      final result = await service.testConnection(config: _config);
      expect(result.success, isFalse);
      expect(
        result.message,
        status < 500 ? '连接失败：API Key 无效或没有访问权限' : '连接失败：AI 服务暂时不可用，请稍后重试',
      );
      expect(result.message.contains(_config.apiKey), isFalse);
      expect(result.message.contains('sensitive-upstream'), isFalse);
      expect(result.message.contains('OpenCode'), isFalse);
    });
  }

  group('百炼设置交互', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({
        'ai_config': jsonEncode(_oldConfig.toJson()),
      });
    });

    for (final change in ['预设', 'Base URL', 'API Key', 'Model', '启用开关']) {
      for (final status in [200, 401]) {
        testWidgets('在途测试后修改$change，旧响应$status不能回填', (tester) async {
          final response = Completer<http.Response>();
          final service = PolisherService(
            httpClient: MockClient((_) => response.future),
          );
          addTearDown(service.dispose);
          await _openSettings(tester, service: service);
          final testButton = find.byKey(const ValueKey('ai_test_connection'));
          await tester.ensureVisible(testButton);
          await tester.tap(testButton);
          await tester.pump();
          expect(find.text('测试中…'), findsOneWidget);

          if (change == '预设' || change == '启用开关') {
            final target = change == '预设'
                ? find.widgetWithText(ActionChip, '阿里云百炼')
                : find.byKey(const ValueKey('ai_enabled_toggle'));
            await tester.ensureVisible(target);
            await tester.tap(target);
          } else {
            await tester.ensureVisible(_field(change));
            await tester.enterText(_field(change), 'changed-value');
          }
          await tester.pump();
          response.complete(
            http.Response('{"choices":[{"message":{"content":"OK"}}]}', status),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('ai_test_connection_message')),
            findsNothing,
          );
          expect(find.text('测试中…'), findsNothing);
        });
      }
    }

    testWidgets('已保存的 Ollama 保持不变，预设仅填表且显式保存后才生效', (tester) async {
      await _openSettings(tester);
      expect(_fieldValue(tester, '服务商名称'), _oldConfig.name);
      expect(_fieldValue(tester, 'Base URL'), _oldConfig.baseUrl);
      expect(_fieldValue(tester, 'Model'), _oldConfig.model);
      expect(find.widgetWithText(ActionChip, '本地 Ollama'), findsNothing);

      await tester.tap(find.widgetWithText(ActionChip, '阿里云百炼'));
      await tester.pump();
      expect(_fieldValue(tester, '服务商名称'), _config.name);
      expect(_fieldValue(tester, 'Base URL'), _baseUrl);
      expect(_fieldValue(tester, 'Model'), _config.model);
      expect(_fieldValue(tester, 'API Key') == _oldConfig.apiKey, isTrue);
      final repository = AIConfigRepository();
      expect((await repository.loadAIConfig()).baseUrl, _oldConfig.baseUrl);

      await tester.ensureVisible(find.text('保存 AI 配置'));
      await tester.tap(find.text('保存 AI 配置'));
      await tester.pumpAndSettle();
      final saved = await repository.loadAIConfig();
      expect(saved.name, _config.name);
      expect(saved.baseUrl, _baseUrl);
      expect(saved.model, _config.model);
      expect(saved.apiKey == _oldConfig.apiKey, isTrue);
      expect(saved.polishPrompt, _oldConfig.polishPrompt);
      expect(saved.coachPrompt, _oldConfig.coachPrompt);
    });

    testWidgets('预设清除旧测试，测试使用未保存字段，字段仍可编辑', (tester) async {
      final bodies = <Map<String, dynamic>>[];
      final urls = <String>[];
      final service = PolisherService(
        httpClient: MockClient((request) async {
          urls.add(request.url.toString());
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            '{"choices":[{"message":{"content":"OK"}}]}',
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      await _openSettings(tester, service: service);
      final testButton = find.byKey(const ValueKey('ai_test_connection'));
      await tester.ensureVisible(testButton);
      await tester.tap(testButton);
      await tester.pumpAndSettle();
      expect(find.text('连接成功'), findsOneWidget);

      final preset = find.widgetWithText(ActionChip, '阿里云百炼');
      await tester.ensureVisible(preset);
      await tester.tap(preset);
      await tester.pump();
      expect(find.text('连接成功'), findsNothing);
      await tester.ensureVisible(testButton);
      await tester.tap(testButton);
      await tester.pumpAndSettle();
      expect(find.text('连接成功'), findsOneWidget);
      expect(urls.last, '$_baseUrl/chat/completions');
      expect(bodies.last['model'], _config.model);
      expect(bodies.last['enable_thinking'], isFalse);
      expect(
        (await AIConfigRepository().loadAIConfig()).baseUrl,
        _oldConfig.baseUrl,
      );

      for (final field in ['Base URL', 'API Key', 'Model']) {
        await tester.ensureVisible(_field(field));
        await tester.enterText(_field(field), '${_fieldValue(tester, field)} ');
        await tester.pump();
        expect(find.text('连接成功'), findsNothing);
        await tester.ensureVisible(testButton);
        await tester.tap(testButton);
        await tester.pumpAndSettle();
        expect(find.text('连接成功'), findsOneWidget);
      }
      await tester.ensureVisible(_field('Model'));
      await tester.enterText(_field('Model'), 'custom-model');
      await tester.pump();
      expect(_fieldValue(tester, 'Model'), 'custom-model');
      expect(find.text('连接成功'), findsNothing);
    });
  });
}
