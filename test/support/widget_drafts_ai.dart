part of '../widget_test.dart';

void registerDraftsAiTests() {
  group('DraftRepository', () {
    final date = DateTime(2026, 6, 7);
    late DraftRepository repo;
    late _TestStorage storage;

    setUp(() {
      storage = _TestStorage();
      repo = DraftRepository(storage: storage);
    });

    test('quick draft save and restore', () async {
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'hello',
        tags: ['工作'],
      );

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );

      expect(draft, isNotNull);
      expect(draft!.content, 'hello');
      expect(draft.tags, ['工作']);
    });

    test('quick draft entries do not overwrite each other', () async {
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'quick',
        tags: ['q'],
      );
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.reflection,
        content: 'reflect',
        tags: ['r'],
      );
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.happiness,
        content: 'happy',
        tags: ['h'],
      );

      expect(
        (await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.quickNote,
        ))!.content,
        'quick',
      );
      expect(
        (await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.reflection,
        ))!.content,
        'reflect',
      );
      expect(
        (await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.happiness,
        ))!.content,
        'happy',
      );
    });

    test('anxiety draft save and restore', () async {
      await repo.saveAnxietyDraft(
        date: date,
        step: 2,
        answers: ['a1', 'a2', '', ''],
      );

      final draft = await repo.loadAnxietyDraft(date: date);

      expect(draft, isNotNull);
      expect(draft!.step, 2);
      expect(draft.answers, ['a1', 'a2', '', '']);
    });

    test('fromJson survives type-incompatible input', () {
      final draft = QuickDraft.fromJson(<String, dynamic>{});

      expect(draft.content, '');
      expect(draft.tags, isEmpty);
    });

    test('clearDraft returns null', () async {
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'hello',
        tags: [],
      );
      await repo.clearDraft(date: date, entryType: EntryType.quickNote);

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );
      expect(draft, isNull);
    });

    test('bad JSON returns null', () async {
      storage.data['draft_2026-06-07_quickNote'] = 'not json';
      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );
      expect(draft, isNull);
    });

    test('quick draft not expired within TTL', () async {
      final now = DateTime(2026, 6, 7, 10, 0);
      repo = DraftRepository(storage: storage, now: () => now);

      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'hello',
        tags: ['工作'],
      );

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );

      expect(draft, isNotNull);
      expect(draft!.content, 'hello');
    });

    test(
      'quick draft expired after 2 minutes returns null and clears',
      () async {
        final now = DateTime(2026, 6, 7, 10, 0);
        repo = DraftRepository(storage: storage, now: () => now);

        await repo.saveQuickDraft(
          date: date,
          entryType: EntryType.quickNote,
          content: 'hello',
          tags: [],
        );

        // Advance 2 minutes + 1 second
        repo = DraftRepository(
          storage: storage,
          now: () => now.add(const Duration(minutes: 2, seconds: 1)),
        );

        final draft = await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.quickNote,
        );

        expect(draft, isNull);

        // Draft was cleared
        final reloaded = await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.quickNote,
        );
        expect(reloaded, isNull);
      },
    );

    test('anxiety draft not expired within TTL', () async {
      final now = DateTime(2026, 6, 7, 10, 0);
      repo = DraftRepository(storage: storage, now: () => now);

      await repo.saveAnxietyDraft(
        date: date,
        step: 2,
        answers: ['a1', 'a2', '', ''],
      );

      final draft = await repo.loadAnxietyDraft(date: date);

      expect(draft, isNotNull);
      expect(draft!.step, 2);
      expect(draft.answers, ['a1', 'a2', '', '']);
    });

    test(
      'anxiety draft expired after 2 minutes returns null and clears',
      () async {
        final now = DateTime(2026, 6, 7, 10, 0);
        repo = DraftRepository(storage: storage, now: () => now);

        await repo.saveAnxietyDraft(
          date: date,
          step: 2,
          answers: ['a1', 'a2', '', ''],
        );

        repo = DraftRepository(
          storage: storage,
          now: () => now.add(const Duration(minutes: 2, seconds: 1)),
        );

        final draft = await repo.loadAnxietyDraft(date: date);

        expect(draft, isNull);
      },
    );

    test('old format without updatedAt returns null', () async {
      // Simulate old draft without updatedAt field
      storage.data['draft_2026-06-07_quickNote'] = jsonEncode({
        'content': 'old',
        'tags': [],
      });

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );

      expect(draft, isNull);
    });

    test('updatedAt written on save', () async {
      final now = DateTime(2026, 6, 7, 10, 0);
      repo = DraftRepository(storage: storage, now: () => now);

      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'hello',
        tags: ['工作'],
      );

      final raw = storage.data['draft_2026-06-07_quickNote']!;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['updatedAt'], isNotNull);
      expect(json['updatedAt'], now.toIso8601String());
    });
  });

  group('PolishResultParser', () {
    final config = _polishTagConfig();
    const parser = PolishResultParser();

    test('extracts Chinese tags and removes them from content', () {
      final result = parser.parse('今天小宝表达了自己的边界。 #亲子 #亲子沟通 #反思', config);

      expect(result.content, '今天小宝表达了自己的边界。');
      expect(result.tags, ['亲子', '亲子沟通', '反思']);
    });

    test('filters unknown tags, keeps known tags', () {
      final result = parser.parse('正文。 #未知标签 #不存在', config);

      expect(result.content, '正文。 #未知标签 #不存在');
      expect(result.tags, isEmpty);
    });

    test('returns empty tags when domain present but no matching topic', () {
      final result = parser.parse('正文。 #亲子 #反思', config);

      expect(result.content, '正文。');
      expect(result.tags, isEmpty);
    });

    test('returns domain and topic without method', () {
      final result = parser.parse('正文。 #亲子 #亲子沟通', config);

      expect(result.content, '正文。');
      expect(result.tags, ['亲子', '亲子沟通']);
    });

    test('keeps first domain, ignores topic not belonging to it', () {
      final result = parser.parse('正文。 #工作 #亲子沟通', config);

      // 工作 is first domain, 亲子沟通 does not belong to 工作
      expect(result.content, '正文。');
      expect(result.tags, isEmpty);
    });

    test('keeps first domain, ignores topic belonging to later domain', () {
      final result = parser.parse('正文。 #亲子 #工作 #任务执行 #反思', config);

      // 亲子 is first domain, 任务执行 belongs to 工作, ignored
      expect(result.content, '正文。');
      expect(result.tags, isEmpty);
    });

    test('keeps first topic, first method for the selected domain', () {
      final result = parser.parse('正文。 #亲子 #亲子沟通 #陪伴互动 #反思', config);

      // 亲子沟通 is first topic, 陪伴互动 ignored
      expect(result.content, '正文。');
      expect(result.tags, ['亲子', '亲子沟通', '反思']);
    });

    test('cleans 润色后 prefix from content', () {
      final result = parser.parse('润色后：今天小宝表达了边界。 #亲子 #亲子沟通', config);

      expect(result.content, '今天小宝表达了边界。');
      expect(result.tags, ['亲子', '亲子沟通']);
    });

    test('returns content and empty tags when no tags present', () {
      final result = parser.parse('这是一段普通的正文。', config);

      expect(result.content, '这是一段普通的正文。');
      expect(result.tags, isEmpty);
    });

    test('empty TagConfig returns empty tags', () {
      final result = parser.parse(
        '#工作 #任务执行',
        const TagConfig(domains: [], methods: []),
      );

      expect(result.content, '#工作 #任务执行');
      expect(result.tags, isEmpty);
    });
  });

  group('AIConfig', () {
    test('toJson / fromJson round-trip', () {
      const config = AIConfig(
        enabled: true,
        name: 'OpenAI API',
        baseUrl: 'https://api.openai.com',
        apiKey: 'sk-test',
        model: 'gpt-4',
        polishPrompt: '保持简洁',
        coachPrompt: '请用温柔的语气',
      );

      final json = config.toJson();
      final restored = AIConfig.fromJson(json);

      expect(restored.enabled, true);
      expect(restored.name, 'OpenAI API');
      expect(restored.baseUrl, 'https://api.openai.com');
      expect(restored.apiKey, 'sk-test');
      expect(restored.model, 'gpt-4');
      expect(restored.polishPrompt, '保持简洁');
      expect(restored.coachPrompt, '请用温柔的语气');
    });

    test('fromJson defaults name to empty for old data', () {
      final config = AIConfig.fromJson(<String, dynamic>{
        'enabled': true,
        'baseUrl': 'https://api.openai.com',
        'apiKey': 'sk-test',
        'model': 'gpt-4',
      });

      expect(config.name, '');
      expect(config.isUsable, isTrue);
    });

    test('fromJson defaults disabled when fields missing', () {
      final config = AIConfig.fromJson({});

      expect(config.enabled, isFalse);
      expect(config.isUsable, isFalse);
    });

    test('isUsable is false when any required field empty', () {
      expect(
        const AIConfig(
          enabled: true,
          baseUrl: '',
          apiKey: 'k',
          model: 'm',
        ).isUsable,
        isFalse,
      );
      expect(
        const AIConfig(
          enabled: true,
          baseUrl: 'u',
          apiKey: '',
          model: 'm',
        ).isUsable,
        isFalse,
      );
      expect(
        const AIConfig(
          enabled: true,
          baseUrl: 'u',
          apiKey: 'k',
          model: '',
        ).isUsable,
        isFalse,
      );
      expect(
        const AIConfig(
          enabled: false,
          baseUrl: 'u',
          apiKey: 'k',
          model: 'm',
        ).isUsable,
        isFalse,
      );
    });

    test('toString does not expose apiKey', () {
      const config = AIConfig(
        enabled: true,
        baseUrl: 'https://api.test.com',
        apiKey: 'sk-secret-key',
        model: 'gpt-4',
      );

      final str = config.toString();
      expect(str, contains('https://api.test.com'));
      expect(str, contains('gpt-4'));
      expect(str, isNot(contains('sk-secret-key')));
    });

    test('DeepSeek preset defaults to deepseek-v4-flash', () {
      final deepseekPreset = aiPresets.firstWhere((p) => p.name == 'DeepSeek');
      expect(deepseekPreset.model, 'deepseek-v4-flash');
    });

    test('resolvedModel falls back for DeepSeek with empty model', () {
      final config = AIConfig(
        enabled: true,
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com',
        apiKey: 'sk-test',
        model: '',
      );
      expect(config.resolvedModel, 'deepseek-v4-flash');
    });

    test('resolvedModel keeps user model when set', () {
      final config = AIConfig(
        enabled: true,
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com',
        apiKey: 'sk-test',
        model: 'deepseek-v4-expensive',
      );
      // 用户已保存的模型不被覆盖
      expect(config.resolvedModel, 'deepseek-v4-expensive');
    });

    test('resolvedModel does not affect OpenAI', () {
      final config = AIConfig(
        enabled: true,
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com',
        apiKey: 'sk-test',
        model: '',
      );
      // OpenAI 不受 DeepSeek fallback 影响
      expect(config.resolvedModel, '');
    });
  });

  group('AIConfigRepository', () {
    test('loadAIConfig returns disabled config on bad JSON', () async {
      final storage = _TestStorage({'ai_config': 'not json'});
      final repo = AIConfigRepository(storage: storage);

      final config = await repo.loadAIConfig();

      expect(config.enabled, isFalse);
    });

    test('save and load round-trip', () async {
      final storage = _TestStorage();
      final repo = AIConfigRepository(storage: storage);

      const config = AIConfig(
        enabled: true,
        baseUrl: 'https://api.test.com',
        apiKey: 'sk-test-key',
        model: 'gpt-4',
      );

      await repo.saveAIConfig(config);
      final loaded = await repo.loadAIConfig();

      expect(loaded.enabled, isTrue);
      expect(loaded.baseUrl, 'https://api.test.com');
      expect(loaded.apiKey, 'sk-test-key');
      expect(loaded.model, 'gpt-4');
    });

    test('clearAIConfig removes stored config', () async {
      final storage = _TestStorage();
      final repo = AIConfigRepository(storage: storage);

      const config = AIConfig(
        enabled: true,
        baseUrl: 'https://api.test.com',
        apiKey: 'sk-test',
        model: 'gpt-4',
      );

      await repo.saveAIConfig(config);
      await repo.clearAIConfig();

      final loaded = await repo.loadAIConfig();
      expect(loaded.enabled, isFalse);
    });

    test('loadAIConfig returns default when nothing stored', () async {
      final storage = _TestStorage();
      final repo = AIConfigRepository(storage: storage);

      final config = await repo.loadAIConfig();

      expect(config.enabled, isFalse);
    });
  });

  group('PolisherService', () {
    final tagConfig = _polishTagConfig();

    test('throws when content is empty', () async {
      final service = PolisherService();

      expect(
        () => service.polish(
          content: '   ',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('内容为空'),
          ),
        ),
      );
    });

    test('throws when config is disabled', () async {
      final service = PolisherService();

      expect(
        () => service.polish(
          content: '测试内容',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(enabled: false),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('未启用'),
          ),
        ),
      );
    });

    test('parses mock OpenAI response with tags', () async {
      const rawResponse = '''
{
  "choices": [{
    "message": {
      "content": "今天小宝清晰表达了自己的边界。 #亲子 #亲子沟通 #反思"
    }
  }]
}''';

      final client = _FakeHttpClient(body: rawResponse);
      final service = PolisherService(httpClient: client);

      final result = await service.polish(
        content: '今天小宝说不要碰我',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      expect(result.content, '今天小宝清晰表达了自己的边界。');
      expect(result.tags, ['亲子', '亲子沟通', '反思']);
    });

    test('throws when response has no choices', () async {
      final client = _FakeHttpClient(body: '{"choices": []}');
      final service = PolisherService(httpClient: client);

      expect(
        () => service.polish(
          content: '测试',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('未返回结果'),
          ),
        ),
      );
    });

    test('throws on non-200 status', () async {
      final client = _FakeHttpClient(statusCode: 401, body: 'Unauthorized');
      final service = PolisherService(httpClient: client);

      expect(
        () => service.polish(
          content: '测试',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('401'),
          ),
        ),
      );
    });

    test('throws readable timeout error without apiKey', () async {
      final service = PolisherService(httpClient: _TimeoutHttpClient());

      expect(
        () => service.polish(
          content: '测试',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-super-secret',
            model: 'gpt-4',
          ),
        ),
        throwsA(
          isA<Exception>()
              .having((e) => e.toString(), 'message', contains('AI 请求超时'))
              .having(
                (e) => e.toString(),
                'message',
                isNot(contains('sk-super-secret')),
              ),
        ),
      );
    });

    test('system prompt uses default when polishPrompt is empty', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "ok"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('润色规则'));
      expect(systemContent, contains('日记润色助手'));
      expect(systemContent, contains('亲子'));
      expect(systemContent, contains('【固定标签规则】'));
    });

    test('system prompt uses custom prompt when provided', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "ok"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
          polishPrompt: '请用极简风格润色，20字以内。',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('极简风格'));
      expect(systemContent, contains('20字以内'));
      expect(systemContent, contains('【固定标签规则】'));
      expect(systemContent, isNot(contains('日记润色助手')));
    });

    test('system prompt always appends tag rules and output format', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "润色后正文。 #亲子 #亲子沟通"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
          polishPrompt: '字数控制在50字以内',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('字数控制在50字以内'));
      expect(systemContent, contains('【固定标签规则】'));
      expect(systemContent, contains('【输出格式】'));
    });

    test('system prompt does not contain apiKey', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "ok"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-super-secret',
          model: 'gpt-4',
        ),
      );

      final body = client.lastRequestBody!;
      expect(body, isNot(contains('sk-super-secret')));
    });

    test('error messages do not contain apiKey', () async {
      final client = _FakeHttpClient(statusCode: 500, body: 'error');
      final service = PolisherService(httpClient: client);

      String? errorMessage;
      try {
        await service.polish(
          content: '测试',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-super-secret',
            model: 'gpt-4',
          ),
        );
      } catch (e) {
        errorMessage = e.toString();
      }

      expect(errorMessage, isNotNull);
      expect(errorMessage, isNot(contains('sk-super-secret')));
    });

    test('chatUrl normalizes base URLs', () {
      expect(
        PolisherService.chatUrl('https://api.openai.com'),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        PolisherService.chatUrl('https://api.openai.com/'),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        PolisherService.chatUrl('https://api.openai.com/v1'),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        PolisherService.chatUrl('https://api.openai.com/v1/'),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        PolisherService.chatUrl('http://localhost:11434'),
        'http://localhost:11434/v1/chat/completions',
      );
    });

    test(
      'testConnection sends a minimal request to the configured endpoint',
      () async {
        final client = _CapturingClient(
          responseBody: '{"choices":[{"message":{"content":"OK"}}]}',
        );
        final service = PolisherService(httpClient: client);

        final result = await service.testConnection(
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://opencode.ai/zen/go',
            apiKey: 'go-test-key',
            model: 'deepseek-v4-flash',
          ),
        );

        expect(result.success, isTrue);
        expect(result.message, '连接成功');
        expect(
          client.lastUrl,
          'https://opencode.ai/zen/go/v1/chat/completions',
        );
        final body = jsonDecode(client.lastBody!) as Map<String, dynamic>;
        expect(body['model'], 'deepseek-v4-flash');
        expect(body['max_tokens'], 16);
        expect(body, isNot(contains('thinking')));
        expect(client.lastBody, isNot(contains('go-test-key')));
      },
    );

    test(
      'testConnection explains authentication failures without exposing apiKey',
      () async {
        final client = _CapturingClient(statusCode: 401);
        final service = PolisherService(httpClient: client);

        final result = await service.testConnection(
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://opencode.ai/zen/go',
            apiKey: 'sk-secret-key',
            model: 'deepseek-v4-flash',
          ),
        );

        expect(result.success, isFalse);
        expect(result.message, contains('API Key 无效'));
        expect(result.message, isNot(contains('sk-secret-key')));
      },
    );

    test(
      'testConnection validates required fields before requesting',
      () async {
        final client = _CapturingClient();
        final service = PolisherService(httpClient: client);

        final result = await service.testConnection(
          config: const AIConfig(enabled: true, apiKey: 'key', model: 'model'),
        );

        expect(result.success, isFalse);
        expect(result.message, '请输入有效的 Base URL');
        expect(client.lastUrl, isNull);
      },
    );

    test('OpenCode Go polish uses a compatible bounded request body', () async {
      final client = _CapturingHttpClient(
        body: '{"choices":[{"message":{"content":"正文 #亲子 #亲子沟通"}}]}',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '今天记录了一件小事',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://opencode.ai/zen/go',
          apiKey: 'key',
          model: 'deepseek-v4-flash',
        ),
      );

      final body = jsonDecode(client.lastRequestBody!) as Map<String, dynamic>;
      expect(body['max_tokens'], 512);
      expect(body, isNot(contains('thinking')));
    });

    test('official DeepSeek requests explicitly disable thinking', () async {
      final client = _CapturingHttpClient(
        body: '{"choices":[{"message":{"content":"正文 #亲子 #亲子沟通"}}]}',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '今天记录了一件小事',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.deepseek.com',
          apiKey: 'key',
          model: 'deepseek-v4-flash',
        ),
      );

      final body = jsonDecode(client.lastRequestBody!) as Map<String, dynamic>;
      expect(body['thinking'], {'type': 'disabled'});
    });

    test('connection interruption returns an actionable safe error', () async {
      final service = PolisherService(httpClient: _ClientExceptionHttpClient());
      Object? capturedError;

      try {
        await service.polish(
          content: '今天记录了一件小事',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://opencode.ai/zen/go',
            apiKey: 'key',
            model: 'deepseek-v4-flash',
          ),
        );
      } catch (error) {
        capturedError = error;
      }

      expect(capturedError, isNotNull);
      expect(PolisherService.readableError(capturedError!), '暂时无法润色，请检查网络后重试');
    });

    test('recording errors use feature copy without technical details', () {
      expect(
        PolisherService.readableError(Exception('AI 润色未启用或配置不完整')),
        '润色功能尚未配置，请前往设置',
      );
      expect(
        PolisherService.readableError(Exception('润色功能尚未配置，请前往设置')),
        '润色功能尚未配置，请前往设置',
      );
      expect(
        PolisherService.readableError(const AIRequestException(401)),
        '润色服务暂不可用，请前往设置检查配置',
      );
      expect(
        PolisherService.readableError(const AIRequestException(429)),
        '润色请求较多，请稍后重试',
      );
      expect(
        PolisherService.readableError(Exception('AI 请求超时，请稍后重试')),
        '润色超时，请稍后重试',
      );
      expect(
        PolisherService.readableError(Exception('无法连接到 AI 服务，请检查网络或服务地址')),
        '暂时无法润色，请检查网络后重试',
      );
      expect(
        PolisherService.readableError(const AIProviderException('上游内部信息')),
        '润色服务暂不可用，请稍后重试',
      );
    });

    test('coach errors use feature copy without technical details', () {
      expect(
        PolisherService.readableCoachError(Exception('请先在设置中启用AI并配置API')),
        '今日回顾尚未配置，请前往设置',
      );
      expect(
        PolisherService.readableCoachError(const AIRequestException(401)),
        '今日回顾尚未配置，请前往设置',
      );
      expect(
        PolisherService.readableCoachError(Exception('保存今日回顾失败')),
        '今日回顾保存失败，请重试',
      );
      expect(
        PolisherService.readableCoachError(const AIProviderException('内部信息')),
        '暂时无法生成回顾，请稍后重试',
      );
    });

    test(
      'retry succeeds when first response has no tags, second has',
      () async {
        final client = _MultiResponseHttpClient([
          '{"choices":[{"message":{"content":"润色正文"}}]}',
          '{"choices":[{"message":{"content":"润色正文\\n#亲子 #亲子沟通 #反思"}}]}',
        ]);
        final service = PolisherService(httpClient: client);

        final result = await service.polish(
          content: '测试',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        );

        expect(result.content, '润色正文');
        expect(result.tags, ['亲子', '亲子沟通', '反思']);
        expect(client.callCount, 2);
      },
    );

    test(
      'retry still returns content when both responses have no valid tags',
      () async {
        final client = _MultiResponseHttpClient([
          '{"choices":[{"message":{"content":"正文一"}}]}',
          '{"choices":[{"message":{"content":"正文二"}}]}',
        ]);
        final service = PolisherService(httpClient: client);

        final result = await service.polish(
          content: '测试',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        );

        expect(result.content, '正文二');
        expect(result.tags, isEmpty);
        expect(client.callCount, 2);
      },
    );

    test('no retry when first response already has valid tags', () async {
      final client = _MultiResponseHttpClient([
        '{"choices":[{"message":{"content":"正文\\n#亲子 #亲子沟通"}}]}',
      ]);
      final service = PolisherService(httpClient: client);

      final result = await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      expect(result.content, '正文');
      expect(result.tags, ['亲子', '亲子沟通']);
      expect(client.callCount, 1);
    });

    test('retry prompt contains retry instruction', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "无标签正文"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('必须输出 1 个领域 + 1 个主题'));
      expect(systemContent, contains('【重要提醒】'));
    });

    test('retry does not affect polishPlainText', () async {
      final client = _MultiResponseHttpClient([
        '{"choices":[{"message":{"content":"单次润色"}}]}',
      ]);
      final service = PolisherService(httpClient: client);

      final result = await service.polishPlainText(
        content: '测试',
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      expect(result, '单次润色');
      expect(client.callCount, 1);
    });

    test('reflection prompt includes domain guidance', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "ok"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '今天开会时有些急躁',
        entryType: EntryType.reflection,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('觉察与迭代记录'));
      expect(systemContent, contains('属于哪个生活领域'));
    });

    test(
      'reflection retry with method-only recovers with domain+topic',
      () async {
        final client = _MultiResponseHttpClient([
          '{"choices":[{"message":{"content":"正文\\n#反思"}}]}',
          '{"choices":[{"message":{"content":"正文\\n#亲子 #亲子沟通 #反思"}}]}',
        ]);
        final service = PolisherService(httpClient: client);

        final result = await service.polish(
          content: '今天反思了一下',
          entryType: EntryType.reflection,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        );

        // First response had only #反思 (method), filtered as empty tags
        // Second response has domain+topic+method
        expect(result.content, '正文');
        expect(result.tags, ['亲子', '亲子沟通', '反思']);
        expect(client.callCount, 2);
      },
    );

    test('retry instruction includes method warning', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "#反思"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.reflection,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('方法名'));
      expect(systemContent, contains('不能替代领域或主题'));
    });

    test(
      'generateCoach uses Web-compatible prompt and diary context',
      () async {
        final client = _CapturingHttpClient(
          body: '''
{
  "choices": [{
    "message": {
      "content": "📌 模式识别\\n内容\\n\\n🎯 行动建议\\n行动"
    }
  }]
}''',
        );
        final service = PolisherService(httpClient: client);

        final result = await service.generateCoach(
          diaryContext: '【随手记】\n- **09:30** 测试 #生活',
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-secret',
            model: 'gpt-4',
          ),
        );

        final body = client.lastRequestBody!;
        final json = jsonDecode(body) as Map<String, dynamic>;
        final messages = json['messages'] as List;
        final systemContent =
            (messages[0] as Map<String, dynamic>)['content'] as String;
        final userContent =
            (messages[1] as Map<String, dynamic>)['content'] as String;

        expect(result, contains('📌 模式识别'));
        expect(systemContent, contains('你是一位理性、克制的日记回顾者'));
        expect(systemContent, contains('📌 模式识别'));
        expect(systemContent, contains('🎯 行动建议'));
        expect(systemContent, contains('💬 暖心鼓励'));
        expect(systemContent, contains('没有出现的模块视为未填写'));
        expect(systemContent, contains('必须输出「🎯 行动建议」模块'));
        expect(userContent, '今天日记内容：\n【随手记】\n- **09:30** 测试 #生活');
        expect(body, isNot(contains('sk-secret')));
      },
    );

    test('generateCoach keeps a saved custom prompt unchanged', () async {
      final client = _CapturingHttpClient(
        body: '{"choices":[{"message":{"content":"回顾内容"}}]}',
      );
      final service = PolisherService(httpClient: client);

      await service.generateCoach(
        diaryContext: '【随手记】\n今天完成了一件小事',
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
          coachPrompt: '用户自定义的回顾规则',
        ),
      );

      final body = jsonDecode(client.lastRequestBody!) as Map<String, dynamic>;
      final messages = body['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;
      expect(systemContent, contains('用户自定义的回顾规则'));
      expect(systemContent, isNot(contains('你是一位理性、克制的日记回顾者')));
    });

    test(
      'coach diary context ignores empty anxiety and generated tomorrow',
      () {
        const raw = '''
# 今天

## ✍️ 随手记 & 灵感
- **09:30** 读完一章书 #生活

## 😰 焦虑时刻
- 今天什么时候我感到焦虑/紧张？
>
- 当时我在担心什么？（具体到一句话）
>

### 🌙 明日寄语
- 旧的明日寄语
''';

        final context = buildCoachDiaryContext(raw);

        expect(context, contains('【随手记】'));
        expect(context, contains('读完一章书'));
        expect(context, isNot(contains('焦虑时刻')));
        expect(context, isNot(contains('今天什么时候我感到焦虑')));
        expect(context, isNot(contains('旧的明日寄语')));
      },
    );

    test('coach diary context includes only real anxiety answers', () {
      const raw = '''
# 今天

## 😰 焦虑时刻
- 今天什么时候我感到焦虑/紧张？
> 下午开会前
- 当时我在担心什么？（具体到一句话）
>
''';

      final context = buildCoachDiaryContext(raw);

      expect(context, contains('【焦虑时刻】'));
      expect(context, contains('下午开会前'));
      expect(context, isNot(contains('当时我在担心什么')));
    });
  });
}
