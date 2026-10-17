part of '../widget_test.dart';

void registerTagsTests() {
  group('TagConfig', () {
    test('TagConfig.fromJson parses domains and methods', () {
      final json = {
        'domains': [
          {
            'id': 'work',
            'name': '工作',
            'description': '职业任务',
            'order': 0,
            'topics': [
              {'id': 'work-task', 'name': '任务执行', 'order': 0},
            ],
          },
        ],
        'methods': [
          {'id': 'reflect', 'name': '反思', 'order': 0},
        ],
      };

      final config = TagConfig.fromJson(json);
      expect(config.domains, hasLength(1));
      expect(config.domains[0].id, 'work');
      expect(config.domains[0].name, '工作');
      expect(config.domains[0].description, '职业任务');
      expect(config.domains[0].order, 0);
      expect(config.domains[0].topics, hasLength(1));

      expect(config.methods, hasLength(1));
      expect(config.methods[0].id, 'reflect');
      expect(config.methods[0].name, '反思');
      expect(config.methods[0].order, 0);
    });

    test('TagTopic.fromJson handles missing description', () {
      final json = {'id': 'work-task', 'name': '任务执行', 'order': 0};
      final topic = TagTopic.fromJson(json);
      expect(topic.id, 'work-task');
      expect(topic.name, '任务执行');
      expect(topic.description, isNull);
    });

    test('TagMethod.fromJson handles missing description', () {
      final json = {'id': 'remember', 'name': '回忆', 'order': 3};
      final method = TagMethod.fromJson(json);
      expect(method.id, 'remember');
      expect(method.name, '回忆');
      expect(method.description, isNull);
    });

    test('TagConfig.fromJson handles missing domains and methods', () {
      final config = TagConfig.fromJson({});
      expect(config.domains, isEmpty);
      expect(config.methods, isEmpty);
    });

    test('TagDomain.fromJson handles missing topics', () {
      final json = {'id': 'work', 'name': '工作', 'order': 0};
      final domain = TagDomain.fromJson(json);
      expect(domain.topics, isEmpty);
    });

    test('TagConfig.fromJson handles missing id/name/order safely', () {
      final json = {
        'domains': [
          {
            'topics': [{}],
          },
        ],
        'methods': [{}],
      };
      final config = TagConfig.fromJson(json);
      expect(config.domains[0].id, '');
      expect(config.domains[0].name, '');
      expect(config.domains[0].order, 0);
      expect(config.domains[0].topics[0].id, '');
      expect(config.domains[0].topics[0].order, 0);
      expect(config.methods[0].id, '');
    });

    test('TagConfig.toJson preserves basic structure', () {
      final config = TagConfig(
        domains: [
          TagDomain(
            id: 'work',
            name: '工作',
            description: 'desc',
            order: 0,
            topics: [TagTopic(id: 't1', name: '主题1', order: 0)],
          ),
        ],
        methods: [TagMethod(id: 'm1', name: '方法1', order: 0)],
      );
      final json = config.toJson();
      expect(json['domains'], isA<List>());
      expect(json['methods'], isA<List>());
      expect(json['domains'][0]['name'], '工作');
      expect(json['domains'][0]['topics'][0]['name'], '主题1');
      expect(json['methods'][0]['name'], '方法1');
    });

    test('cache round-trip preserves nested data', () {
      final original = TagConfig(
        domains: [
          TagDomain(
            id: 'work',
            name: '工作',
            description: '职业任务和职场活动',
            order: 2,
            topics: [
              TagTopic(
                id: 'work-task',
                name: '任务执行',
                description: '具体任务完成',
                order: 0,
              ),
              TagTopic(id: 'work-collab', name: '沟通协作', order: 1),
            ],
          ),
        ],
        methods: [
          TagMethod(
            id: 'reflect',
            name: '反思',
            description: '对自身行为和思考的回顾',
            order: 0,
          ),
          TagMethod(id: 'remember', name: '回忆', order: 3),
        ],
      );

      final jsonString = jsonEncode(original.toJson());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final restored = TagConfig.fromJson(decoded);

      expect(restored.domains, hasLength(1));
      expect(restored.domains[0].id, 'work');
      expect(restored.domains[0].description, '职业任务和职场活动');
      expect(restored.domains[0].topics, hasLength(2));
      expect(restored.domains[0].topics[0].description, '具体任务完成');
      expect(restored.domains[0].topics[1].description, isNull);

      expect(restored.methods, hasLength(2));
      expect(restored.methods[0].description, '对自身行为和思考的回顾');
      expect(restored.methods[1].description, isNull);
    });
  });

  group('TagPicker', () {
    final testConfig = TagConfig(
      domains: [
        TagDomain(
          id: 'work',
          name: '工作',
          order: 0,
          topics: [
            TagTopic(id: 'work-task', name: '任务执行', order: 0),
            TagTopic(id: 'work-collab', name: '沟通协作', order: 1),
          ],
        ),
        TagDomain(
          id: 'life',
          name: '生活',
          order: 1,
          topics: [
            TagTopic(id: 'life-health', name: '健康管理', order: 0),
            TagTopic(id: 'life-daily', name: '日常记录', order: 1),
          ],
        ),
      ],
      methods: [
        TagMethod(id: 'reflect', name: '反思', order: 0),
        TagMethod(id: 'remember', name: '回忆', order: 1),
      ],
    );

    Widget buildPicker({
      List<String> initialTags = const [],
      required ValueChanged<List<String>> onChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TagPicker(
              tagConfig: testConfig,
              initialTags: initialTags,
              onChanged: onChanged,
            ),
          ),
        ),
      );
    }

    testWidgets('defaults to collapsed state', (WidgetTester tester) async {
      await tester.pumpWidget(buildPicker(onChanged: (_) {}));
      // Chips hidden by default
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('标签'), findsOneWidget);
    });

    testWidgets('expands chips when toggle tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildPicker(onChanged: (_) {}));

      await tester.tap(find.text('标签'));
      await tester.pump();

      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.text('工作'), findsWidgets);
      for (final chip in find.byType(ChoiceChip).evaluate()) {
        expect(
          tester.getSize(find.byWidget(chip.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
    });

    testWidgets('shows topics after expanding and tapping domain', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildPicker(onChanged: (_) {}));

      await tester.tap(find.text('标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();

      expect(find.text('任务执行'), findsOneWidget);
    });

    testWidgets('onChanged outputs domain and topic when selected', (
      WidgetTester tester,
    ) async {
      List<String>? output;
      await tester.pumpWidget(buildPicker(onChanged: (tags) => output = tags));

      await tester.tap(find.text('标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      expect(output, ['工作']);

      await tester.tap(find.text('任务执行').last);
      await tester.pump();
      expect(output, ['工作', '任务执行']);
    });

    testWidgets('onChanged outputs method when toggled', (
      WidgetTester tester,
    ) async {
      List<String>? output;
      await tester.pumpWidget(buildPicker(onChanged: (tags) => output = tags));

      await tester.tap(find.text('标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      await tester.tap(find.text('任务执行').last);
      await tester.pump();

      await tester.tap(find.text('反思').last);
      await tester.pump();
      expect(output, ['工作', '任务执行', '反思']);

      await tester.tap(find.text('反思').last);
      await tester.pump();
      expect(output, ['工作', '任务执行']);
    });

    testWidgets('switching domain clears topic', (WidgetTester tester) async {
      List<String>? output;
      await tester.pumpWidget(buildPicker(onChanged: (tags) => output = tags));

      await tester.tap(find.text('标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      await tester.tap(find.text('任务执行').last);
      await tester.pump();
      expect(output, ['工作', '任务执行']);

      await tester.tap(find.text('生活').last);
      await tester.pump();
      expect(output, ['生活']);
    });

    testWidgets('selected pills visible in collapsed state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildPicker(initialTags: ['生活', '健康管理', '回忆'], onChanged: (_) {}),
      );

      // Pills visible even in collapsed state
      expect(find.text('生活'), findsWidgets);
      expect(find.text('健康管理'), findsAtLeastNWidgets(1));
      expect(find.text('回忆'), findsAtLeastNWidgets(1));

      // Chips not visible
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('collapses when initialTags cleared externally', (
      WidgetTester tester,
    ) async {
      List<String> tags = ['工作', '任务执行'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return TagPicker(
                  tagConfig: testConfig,
                  initialTags: tags,
                  onChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );

      // Expand and verify chips visible
      await tester.tap(find.text('标签'));
      await tester.pump();
      expect(find.byType(ChoiceChip), findsWidgets);

      // Now clear tags by rebuilding with empty list
      tags = [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagPicker(
              tagConfig: testConfig,
              initialTags: tags,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Should be collapsed again
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('标签'), findsOneWidget);
    });

    testWidgets('clears stale topic and method when external tags shrink', (
      WidgetTester tester,
    ) async {
      var tags = ['生活', '健康管理', '回忆'];
      late void Function(VoidCallback) update;
      List<String>? output;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return TagPicker(
                  tagConfig: testConfig,
                  initialTags: tags,
                  onChanged: (value) => output = value,
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('标签'));
      await tester.pump();
      update(() => tags = ['生活']);
      await tester.pump();

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '健康管理'))
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '回忆'))
            .selected,
        isFalse,
      );

      final recalledChip = find.widgetWithText(ChoiceChip, '回忆');
      await tester.ensureVisible(recalledChip);
      await tester.tap(recalledChip);
      await tester.pump();
      expect(output, ['生活', '回忆']);
    });

    testWidgets('clears stale method when external tags lose method', (
      WidgetTester tester,
    ) async {
      var tags = ['生活', '健康管理', '回忆'];
      late void Function(VoidCallback) update;
      List<String>? output;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return TagPicker(
                  tagConfig: testConfig,
                  initialTags: tags,
                  onChanged: (value) => output = value,
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('标签'));
      await tester.pump();
      update(() => tags = ['生活', '健康管理']);
      await tester.pump();

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '回忆'))
            .selected,
        isFalse,
      );
      final reflectionChip = find.widgetWithText(ChoiceChip, '反思');
      await tester.ensureVisible(reflectionChip);
      await tester.tap(reflectionChip);
      await tester.pump();
      expect(output, ['生活', '健康管理', '反思']);
    });

    testWidgets('unknown external domain clears all previous selections', (
      WidgetTester tester,
    ) async {
      var tags = ['生活', '健康管理', '回忆'];
      late void Function(VoidCallback) update;
      List<String>? output;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return TagPicker(
                  tagConfig: testConfig,
                  initialTags: tags,
                  onChanged: (value) => output = value,
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('标签'));
      await tester.pump();
      update(() => tags = ['不存在的领域', '健康管理', '回忆']);
      await tester.pump();

      await tester.tap(find.text('反思').last);
      await tester.pump();
      expect(output, ['反思']);
    });

    testWidgets('tag config changes clear removed selections', (
      WidgetTester tester,
    ) async {
      var config = testConfig;
      late void Function(VoidCallback) update;

      final renamedConfig = TagConfig(
        domains: [
          TagDomain(
            id: 'life',
            name: '生活',
            order: 1,
            topics: const [TagTopic(id: 'new-topic', name: '新的主题', order: 1)],
          ),
        ],
        methods: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return TagPicker(
                  tagConfig: config,
                  initialTags: const ['生活', '健康管理', '回忆'],
                  onChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('健康管理'), findsAtLeastNWidgets(1));
      expect(find.text('回忆'), findsAtLeastNWidgets(1));

      update(() => config = renamedConfig);
      await tester.pump();

      expect(find.text('健康管理'), findsNothing);
      expect(find.text('回忆'), findsNothing);
      expect(find.text('新的主题'), findsNothing);
    });

    test('uses distinct domain colors and unified topic/method colors', () {
      final theme = ThemeData.light();

      final workColors = tagChipColorsFor(
        label: '工作',
        tagConfig: testConfig,
        theme: theme,
      );
      final lifeColors = tagChipColorsFor(
        label: '生活',
        tagConfig: testConfig,
        theme: theme,
      );
      final workTopicColors = tagChipColorsFor(
        label: '任务执行',
        tagConfig: testConfig,
        theme: theme,
      );
      final lifeTopicColors = tagChipColorsFor(
        label: '健康管理',
        tagConfig: testConfig,
        theme: theme,
      );
      final reflectColors = tagChipColorsFor(
        label: '反思',
        tagConfig: testConfig,
        theme: theme,
      );
      final rememberColors = tagChipColorsFor(
        label: '回忆',
        tagConfig: testConfig,
        theme: theme,
      );
      final moduleColors = tagChipColorsFor(
        label: '任务执行',
        tagConfig: testConfig,
        theme: theme,
        moduleAccentColor: const Color(0xFF51CF66),
      );

      expect(workColors.backgroundColor, isNot(lifeColors.backgroundColor));
      expect(workTopicColors.backgroundColor, lifeTopicColors.backgroundColor);
      expect(reflectColors.backgroundColor, rememberColors.backgroundColor);
      expect(
        moduleColors.backgroundColor,
        isNot(workTopicColors.backgroundColor),
      );
    });
  });

  testWidgets('happiness slogan hidden when real content exists', (
    WidgetTester tester,
  ) async {
    final section = HappinessSection(
      title: '✨ 每日小确幸',
      contents: [
        const CalloutContent(type: 'success', title: '总有事件值得感恩🙏❤️', body: []),
        const TimelineContent(
          time: '09:30',
          text: '喝到一杯好咖啡',
          tags: [],
          rawLine: '',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GenericSectionCard(section: section)),
      ),
    );

    expect(find.text('总有事件值得感恩'), findsNothing);
    expect(find.text('喝到一杯好咖啡'), findsOneWidget);
  });
}
