part of '../widget_test.dart';

void registerEntryEditsTests() {
  group('EntryLineBuilder', () {
    test('rebuildTimelineLine preserves - prefix and time', () {
      const rawLine = '- **09:30** 原始内容 #旧标签';

      final result = rebuildTimelineLine(
        rawLine: rawLine,
        content: '新内容',
        tags: ['亲子', '亲子沟通'],
      );

      expect(result, '- **09:30** 新内容 #亲子 #亲子沟通');
    });

    test('rebuildTimelineLine preserves > prefix and time', () {
      const rawLine = '> **14:00** 小确幸原文 #生活';

      final result = rebuildTimelineLine(
        rawLine: rawLine,
        content: '更新后的内容',
        tags: ['生活', '日常记录'],
      );

      expect(result, '> **14:00** 更新后的内容 #生活 #日常记录');
    });

    test('rebuildTimelineLine preserves original time', () {
      const rawLine = '- **23:59** 晚间记录';

      final result = rebuildTimelineLine(
        rawLine: rawLine,
        content: '修改后',
        tags: [],
      );

      expect(result, '- **23:59** 修改后');
    });

    test('rebuildTimelineLine no tags produces no hashtag', () {
      const rawLine = '- **12:00** 内容 #标签';

      final result = rebuildTimelineLine(
        rawLine: rawLine,
        content: '新内容',
        tags: [],
      );

      expect(result, '- **12:00** 新内容');
    });

    test('rebuildTimelineLine throws on invalid format', () {
      expect(
        () => rebuildTimelineLine(
          rawLine: 'no prefix line',
          content: 'x',
          tags: [],
        ),
        throwsArgumentError,
      );
    });

    test('rebuildTimelineLine handles tags with addHash format', () {
      const rawLine = '- **08:00** 原文 #a #b';

      final result = rebuildTimelineLine(
        rawLine: rawLine,
        content: '新',
        tags: ['工作', '任务执行', '反思'],
      );

      expect(result, '- **08:00** 新 #工作 #任务执行 #反思');
    });
  });

  group('EntryDelete', () {
    testWidgets('QuickNoteTimeline shows delete button', (tester) async {
      final section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '09:30',
            content: '测试内容',
            tags: ['#工作'],
            rawLine: '- **09:30** 测试内容 #工作',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteTimeline(section: section, onDelete: (_) async {}),
          ),
        ),
      );

      expect(find.byTooltip("更多操作"), findsOneWidget);
      expect(find.byType(JournalSection), findsOneWidget);
    });

    testWidgets('QuickNoteTimeline delete button shows confirm dialog', (
      tester,
    ) async {
      final section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '09:30',
            content: '测试',
            tags: [],
            rawLine: '- **09:30** 测试',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteTimeline(section: section, onDelete: (_) async {}),
          ),
        ),
      );

      await tester.tap(find.byTooltip("更多操作"));
      await tester.pumpAndSettle();

      // The action sheet only shows operations with available callbacks.
      expect(find.text('编辑'), findsNothing);
      expect(find.text('删除'), findsOneWidget);

      // Tap delete in the action sheet
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.text('确认删除'), findsOneWidget);
      expect(find.text('确定删除这条记录吗？'), findsOneWidget);
    });

    testWidgets('QuickNoteTimeline delete confirmation reports linked photos', (
      tester,
    ) async {
      final section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '09:30',
            content: '图文记录',
            tags: [],
            rawLine: '- **09:30** 图文记录',
            photos: const [
              DiaryPhoto(filename: 'one.jpg', rawLine: '![[one.jpg]]'),
              DiaryPhoto(filename: 'two.jpg', rawLine: '![[two.jpg]]'),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteTimeline(section: section, onDelete: (_) async {}),
          ),
        ),
      );

      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.text('同时删除关联的 2 张照片，确定继续吗？'), findsOneWidget);
    });

    testWidgets(
      'QuickNoteTimeline confirm delete calls onDelete with rawLine',
      (tester) async {
        String? deletedRawLine;
        final section = QuickNoteSection(
          title: '随手记',
          contents: [],
          notes: [
            QuickNoteItem(
              time: '09:30',
              content: '测试',
              tags: [],
              rawLine: '- **09:30** 测试 #工作',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QuickNoteTimeline(
                section: section,
                onDelete: (note) async {
                  deletedRawLine = note.rawLine;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byTooltip("更多操作"));
        await tester.pumpAndSettle();

        // Tap delete in action sheet
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();

        // Now tap delete in confirm dialog
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();

        expect(deletedRawLine, '- **09:30** 测试 #工作');
      },
    );

    testWidgets('GenericSectionCard single happiness shows plain text', (
      tester,
    ) async {
      final section = HappinessSection(
        title: '小确幸',
        contents: [
          TimelineContent(
            time: '14:00',
            text: '下班看到晚霞',
            tags: ['#生活'],
            rawLine: '> **14:00** 下班看到晚霞 #生活',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenericSectionCard(section: section)),
        ),
      );

      // 单条显示纯文本，无项目符号
      expect(find.text('下班看到晚霞'), findsOneWidget);
      expect(find.text('•'), findsNothing);
      // 无 timeline 图标
      expect(find.byTooltip("更多操作"), findsNothing);
    });

    testWidgets('GenericSectionCard multiple happiness shows bullet list', (
      tester,
    ) async {
      final section = HappinessSection(
        title: '小确幸',
        contents: [
          TimelineContent(
            time: '14:00',
            text: '下班看到晚霞',
            tags: [],
            rawLine: '> **14:00** 下班看到晚霞',
          ),
          TimelineContent(
            time: '15:00',
            text: '女儿收拾玩具',
            tags: [],
            rawLine: '> **15:00** 女儿收拾玩具',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenericSectionCard(section: section)),
        ),
      );

      // 多条显示 bullet list
      expect(find.text('•'), findsNWidgets(2));
      expect(find.text('下班看到晚霞'), findsOneWidget);
      expect(find.text('女儿收拾玩具'), findsOneWidget);
      // 无 timeline 样式
      expect(find.text('14:00'), findsNothing);
      expect(find.text('15:00'), findsNothing);
      expect(find.byTooltip("更多操作"), findsNothing);
    });

    testWidgets('GenericSectionCard happiness no longer shows timeline', (
      tester,
    ) async {
      final section = HappinessSection(
        title: '小确幸',
        contents: [
          TimelineContent(
            time: '20:00',
            text: '散步很快乐',
            tags: [],
            rawLine: '> **20:00** 散步很快乐',
          ),
          TimelineContent(
            time: '21:00',
            text: '喝了杯热茶',
            tags: [],
            rawLine: '> **21:00** 喝了杯热茶',
          ),
          TimelineContent(
            time: '22:00',
            text: '看了本好书',
            tags: [],
            rawLine: '> **22:00** 看了本好书',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenericSectionCard(section: section)),
        ),
      );

      // 三条都是 bullet，不是时间标签
      expect(find.text('•'), findsNWidgets(3));
      expect(find.text('20:00'), findsNothing);
      expect(find.text('21:00'), findsNothing);
      expect(find.text('22:00'), findsNothing);
    });

    testWidgets('GenericSectionCard happiness shows actions per entry', (
      tester,
    ) async {
      final section = HappinessSection(
        title: '小确幸',
        contents: [
          const TimelineContent(
            time: '14:00',
            text: '下班看到晚霞',
            tags: ['#生活'],
            rawLine: '> **14:00** 下班看到晚霞 #生活',
          ),
          const TimelineContent(
            time: '15:00',
            text: '女儿收拾玩具',
            tags: [],
            rawLine: '> **15:00** 女儿收拾玩具',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericSectionCard(
              section: section,
              onTimelineDelete: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('•'), findsNWidgets(2));
      expect(find.byTooltip("更多操作"), findsNWidgets(2));
    });

    testWidgets('happiness edit reuses capture page and preserves rawLine', (
      tester,
    ) async {
      const rawLine = '> **14:00** 旧小确幸 #生活';
      String? savedRawLine;
      String? savedContent;
      List<String>? savedTags;
      String? savedTime;
      final section = HappinessSection(
        title: '小确幸',
        contents: const [
          TimelineContent(
            time: '14:00',
            text: '旧小确幸',
            tags: ['#生活'],
            rawLine: rawLine,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericSectionCard(
              section: section,
              onTimelineEdit: (rawLine, content, tags, time) async {
                savedRawLine = rawLine;
                savedContent = content;
                savedTags = tags;
                savedTime = time;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip("更多操作"));
      await tester.pumpAndSettle();
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('删除'), findsNothing);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureScreen), findsOneWidget);
      expect(find.text('编辑记录'), findsOneWidget);
      expect(find.text('今天 14:00'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
        '今天有什么小确幸？',
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedRawLine, rawLine);
      expect(savedContent, '旧小确幸');
      expect(savedTags, const ['生活']);
      expect(savedTime, '14:00');
    });

    testWidgets('happiness delete uses the original rawLine', (tester) async {
      const rawLine = '> **15:00** 原始小确幸 #生活';
      String? deletedRawLine;
      final section = HappinessSection(
        title: '小确幸',
        contents: const [
          TimelineContent(
            time: '15:00',
            text: '原始小确幸',
            tags: ['#生活'],
            rawLine: rawLine,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericSectionCard(
              section: section,
              onTimelineDelete: (rawLine) async {
                deletedRawLine = rawLine;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip("更多操作"));
      await tester.pumpAndSettle();
      expect(find.text('编辑'), findsNothing);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(deletedRawLine, rawLine);
    });

    testWidgets(
      'GenericSectionCard reflection delete calls onDelete with rawLine',
      (tester) async {
        String? deletedRawLine;
        final section = ReviewSection(
          title: '觉察',
          contents: [
            TimelineContent(
              time: '10:00',
              text: '觉察内容',
              tags: ['#反思'],
              rawLine: '- **10:00** 觉察内容 #反思',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenericSectionCard(
                section: section,
                onTimelineDelete: (rawLine) async {
                  deletedRawLine = rawLine;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byTooltip("更多操作"));
        await tester.pumpAndSettle();

        // Tap delete in action sheet
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();

        // Tap delete in confirm dialog
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();

        expect(deletedRawLine, '- **10:00** 觉察内容 #反思');
      },
    );

    testWidgets('GenericSectionCard single reflection hides its timeline', (
      tester,
    ) async {
      final section = ReviewSection(
        title: '觉察',
        contents: [
          TimelineContent(
            time: '10:00',
            text: '先停下来观察',
            tags: ['#反思'],
            rawLine: '- **10:00** 先停下来观察 #反思',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericSectionCard(
              section: section,
              onTimelineDelete: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('先停下来观察'), findsOneWidget);
      expect(find.text('10:00'), findsNothing);
      expect(find.text('•'), findsNothing);
      expect(find.byType(JournalTimelineRow), findsNothing);
      expect(find.byTooltip("更多操作"), findsOneWidget);
    });

    testWidgets('GenericSectionCard multiple reflections use bullets', (
      tester,
    ) async {
      final section = ReviewSection(
        title: '觉察',
        contents: [
          TimelineContent(
            time: '10:00',
            text: '先停下来观察',
            tags: [],
            rawLine: '- **10:00** 先停下来观察',
          ),
          TimelineContent(
            time: '21:30',
            text: '把感受说清楚',
            tags: [],
            rawLine: '- **21:30** 把感受说清楚',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenericSectionCard(section: section)),
        ),
      );

      expect(find.text('先停下来观察'), findsOneWidget);
      expect(find.text('把感受说清楚'), findsOneWidget);
      expect(find.text('10:00'), findsNothing);
      expect(find.text('21:30'), findsNothing);
      expect(find.text('•'), findsNWidgets(2));
      expect(find.byType(JournalTimelineRow), findsNothing);
      expect(find.byTooltip("更多操作"), findsNothing);
    });

    testWidgets('multiple reflections keep actions tied to each rawLine', (
      tester,
    ) async {
      String? deletedRawLine;
      final section = ReviewSection(
        title: '觉察',
        contents: [
          TimelineContent(
            time: '10:00',
            text: '先停下来观察',
            tags: [],
            rawLine: '- **10:00** 先停下来观察',
          ),
          TimelineContent(
            time: '21:30',
            text: '把感受说清楚',
            tags: [],
            rawLine: '- **21:30** 把感受说清楚',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericSectionCard(
              section: section,
              onTimelineDelete: (rawLine) async {
                deletedRawLine = rawLine;
              },
            ),
          ),
        ),
      );

      final actionIcons = find.byTooltip("更多操作");
      expect(actionIcons, findsNWidgets(2));
      await tester.tap(actionIcons.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(deletedRawLine, '- **21:30** 把感受说清楚');
    });

    testWidgets('GenericSectionCard reflection list supports dark large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final section = ReviewSection(
        title: '觉察',
        contents: [
          TimelineContent(
            time: '10:00',
            text: '先停下来观察自己的感受',
            tags: ['#反思'],
            rawLine: '- **10:00** 先停下来观察自己的感受 #反思',
          ),
          TimelineContent(
            time: '21:30',
            text: '把感受说清楚再行动',
            tags: [],
            rawLine: '- **21:30** 把感受说清楚再行动',
          ),
        ],
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(body: GenericSectionCard(section: section)),
          ),
        ),
      );

      expect(find.text('先停下来观察自己的感受'), findsOneWidget);
      expect(find.text('把感受说清楚再行动'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no delete button when onDelete is null', (tester) async {
      final section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '09:30',
            content: '测试',
            tags: [],
            rawLine: '- **09:30** 测试',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuickNoteTimeline(section: section)),
        ),
      );

      expect(find.byTooltip("更多操作"), findsNothing);
    });

    testWidgets('ReviewCard shows delete button via GenericSectionCard', (
      tester,
    ) async {
      final section = ReviewSection(
        title: '💡 觉察与迭代',
        contents: [
          TimelineContent(
            time: '10:00',
            text: '觉察内容',
            tags: ['#反思'],
            rawLine: '- **10:00** 觉察内容 #反思',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewCard(section: section, onTimelineDelete: (_) async {}),
          ),
        ),
      );

      expect(find.byTooltip("更多操作"), findsOneWidget);
      expect(find.byType(JournalSection), findsOneWidget);
    });

    testWidgets('ReviewCard delete passes rawLine with section reflection', (
      tester,
    ) async {
      String? passedRawLine;
      final section = ReviewSection(
        title: '💡 觉察与迭代',
        contents: [
          TimelineContent(
            time: '10:00',
            text: '觉察内容',
            tags: ['#反思'],
            rawLine: '- **10:00** 觉察内容 #反思',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewCard(
              section: section,
              onTimelineDelete: (rawLine) async {
                passedRawLine = rawLine;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip("更多操作"));
      await tester.pumpAndSettle();

      // Tap delete in action sheet
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Tap delete in confirm dialog
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(passedRawLine, '- **10:00** 觉察内容 #反思');
    });

    testWidgets('ReviewCard with SubSectionContent still shows delete button', (
      tester,
    ) async {
      // Replicates real markdown: "## 每日复盘" / "### 💡 觉察与迭代"
      final section = ReviewSection(
        title: '🧠 每日复盘',
        contents: [
          const SubSectionContent('💡 觉察与迭代'),
          TimelineContent(
            time: '10:00',
            text: '觉察内容',
            tags: ['#反思'],
            rawLine: '- **10:00** 觉察内容 #反思',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewCard(section: section, onTimelineDelete: (_) async {}),
          ),
        ),
      );

      expect(find.byTooltip("更多操作"), findsOneWidget);
    });

    testWidgets('action sheet shows edit and delete options', (tester) async {
      final section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '09:30',
            content: '测试',
            tags: [],
            rawLine: '- **09:30** 测试',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteTimeline(
              section: section,
              onDelete: (_) async {},
              onEdit: (_, _, _, _) async {},
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip("更多操作"));
      await tester.pumpAndSettle();

      expect(find.byType(FloraGlassSurface), findsOneWidget);
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      expect(
        tester.getSize(find.byType(FloraGlassSurface)).height,
        lessThan(200),
      );
    });

    testWidgets('edit reuses QuickCaptureScreen with pre-filled content', (
      tester,
    ) async {
      final section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '09:30',
            content: '原始内容',
            tags: ['#工作'],
            rawLine: '- **09:30** 原始内容 #工作',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteTimeline(
              section: section,
              onEdit: (_, _, _, _) async {},
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip("更多操作"));
      await tester.pumpAndSettle();

      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureScreen), findsOneWidget);
      expect(find.text('编辑记录'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '原始内容',
      );
      expect(find.text('今天 09:30'), findsOneWidget);
      expect(find.text('润色'), findsOneWidget);
      expect(find.text('AI 润色'), findsNothing);
    });

    testWidgets('edit mode strips # prefix from tags for TagPicker', (
      tester,
    ) async {
      final tagConfig = _polishTagConfig();
      List<String>? savedTags;

      await tester.pumpWidget(
        MaterialApp(
          home: QuickCaptureScreen(
            entryType: EntryType.quickNote,
            openedAt: DateTime(2026, 9, 11, 21, 18),
            initialContent: 'test',
            initialTime: '09:30',
            initialTags: const ['#亲子', '#亲子沟通'],
            tagConfig: tagConfig,
            onSave: (submission) async {
              savedTags = submission.tags;
            },
          ),
        ),
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedTags, isNotNull);
      expect(savedTags, isNot(contains('#亲子')));
      expect(savedTags, contains('亲子'));
    });

    testWidgets('edit mode removes a hidden tag only after explicit deletion', (
      tester,
    ) async {
      final tagConfig = _polishTagConfig();
      final tagSettings = TagSettings.fromTagConfig(tagConfig);
      tagSettings.domainSettings.first.topics.first.enabled = false;
      List<String>? savedTags;

      await tester.pumpWidget(
        MaterialApp(
          home: QuickCaptureScreen(
            entryType: EntryType.quickNote,
            openedAt: DateTime(2026, 9, 11, 21, 18),
            initialContent: 'test',
            initialTime: '09:30',
            initialTags: const ['#亲子', '#陪伴互动'],
            tagConfig: tagConfig,
            tagSettings: tagSettings,
            onSave: (submission) async => savedTags = submission.tags,
          ),
        ),
      );

      await tester.tap(find.text('标签'));
      await tester.pumpAndSettle();
      expect(find.text('陪伴互动 (已隐藏)'), findsWidgets);

      await tester.ensureVisible(_floraIcon(FloraIcons.close));
      await tester.pumpAndSettle();
      await tester.tap(_floraIcon(FloraIcons.close));
      await tester.pumpAndSettle();
      expect(find.text('陪伴互动 (已隐藏)'), findsNothing);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(savedTags, isNot(contains('陪伴互动')));
    });

    testWidgets('AI polish preserves hidden tags in edit mode', (tester) async {
      final tagConfig = _polishTagConfig();
      final tagSettings = TagSettings.fromTagConfig(tagConfig);
      tagSettings.domainSettings.first.topics.first.enabled = false;
      List<String>? savedTags;

      await tester.pumpWidget(
        MaterialApp(
          home: QuickCaptureScreen(
            entryType: EntryType.quickNote,
            openedAt: DateTime(2026, 9, 11, 21, 18),
            initialContent: '原始内容',
            initialTime: '09:30',
            initialTags: const ['#亲子', '#陪伴互动'],
            tagConfig: tagConfig,
            tagSettings: tagSettings,
            onPolish: (_, _) async =>
                const PolishResult(content: '润色内容', tags: ['工作', '任务执行']),
            onSave: (submission) async => savedTags = submission.tags,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('quick_capture_polish')));
      await tester.pumpAndSettle();
      expect(find.text('陪伴互动 (已隐藏)'), findsOneWidget);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(savedTags, containsAll(['工作', '任务执行', '陪伴互动']));
    });

    testWidgets('reflection edit reuses capture page and preserves rawLine', (
      tester,
    ) async {
      const rawLine = '- **10:15** 先停下来观察 #反思';
      String? savedRawLine;
      String? savedContent;
      List<String>? savedTags;
      String? savedTime;
      final section = ReviewSection(
        title: '觉察',
        contents: const [
          TimelineContent(
            time: '10:15',
            text: '先停下来观察',
            tags: ['#反思'],
            rawLine: rawLine,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewCard(
              section: section,
              onTimelineEdit: (rawLine, content, tags, time) async {
                savedRawLine = rawLine;
                savedContent = content;
                savedTags = tags;
                savedTime = time;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip("更多操作"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureScreen), findsOneWidget);
      expect(find.text('编辑记录'), findsOneWidget);
      expect(find.text('今天 10:15'), findsOneWidget);
      expect(find.text('10:15'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
        '觉察到了什么？',
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedRawLine, rawLine);
      expect(savedContent, '先停下来观察');
      expect(savedTags, const ['反思']);
      expect(savedTime, '10:15');
    });

    test('rebuildTimelineLine preserves original time for edit', () {
      const rawLine = '- **09:30** 旧内容 #旧标签';

      final replacement = rebuildTimelineLine(
        rawLine: rawLine,
        content: '新内容',
        tags: ['亲子', '亲子沟通'],
      );

      expect(replacement, '- **09:30** 新内容 #亲子 #亲子沟通');
    });

    test(
      'rebuildTimelineLine uses the edited time while preserving prefix and tags',
      () {
        const rawLine = '- **18:00** 旧内容 #旧标签';

        final replacement = rebuildTimelineLine(
          rawLine: rawLine,
          content: '新内容',
          tags: ['生活'],
          time: '08:05',
        );

        expect(replacement, '- **08:05** 新内容 #生活');
      },
    );

    test('rebuildTimelineLine preserves > prefix for happiness edit', () {
      const rawLine = '> **14:00** 旧小确幸 #生活';

      final replacement = rebuildTimelineLine(
        rawLine: rawLine,
        content: '新小确幸',
        tags: ['生活', '日常记录'],
      );

      expect(replacement, '> **14:00** 新小确幸 #生活 #日常记录');
    });
  });

  group('ApiClient replaceAnxiety', () {
    ApiClient makeClient(_CapturingClient client) {
      return ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: client,
      );
    }

    test('calls replace endpoint, not append endpoint', () async {
      final client = _CapturingClient();
      final api = makeClient(client);

      await api.replaceAnxiety(DateTime(2026, 6, 7), 'test');

      expect(client.lastUrl, contains('/api/v1/diary/anxiety/replace'));
    });

    test('sends date, content, and operationId in body', () async {
      final client = _CapturingClient();
      final api = makeClient(client);

      await api.replaceAnxiety(DateTime(2026, 6, 7), '四问内容');

      final body = jsonDecode(client.lastBody!) as Map<String, dynamic>;
      expect(body['date'], '2026-06-07');
      expect(body['content'], '四问内容');
      expect(body['operationId'], isA<String>());
      expect(body['operationId'], hasLength(36));
    });

    test('does NOT send tags (replace endpoint has no tags)', () async {
      final client = _CapturingClient();
      final api = makeClient(client);

      await api.replaceAnxiety(DateTime(2026, 6, 7), 'content');

      final body = jsonDecode(client.lastBody!) as Map<String, dynamic>;
      expect(body.containsKey('tags'), isFalse);
    });

    test('returns true on 200 response', () async {
      final client = _CapturingClient();
      final api = makeClient(client);

      final result = await api.replaceAnxiety(DateTime(2026, 6, 7), 'test');

      expect(result, isTrue);
    });
  });

  group('ApiClient append entries', () {
    test('appendQuickNote sends selected time when provided', () async {
      final client = _CapturingClient();
      final api = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: client,
      );

      await api.appendQuickNote(
        DateTime(2026, 6, 17),
        '测试',
        tags: ['工作'],
        time: '21:35',
      );

      final body = jsonDecode(client.lastBody!) as Map<String, dynamic>;
      expect(client.lastUrl, contains('/api/v1/diary/quick-note'));
      expect(body['date'], '2026-06-17');
      expect(body['content'], '测试');
      expect(body['tags'], ['工作']);
      expect(body['time'], '21:35');
      expect(body['operationId'], isA<String>());
    });
  });
}
