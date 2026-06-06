import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litchi_journal_flutter/models/diary_entry.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/models/tag_config.dart';
import 'package:litchi_journal_flutter/services/markdown_parser.dart';
import 'package:litchi_journal_flutter/widgets/quick_note_composer.dart';
import 'package:litchi_journal_flutter/widgets/tag_picker.dart';

TagConfig _testTagConfig() {
  return TagConfig(
    domains: [
      TagDomain(
        id: 'work',
        name: '工作',
        order: 0,
        topics: [
          TagTopic(id: 'work-task', name: '任务执行', order: 0),
        ],
      ),
    ],
    methods: [
      TagMethod(id: 'reflect', name: '反思', order: 0),
    ],
  );
}

void main() {
  test('DiaryEntry.fromJson parses valid data', () {
    final json = {
      'date': '2026-06-06',
      'title': 'Test',
      'raw': 'Hello world',
      'sections': {
        'notes': ['note1', 'note2']
      },
    };
    final entry = DiaryEntry.fromJson(json);
    expect(entry.date, '2026-06-06');
    expect(entry.title, 'Test');
    expect(entry.raw, 'Hello world');
    expect(entry.sections['notes'], ['note1', 'note2']);
  });

  test('DiaryEntry.fromJson handles empty data', () {
    final entry = DiaryEntry.fromJson({});
    expect(entry.date, '');
    expect(entry.title, '');
    expect(entry.raw, '');
    expect(entry.sections, {});
    expect(entry.isEmpty, isTrue);
  });

  test('MarkdownParser maps diary markdown to domain sections', () {
    const markdown = '''
---
tags:
  - 日记
---

# 🌿 星期六 · 此时此刻
> [!quote] 记录让生活更清楚

---
## 🏃 习惯打卡
- [x] 📖 阅读/亲子共读
- [ ] 💊 鱼油/植物甾醇
- 喝水 8 杯

---
## ✍️ 随手记 & 灵感
- **09:30** 写下一个想法 #生活 #日常记录

---
## 😰 焦虑时刻
- 今天什么时候我感到焦虑/紧张？
>

---
## 📈 每日复盘
### 💡 觉察与迭代
- 今天更早休息

### 🧠 人生教练
-

### 🌙 明日寄语
-

---
## 📸 影像记录
''';

    final document = const MarkdownParser().parse(markdown);

    expect(document.title, '🌿 星期六 · 此时此刻');
    expect(document.preamble.single, isA<CalloutContent>());
    expect(document.sections.whereType<HabitSection>(), hasLength(1));
    expect(document.sections.whereType<QuickNoteSection>(), hasLength(1));
    expect(document.sections.whereType<AnxietySection>(), hasLength(1));
    expect(document.sections.whereType<ReviewSection>(), hasLength(1));
    expect(document.sections.whereType<MediaSection>(), hasLength(1));

    final habit = document.sections.whereType<HabitSection>().single;
    expect(habit.contents.whereType<CheckboxContent>(), hasLength(2));
    expect(habit.habits, hasLength(3));
    expect(habit.habits[0].label, '📖 阅读/亲子共读');
    expect(habit.habits[0].checked, isTrue);
    expect(habit.habits[0].rawLine, '- [x] 📖 阅读/亲子共读');
    expect(habit.habits[1].label, '💊 鱼油/植物甾醇');
    expect(habit.habits[1].checked, isFalse);
    expect(habit.habits[1].rawLine, '- [ ] 💊 鱼油/植物甾醇');
    expect(habit.habits[2].label, '喝水 8 杯');

    final quickNote = document.sections.whereType<QuickNoteSection>().single;
    final note = quickNote.contents.whereType<TimelineContent>().single;
    expect(note.time, '09:30');
    expect(note.text, '写下一个想法');
    expect(note.tags, ['#生活', '#日常记录']);
    expect(note.rawLine, '- **09:30** 写下一个想法 #生活 #日常记录');
    expect(quickNote.notes, hasLength(1));
    expect(quickNote.notes.single.time, '09:30');
    expect(quickNote.notes.single.content, '写下一个想法');
    expect(quickNote.notes.single.tags, ['#生活', '#日常记录']);
    expect(
      quickNote.notes.single.rawLine,
      '- **09:30** 写下一个想法 #生活 #日常记录',
    );

    final anxiety = document.sections.whereType<AnxietySection>().single;
    expect(anxiety.isEmpty, isTrue);

    final review = document.sections.whereType<ReviewSection>().single;
    expect(review.isEmpty, isFalse);
  });

  test('MarkdownParser recognizes happiness section', () {
    const markdown = '''
---
---

# 🌟 今天
> [!quote] 每日一言

---
## 🏃 习惯打卡

---
## ✨ 每日小确幸
> **09:30** 喝到一杯好咖啡 #生活 #日常记录
> **14:00** 发现一只可爱的小猫 #生活
>

---
## 📸 影像记录
''';

    final document = const MarkdownParser().parse(markdown);
    final happiness =
        document.sections.whereType<HappinessSection>().single;

    expect(happiness.isEmpty, isFalse);
    expect(happiness.contents, hasLength(1));

    final block = happiness.contents[0] as MarkdownContent;
    expect(block.text, contains('09:30'));
    expect(block.text, contains('喝到一杯好咖啡'));
    expect(block.text, contains('#生活'));
    expect(block.text, contains('#日常记录'));
    expect(block.text, contains('14:00'));
    expect(block.text, contains('可爱的小猫'));
  });

  group('QuickNoteComposer', () {
    Widget buildComposer({
      required Future<void> Function(String, List<String>) onSubmit,
      TagConfig? tagConfig,
      String? tagHint,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: QuickNoteComposer(
            onSubmit: onSubmit,
            tagConfig: tagConfig,
            tagHint: tagHint,
          ),
        ),
      );
    }

    testWidgets('button is disabled when input is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(
        onSubmit: (_, _) async {},
      ));

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('button is enabled when input is not empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(
        onSubmit: (_, _) async {},
      ));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('calls onSubmit with content and empty tags when no tagConfig',
        (WidgetTester tester) async {
      String? submittedContent;
      List<String>? submittedTags;
      await tester.pumpWidget(buildComposer(
        onSubmit: (content, tags) async {
          submittedContent = content;
          submittedTags = tags;
        },
      ));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(submittedContent, 'hello');
      expect(submittedTags, isEmpty);
    });

    testWidgets('clears input on successful submit',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(
        onSubmit: (_, _) async {},
      ));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('preserves input and shows error on failure',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(
        onSubmit: (_, _) async {
          throw Exception('fail');
        },
      ));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'hello');

      expect(find.text('保存失败，请重试'), findsOneWidget);
    });

    testWidgets('button is disabled while saving',
        (WidgetTester tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(buildComposer(
        onSubmit: (_, _) => completer.future,
      ));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('submits tags when selected via tagConfig',
        (WidgetTester tester) async {
      List<String>? submittedTags;
      await tester.pumpWidget(buildComposer(
        tagConfig: _testTagConfig(),
        onSubmit: (_, tags) async {
          submittedTags = tags;
        },
      ));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      await tester.tap(find.text('任务执行').last);
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(submittedTags, ['工作', '任务执行']);
    });

    testWidgets('clears tags on successful submit',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(
        tagConfig: _testTagConfig(),
        onSubmit: (_, _) async {},
      ));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      await tester.tap(find.text('任务执行').last);
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('preserves tags on failed submit',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(
        tagConfig: _testTagConfig(),
        onSubmit: (_, _) async {
          throw Exception('fail');
        },
      ));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      await tester.tap(find.text('任务执行').last);
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Tags should still be visible as pills
      expect(find.text('工作'), findsWidgets);
      expect(find.text('任务执行'), findsWidgets);
    });

    testWidgets('shows tagHint when tagConfig is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(
        onSubmit: (_, _) async {},
        tagHint: '标签暂不可用',
      ));

      expect(find.text('标签暂不可用'), findsOneWidget);
    });
  });

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
              {
                'id': 'work-task',
                'name': '任务执行',
                'order': 0,
              }
            ],
          }
        ],
        'methods': [
          {
            'id': 'reflect',
            'name': '反思',
            'order': 0,
          }
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
      final json = {
        'id': 'work-task',
        'name': '任务执行',
        'order': 0,
      };
      final topic = TagTopic.fromJson(json);
      expect(topic.id, 'work-task');
      expect(topic.name, '任务执行');
      expect(topic.description, isNull);
    });

    test('TagMethod.fromJson handles missing description', () {
      final json = {
        'id': 'remember',
        'name': '回忆',
        'order': 3,
      };
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
      final json = {
        'id': 'work',
        'name': '工作',
        'order': 0,
      };
      final domain = TagDomain.fromJson(json);
      expect(domain.topics, isEmpty);
    });

    test('TagConfig.fromJson handles missing id/name/order safely', () {
      final json = {
        'domains': [
          {
            'topics': [{}],
          }
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
            topics: [
              TagTopic(id: 't1', name: '主题1', order: 0),
            ],
          ),
        ],
        methods: [
          TagMethod(id: 'm1', name: '方法1', order: 0),
        ],
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
                  order: 0),
              TagTopic(id: 'work-collab', name: '沟通协作', order: 1),
            ],
          ),
        ],
        methods: [
          TagMethod(
              id: 'reflect',
              name: '反思',
              description: '对自身行为和思考的回顾',
              order: 0),
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

    testWidgets('defaults to collapsed state',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPicker(onChanged: (_) {}));
      // Chips hidden by default
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('🏷️ 标签'), findsOneWidget);
    });

    testWidgets('expands chips when toggle tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPicker(onChanged: (_) {}));

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();

      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.text('工作'), findsWidgets);
    });

    testWidgets('shows topics after expanding and tapping domain',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPicker(onChanged: (_) {}));

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();

      expect(find.text('任务执行'), findsOneWidget);
    });

    testWidgets('onChanged outputs domain and topic when selected',
        (WidgetTester tester) async {
      List<String>? output;
      await tester.pumpWidget(buildPicker(
        onChanged: (tags) => output = tags,
      ));

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      expect(output, ['工作']);

      await tester.tap(find.text('任务执行').last);
      await tester.pump();
      expect(output, ['工作', '任务执行']);
    });

    testWidgets('onChanged outputs method when toggled',
        (WidgetTester tester) async {
      List<String>? output;
      await tester.pumpWidget(buildPicker(
        onChanged: (tags) => output = tags,
      ));

      await tester.tap(find.text('🏷️ 标签'));
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

    testWidgets('switching domain clears topic',
        (WidgetTester tester) async {
      List<String>? output;
      await tester.pumpWidget(buildPicker(
        onChanged: (tags) => output = tags,
      ));

      await tester.tap(find.text('🏷️ 标签'));
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

    testWidgets('selected pills visible in collapsed state',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPicker(
        initialTags: ['生活', '健康管理', '回忆'],
        onChanged: (_) {},
      ));

      // Pills visible even in collapsed state
      expect(find.text('生活'), findsWidgets);
      expect(find.text('健康管理'), findsAtLeastNWidgets(1));
      expect(find.text('回忆'), findsAtLeastNWidgets(1));

      // Chips not visible
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('collapses when initialTags cleared externally',
        (WidgetTester tester) async {
      List<String> tags = ['工作', '任务执行'];

      await tester.pumpWidget(MaterialApp(
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
      ));

      // Expand and verify chips visible
      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      expect(find.byType(ChoiceChip), findsWidgets);

      // Now clear tags by rebuilding with empty list
      tags = [];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagPicker(
            tagConfig: testConfig,
            initialTags: tags,
            onChanged: (_) {},
          ),
        ),
      ));

      // Should be collapsed again
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('🏷️ 标签'), findsOneWidget);
    });
  });
}
