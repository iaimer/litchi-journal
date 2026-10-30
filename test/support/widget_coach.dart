part of '../widget_test.dart';

void registerCoachTests() {
  group('splitCoachResultLikeWeb', () {
    test('extracts action and keeps other modules in coach content', () {
      final raw =
          '📌 模式识别\n'
          '- 今天表现很好\n'
          '⚠️ 矛盾指出\n'
          '- 有点焦虑\n'
          '🎯 行动建议\n'
          '- 明天早点睡\n'
          '💬 暖心鼓励\n'
          '- 加油';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);

      expect(parts.actionContent, '明天早点睡');
      expect(parts.lizhiContent, contains('📌 模式识别'));
      expect(parts.lizhiContent, contains('⚠️ 矛盾指出'));
      expect(parts.lizhiContent, contains('💬 暖心鼓励'));
      expect(parts.lizhiContent, isNot(contains('🎯 行动建议')));
      expect(parts.lizhiContent, isNot(contains('- 今天表现很好')));
      expect(parts.lizhiContent, contains('📌 模式识别\n今天表现很好'));
    });

    test('extracts tomorrow message as action content', () {
      final raw =
          '📌 模式识别\n'
          '- 今天专注在阅读和记录\n'
          '🌙 明日寄语\n'
          '- 明天继续读十分钟\n'
          '💬 暖心鼓励\n'
          '- 你在稳步前进';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);

      expect(parts.actionContent, '明天继续读十分钟');
      expect(parts.lizhiContent, contains('📌 模式识别'));
      expect(parts.lizhiContent, contains('💬 暖心鼓励'));
      expect(parts.lizhiContent, isNot(contains('🌙 明日寄语')));
    });

    test('encouragement does not leak into action content', () {
      final raw =
          '🎯 行动建议\n'
          '- 多喝水\n'
          '💬 暖心鼓励\n'
          '- 加油';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);

      expect(parts.actionContent, '多喝水');
      expect(parts.actionContent, isNot(contains('加油')));
      expect(parts.lizhiContent, contains('💬 暖心鼓励'));
      expect(parts.lizhiContent, contains('加油'));
      expect(parts.lizhiContent, isNot(contains('- 加油')));
    });

    test('returns empty action when action module is missing', () {
      final raw =
          '📌 模式识别\n'
          '- 今天不错\n'
          '💬 暖心鼓励\n'
          '- 加油';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);

      expect(parts.actionContent, '');
      expect(parts.lizhiContent, contains('📌'));
      expect(parts.lizhiContent, contains('💬'));
    });

    test('merges multiple bullets into one paragraph per section', () {
      final raw =
          '📌 模式识别\n'
          '- 你习惯先做计划再行动\n'
          '- 你倾向在焦虑时记录情绪触发点\n'
          '\n'
          '⚠️ 矛盾指出\n'
          '- 你设计了焦虑处理流程\n'
          '- 但实际记录只写了计划部分\n'
          '\n'
          '🎯 行动建议\n'
          '- 明天完成焦虑情境的完整记录\n'
          '- 计划执行后预留5分钟回顾\n'
          '\n'
          '💬 暖心鼓励\n'
          '- 你已经开始用计划管理任务\n'
          '- 继续保持记录';

      final parts = PolisherService.splitCoachResultLikeWeb(raw);

      expect(
        parts.lizhiContent,
        '📌 模式识别\n'
        '你习惯先做计划再行动 你倾向在焦虑时记录情绪触发点\n'
        '⚠️ 矛盾指出\n'
        '你设计了焦虑处理流程 但实际记录只写了计划部分\n'
        '💬 暖心鼓励\n'
        '你已经开始用计划管理任务 继续保持记录',
      );
      expect(parts.actionContent, '明天完成焦虑情境的完整记录\n计划执行后预留5分钟回顾');
    });
  });

  group('coach content normalization', () {
    test('title and body on same line with ** artifacts', () {
      final raw =
          '📌 **模式识别** 今天你展现了清晰的目标导向\n'
          '⚠️ **矛盾指出** 然而你记录焦虑时\n'
          '💬 **暖心鼓励** 你已经开始训练觉察力';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      final lines = parts.lizhiContent.split('\n');
      expect(lines[0], '📌 模式识别');
      expect(lines[1], '今天你展现了清晰的目标导向');
      expect(lines[2], '⚠️ 矛盾指出');
      expect(lines[3], '然而你记录焦虑时');
      expect(lines[4], '💬 暖心鼓励');
      expect(lines[5], '你已经开始训练觉察力');
    });

    test('title with colon and body on same line', () {
      final raw =
          '📌 模式识别：今天你展现了清晰的目标导向\n'
          '⚠️ 矛盾指出：然而你记录焦虑时';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      expect(parts.lizhiContent, contains('📌 模式识别'));
      expect(parts.lizhiContent, contains('今天你展现了清晰的目标导向'));
      expect(parts.lizhiContent, isNot(contains('**')));
      expect(parts.lizhiContent, isNot(contains('：')));
    });

    test('header markdown ### is stripped', () {
      final raw =
          '### 📌 **模式识别**\n'
          '今天不错\n'
          '### ⚠️ **矛盾指出**\n'
          '有点问题';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      expect(parts.lizhiContent, contains('📌 模式识别'));
      expect(parts.lizhiContent, contains('⚠️ 矛盾指出'));
      expect(parts.lizhiContent, isNot(contains('###')));
      expect(parts.lizhiContent, isNot(contains('**')));
    });

    test('alias titles are normalized', () {
      final raw =
          '主要模式与趋势\n'
          '今天不错\n'
          '潜在矛盾与提醒\n'
          '有点问题\n'
          '温暖结语\n'
          '加油';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      expect(parts.lizhiContent, contains('📌 模式识别'));
      expect(parts.lizhiContent, contains('⚠️ 矛盾指出'));
      expect(parts.lizhiContent, contains('💬 暖心鼓励'));
      expect(parts.lizhiContent, isNot(contains('主要模式')));
      expect(parts.lizhiContent, isNot(contains('潜在矛盾')));
      expect(parts.lizhiContent, isNot(contains('温暖结语')));
    });

    test('body text with contradiction words is not treated as title', () {
      final raw =
          '📌 模式识别\n'
          '你今天习惯先计划再行动\n'
          '⚠️ 矛盾指出\n'
          '你一面想保持节奏，一面又被未完成事项牵动，这种矛盾状态值得留意。\n'
          '这种不一致不是失败，而是提醒你需要更小的行动入口。\n'
          '💬 暖心鼓励\n'
          '你已经在认真观察自己';

      final parts = PolisherService.splitCoachResultLikeWeb(raw);

      expect(RegExp('⚠️ 矛盾指出').allMatches(parts.lizhiContent), hasLength(1));
      expect(parts.lizhiContent, contains('这种矛盾状态值得留意'));
      expect(parts.lizhiContent, contains('这种不一致不是失败'));
    });

    test('body ** is cleaned', () {
      final raw =
          '📌 **模式识别**\n'
          '- 你今天**表现很好**特别棒';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      expect(parts.lizhiContent, isNot(contains('**')));
      expect(parts.lizhiContent, contains('你今天表现很好特别棒'));
    });

    test('standard format is not broken', () {
      final raw =
          '📌 模式识别\n'
          '- 今天表现很好\n'
          '⚠️ 矛盾指出\n'
          '- 有点焦虑\n'
          '💬 暖心鼓励\n'
          '- 加油';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      expect(parts.lizhiContent, contains('📌 模式识别'));
      expect(parts.lizhiContent, contains('⚠️ 矛盾指出'));
      expect(parts.lizhiContent, contains('💬 暖心鼓励'));
      expect(parts.lizhiContent, isNot(contains('**')));
    });
  });

  group('DiaryMarkdownView coach and tomorrow', () {
    testWidgets('shows both coach and tomorrow sections', (tester) async {
      const markdown = '''
---
tags:
  - 日记
---

# 今天

### 🧠 人生教练
📌 模式识别
- 你今天表现很好
⚠️ 矛盾指出
- 有一点焦虑
💬 暖心鼓励
- 加油

### 🌙 明日寄语
- 明天完成重要任务
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () {},
              generatingCoach: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Coach section should show
      expect(find.text('今日回顾'), findsOneWidget);
      expect(find.text('人生教练'), findsNothing);
      expect(find.text('模式识别'), findsOneWidget);
      expect(find.text('矛盾指出'), findsOneWidget);
      expect(find.text('暖心鼓励'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is FloraIcon && w.name == FloraIcons.pin,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is FloraIcon && w.name == FloraIcons.warning,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is FloraIcon && w.name == FloraIcons.chatFeedback,
        ),
        findsOneWidget,
      );

      // Tomorrow section should show
      expect(find.text('明日寄语'), findsOneWidget);
      expect(find.text('🌙 明日寄语'), findsNothing);
      expect(find.text('明天完成重要任务'), findsOneWidget);
    });

    testWidgets('coach content uses one shared quiet surface container', (
      tester,
    ) async {
      const markdown = '''
# 今天

### 🧠 人生教练
📌 模式识别
你今天表现很好
⚠️ 矛盾指出
有一点焦虑
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () {},
              readOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.text('你今天表现很好'),
          matching: find.byKey(const ValueKey('diary_group_ai')),
        ),
        findsOneWidget,
      );
      expect(find.text('模式识别'), findsOneWidget);
      expect(find.text('矛盾指出'), findsOneWidget);
      for (final name in [
        FloraIcons.sectionCoach,
        FloraIcons.pin,
        FloraIcons.warning,
      ]) {
        expect(
          find.byWidgetPredicate(
            (widget) => widget is FloraIcon && widget.name == name,
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('restore default rendering after changes', (tester) async {
      const markdown = '''
---
tags:
  - 日记
---

# 今天

## 📈 每日复盘
### 🧠 人生教练
📌 模式识别
今天表现很好
### 🌙 明日寄语
明天完成重要任务
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () {},
              generatingCoach: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both sections exist independently
      expect(find.text('今日回顾'), findsOneWidget);
      expect(find.text('人生教练'), findsNothing);
      expect(find.text('明日寄语'), findsOneWidget);
    });

    testWidgets('readOnly=false shows regenerate button', (tester) async {
      const markdown = '''
# 今天

### 🧠 人生教练
📌 模式识别
你今天表现很好
⚠️ 矛盾指出
有一点焦虑
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () {},
              readOnly: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // update button should show
      expect(find.text('更新回顾'), findsOneWidget);
    });

    testWidgets('readOnly=false shows generate button for empty coach', (
      tester,
    ) async {
      var tapped = false;
      const markdown = '''
# 今天

### 🧠 人生教练
-
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () => tapped = true,
              readOnly: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日回顾'), findsNothing);
      expect(find.text('生成今日回顾'), findsOneWidget);

      final generateButton = find.ancestor(
        of: find.text('生成今日回顾'),
        matching: find.byType(TextButton),
      );
      expect(tester.getSize(generateButton).height, greaterThanOrEqualTo(48));

      await tester.tap(find.text('生成今日回顾'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets(
      'readOnly=false shows generate button when coach section missing',
      (tester) async {
        const markdown = '''
# 今天

## 🏃 习惯打卡
- [x] 📖 阅读/亲子共读

### 🌙 明日寄语
- 明天完成重要任务
''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DiaryMarkdownView(
                markdown: markdown,
                onGenerateCoach: () {},
                readOnly: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('今日回顾'), findsNothing);
        expect(find.text('生成今日回顾'), findsOneWidget);
        expect(find.text('明日寄语'), findsOneWidget);
        expect(find.text('习惯打卡'), findsOneWidget);
        expect(find.text('🏃 习惯打卡'), findsNothing);
      },
    );

    testWidgets('old coach title still shows generate button when editable', (
      tester,
    ) async {
      const markdown = '''
# 今天

### 🧠 荔枝喵说
-
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () {},
              readOnly: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日回顾'), findsNothing);
      expect(find.text('人生教练'), findsNothing);
      expect(find.text('荔枝喵说'), findsNothing);
      expect(find.text('生成今日回顾'), findsOneWidget);
    });

    testWidgets('readOnly=true hides regenerate button', (tester) async {
      const markdown = '''
# 今天

### 🧠 人生教练
📌 模式识别
你今天表现很好
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () {},
              readOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Coach content should show
      expect(find.text('今日回顾'), findsOneWidget);
      expect(find.text('人生教练'), findsNothing);
      expect(find.text('模式识别'), findsOneWidget);
      // Regenerate button should NOT show
      expect(find.text('更新回顾'), findsNothing);
      expect(find.text('生成今日回顾'), findsNothing);
    });

    testWidgets('荔枝喵说 title displays as 今日回顾', (tester) async {
      const markdown = '''
# 今天

### 🧠 荔枝喵说
📌 模式识别
你今天表现很好
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(markdown: markdown, readOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show as 今日回顾, not 荔枝喵说
      expect(find.text('今日回顾'), findsOneWidget);
      expect(find.text('人生教练'), findsNothing);
      expect(find.text('荔枝喵说'), findsNothing);
    });

    testWidgets('old format **模式识别** renders as module title', (tester) async {
      const markdown = '''
# 今天

### 🧠 人生教练
**模式识别**：今天两条线索并行。
**矛盾指出**：16:07 小宝能独立玩乐高。
**批判性问题**：你在旁边盯着的行为。
**甜点**：4岁半能在陌生游乐场自得其乐。
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(markdown: markdown, readOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Old format patterns should be normalized to display titles
      expect(find.text('模式识别'), findsOneWidget);
      expect(find.text('矛盾指出'), findsOneWidget);
      expect(find.text('批判性问题'), findsOneWidget);
      expect(find.text('甜点'), findsOneWidget);

      // Raw ** markers should NOT appear
      expect(find.text('**模式识别**'), findsNothing);
      expect(find.text('**矛盾指出**'), findsNothing);
      expect(find.text('**批判性问题**'), findsNothing);
      expect(find.text('**甜点**'), findsNothing);

      // Body text (after colon) should still appear
      expect(find.text('今天两条线索并行。'), findsOneWidget);
      expect(find.text('16:07 小宝能独立玩乐高。'), findsOneWidget);
    });

    testWidgets('old format with emoji prefix normalizes correctly', (
      tester,
    ) async {
      const markdown = '''
# 今天

### 🧠 人生教练
🍰 **甜点**：4岁半能在陌生游乐场自得其乐。
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(markdown: markdown, readOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify body text appears (without raw ** markers)
      expect(find.text('4岁半能在陌生游乐场自得其乐。'), findsOneWidget);
      // Verify no raw ** markers remain
      expect(find.text('**甜点**'), findsNothing);
      // Verify 今日回顾 title still shows
      expect(find.text('今日回顾'), findsOneWidget);
    });

    testWidgets(
      'hiddenSections hides tomorrow and habits only when specified',
      (tester) async {
        const markdown = '''
# 今天

## 🏃 习惯打卡
- [x] 📖 阅读/亲子共读

### 🧠 人生教练
📌 模式识别
你今天表现很好

### 🌙 明日寄语
- 明天完成重要任务
''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DiaryMarkdownView(
                markdown: markdown,
                readOnly: true,
                hiddenSections: {'tomorrow', 'habits'},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('今日回顾'), findsOneWidget);
        expect(find.text('模式识别'), findsOneWidget);
        expect(find.text('🌙 明日寄语'), findsNothing);
        expect(find.text('🏃 习惯打卡'), findsNothing);
        expect(find.text('📖 阅读/亲子共读'), findsNothing);
      },
    );

    testWidgets('hiddenSections hides habit tracking title variant', (
      tester,
    ) async {
      const markdown = '''
# 今天

## 📌 习惯追踪
- [x] 📖 阅读/亲子共读

### 🧠 人生教练
📌 模式识别
你今天表现很好
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              readOnly: true,
              hiddenSections: {'tomorrow', 'habits'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日回顾'), findsOneWidget);
      expect(find.text('📌 习惯追踪'), findsNothing);
      expect(find.text('📖 阅读/亲子共读'), findsNothing);
    });

    testWidgets('hiddenSections accepts Chinese section keys', (tester) async {
      const markdown = '''
# 今天

## 🏃 习惯打卡
- [x] 📖 阅读/亲子共读

### 🌙 明日寄语
- 明天完成重要任务

### 🧠 人生教练
📌 模式识别
你今天表现很好
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              readOnly: true,
              hiddenSections: {'明日寄语', '习惯打卡'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日回顾'), findsOneWidget);
      expect(find.text('🌙 明日寄语'), findsNothing);
      expect(find.text('🏃 习惯打卡'), findsNothing);
      expect(find.text('📖 阅读/亲子共读'), findsNothing);
    });

    testWidgets(
      'today rendering keeps tomorrow and habits without hiddenSections',
      (tester) async {
        const markdown = '''
# 今天

## 🏃 习惯打卡
- [x] 📖 阅读/亲子共读

### 🧠 人生教练
📌 模式识别
你今天表现很好

### 🌙 明日寄语
- 明天完成重要任务
''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DiaryMarkdownView(
                markdown: markdown,
                onGenerateCoach: () {},
                readOnly: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('今日回顾'), findsOneWidget);
        expect(find.text('更新回顾'), findsOneWidget);
        expect(find.text('明日寄语'), findsOneWidget);
        expect(find.text('明天完成重要任务'), findsOneWidget);
        expect(find.text('习惯打卡'), findsOneWidget);
        expect(find.text('🏃 习惯打卡'), findsNothing);
        expect(find.text('亲子共读'), findsOneWidget);
      },
    );

    testWidgets(
      'editable view adds fallback habit card when habit section missing',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DiaryMarkdownView(
                markdown: '# 今天\n',
                onHabitUpdate: (_) async => true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('habit_card')), findsOneWidget);
        expect(find.text('习惯打卡'), findsOneWidget);
        expect(find.text('🏃 习惯打卡'), findsNothing);
        expect(find.text('亲子共读'), findsOneWidget);
      },
    );
  });

  group('Diary section display titles', () {
    test(
      'known system sections lose storage emoji but custom titles stay intact',
      () {
        final sections = <DiarySection>[
          HabitSection(title: '🏃 习惯打卡', contents: [], habits: []),
          QuickNoteSection(title: '✍️ 随手记', contents: [], notes: []),
          HappinessSection(title: '✨ 小确幸', contents: []),
          AnxietySection(title: '😰 焦虑时刻', contents: []),
          ReviewSection(title: '🔍 觉察', contents: []),
          CoachSection(title: '🧠 人生教练', contents: []),
          TomorrowSection(title: '🌙 明日寄语', contents: []),
          MediaSection(title: '📸 影像记录', contents: []),
          GenericDiarySection(title: '🧩 我的栏目', contents: []),
        ];

        expect(sections.map(diarySectionDisplayTitle).toList(), const [
          '习惯打卡',
          '随手记',
          '小确幸',
          '焦虑时刻',
          '觉察',
          '今日回顾',
          '明日寄语',
          '影像记录',
          '🧩 我的栏目',
        ]);
      },
    );
  });
}
