part of '../widget_test.dart';

AnxietySection _legacyAnxiety({
  required String title,
  required List<DiaryContent> contents,
}) {
  final body = contents
      .whereType<MarkdownContent>()
      .map((content) => content.text)
      .join('\n\n');
  return parseLegacyAnxietyFixture(body, title: title);
}

void registerAnxietyTests() {
  group('Legacy anxiety review context', () {
    test('coachAnswers returns four empty values for a blank template', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
>\u0020
- 当时我在担心什么？（具体到一句话）
>\u0020
- 我做了什么？
>\u0020
- 这个应对是帮我面对了，还是帮我躲开了？
>\u0020
''';

      final answers = _legacyAnxiety(
        title: '焦虑时刻',
        contents: [MarkdownContent(markdown)],
      ).coachAnswers;
      expect(answers, hasLength(4));
      expect(answers.every((a) => a.trim().isEmpty), isTrue);
    });

    test('coachAnswers returns filled values in standard question order', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
> 下午开会时
- 当时我在担心什么？（具体到一句话）
> 担心项目延期
- 我做了什么？
> 列了任务清单
- 这个应对是帮我面对了，还是帮我躲开了？
> 面对了
''';

      final answers = _legacyAnxiety(
        title: '焦虑时刻',
        contents: [MarkdownContent(markdown)],
      ).coachAnswers;
      expect(answers, ['下午开会时', '担心项目延期', '列了任务清单', '面对了']);
    });

    test('coachAnswers preserves gaps between real answers', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
> 下午开会
- 当时我在担心什么？（具体到一句话）
>\u0020
- 我做了什么？
> 做了深呼吸
- 这个应对是帮我面对了，还是帮我躲开了？
>\u0020
''';

      final answers = _legacyAnxiety(
        title: '焦虑时刻',
        contents: [MarkdownContent(markdown)],
      ).coachAnswers;
      expect(answers, ['下午开会', '', '做了深呼吸', '']);
    });

    test('coachAnswers takes the last non-empty duplicate answer '
        '- takes last non-empty answer', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
>\u0020
- 当时我在担心什么？（具体到一句话）
>\u0020
- 我做了什么？
>\u0020
- 这个应对是帮我面对了，还是帮我躲开了？
>\u0020
- 今天什么时候我感到焦虑/紧张？
> 午休的时候刷视频
- 当时我在担心什么？（具体到一句话）
> 任务安排有冲突
- 我做了什么？
> 优先处理截止日期近的
- 这个应对是帮我面对了，还是帮我躲开了？
> 继续拖到最后一刻，躲不开
''';

      final answers = _legacyAnxiety(
        title: '焦虑时刻',
        contents: [MarkdownContent(markdown)],
      ).coachAnswers;
      expect(answers, ['午休的时候刷视频', '任务安排有冲突', '优先处理截止日期近的', '继续拖到最后一刻，躲不开']);
    });

    test('coachAnswers uses the last non-empty answer for repeated questions '
        '- takes last non-empty', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
> 第一次回答
- 当时我在担心什么？（具体到一句话）
> 第一次担心
- 今天什么时候我感到焦虑/紧张？
> 第二次回答才是真的
- 当时我在担心什么？（具体到一句话）
>\u0020
''';

      final answers = _legacyAnxiety(
        title: '焦虑时刻',
        contents: [MarkdownContent(markdown)],
      ).coachAnswers;
      expect(answers, ['第二次回答才是真的', '第一次担心', '', '']);
    });

    test('coachAnswers preserves answers when only some questions repeat '
        'repeated, some not', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
>\u0020
- 今天什么时候我感到焦虑/紧张？
> 实际场景
- 当时我在担心什么？（具体到一句话）
> 实际担心
- 我做了什么？
> 什么都不做
''';

      final answers = _legacyAnxiety(
        title: '焦虑时刻',
        contents: [MarkdownContent(markdown)],
      ).coachAnswers;
      expect(answers, ['实际场景', '实际担心', '什么都不做', '']);
    });

    test(
      'coachAnswers does not let an empty duplicate overwrite an answer',
      () {
        const markdown = '''
- 今天什么时候我感到焦虑/紧张？
> 真实回答
- 当时我在担心什么？（具体到一句话）
> 真实担心
- 今天什么时候我感到焦虑/紧张？
>\u0020
- 当时我在担心什么？（具体到一句话）
>\u0020
''';

        final answers = _legacyAnxiety(
          title: '焦虑时刻',
          contents: [MarkdownContent(markdown)],
        ).coachAnswers;
        expect(answers, ['真实回答', '真实担心', '', '']);
      },
    );
  });

  testWidgets('AnxietyCard omits empty template', (WidgetTester tester) async {
    final section = _legacyAnxiety(
      title: '😰 焦虑时刻',
      contents: [
        MarkdownContent(
          '- 今天什么时候我感到焦虑/紧张？\n'
          '> \n'
          '- 当时我在担心什么？（具体到一句话）\n'
          '> \n'
          '- 我做了什么？\n'
          '> \n'
          '- 这个应对是帮我面对了，还是帮我躲开了？\n'
          '>',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnxietyCard(section: section)),
      ),
    );

    expect(find.text('今天什么时候我感到焦虑/紧张？'), findsNothing);
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox || widget.key is! ValueKey<String>) {
          return false;
        }
        return (widget.key! as ValueKey<String>).value.startsWith(
          'anxiety_question_marker_',
        );
      }),
      findsNothing,
    );
  });

  testWidgets('AnxietyCard hides template when real answers exist', (
    WidgetTester tester,
  ) async {
    final section = _legacyAnxiety(
      title: '😰 焦虑时刻',
      contents: [
        MarkdownContent(
          '- 今天什么时候我感到焦虑/紧张？\n'
          '> \n'
          '- 当时我在担心什么？（具体到一句话）\n'
          '> \n'
          '- 我做了什么？\n'
          '> \n'
          '- 这个应对是帮我面对了，还是帮我躲开了？\n'
          '> \n'
          '\n'
          '- 今天什么时候我感到焦虑/紧张？\n'
          '> 下午开会时\n'
          '- 当时我在担心什么？（具体到一句话）\n'
          '> 担心项目延期\n'
          '- 我做了什么？\n'
          '> \n'
          '- 这个应对是帮我面对了，还是帮我躲开了？\n'
          '> ',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnxietyCard(section: section)),
      ),
    );

    // Real Q&A visible
    expect(find.text('下午开会时'), findsOneWidget);
    expect(find.text('担心项目延期'), findsOneWidget);

    // Template questions should be hidden (both from template and from skipped Q&A)
    expect(find.byType(AnxietyCard), findsOneWidget);
    expect(find.byType(JournalSection), findsOneWidget);
    expect(find.byType(SectionCard), findsNothing);
    expect(find.text('今天什么时候我感到焦虑/紧张？'), findsOneWidget);
    expect(find.text('当时我在担心什么？（具体到一句话）'), findsOneWidget);
    expect(find.text('我做了什么？'), findsNothing);
  });

  testWidgets('AnxietyCard keeps saved answers open in dark mode', (
    WidgetTester tester,
  ) async {
    final section = _legacyAnxiety(
      title: '😰 焦虑时刻',
      contents: [
        MarkdownContent(
          '- 今天什么时候我感到焦虑/紧张？\n'
          '> 今天送小宝去幼儿园时，她迟到了。',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: AnxietyCard(section: section)),
      ),
    );

    const anxietyAccentColor = Color(0xFF8DB993);
    final answerFinder = find.ancestor(
      of: find.text('今天送小宝去幼儿园时，她迟到了。'),
      matching: find.byType(DecoratedBox),
    );
    expect(answerFinder, findsNothing);
    final marker = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('anxiety_question_marker_0')),
    );
    final markerDecoration = marker.decoration as BoxDecoration;
    expect(markerDecoration.color, anxietyAccentColor);
    expect(markerDecoration.shape, BoxShape.circle);
    expect(find.byType(MarkdownBody), findsNothing);
  });

  testWidgets('AnxietyCard renders one open group for all answers', (
    tester,
  ) async {
    final section = _legacyAnxiety(
      title: '😰 焦虑时刻',
      contents: [
        MarkdownContent(
          '- 什么时候感到焦虑？\n'
          '> 下午开会\n'
          '- 当时在担心什么？\n'
          '> 担心准备不充分',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnxietyCard(section: section)),
      ),
    );

    expect(find.byType(JournalSection), findsOneWidget);
    expect(find.byType(SectionCard), findsNothing);
    expect(find.text('😰 焦虑时刻'), findsNothing);
    expect(find.text('焦虑时刻'), findsOneWidget);
    expect(find.text('什么时候感到焦虑？'), findsOneWidget);
    expect(find.text('下午开会'), findsOneWidget);
    expect(find.text('当时在担心什么？'), findsOneWidget);
    expect(find.text('担心准备不充分'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('什么时候感到焦虑？')).dy,
      lessThan(tester.getTopLeft(find.text('下午开会')).dy),
    );
    expect(
      tester.getTopLeft(find.text('下午开会')).dy,
      lessThan(tester.getTopLeft(find.text('当时在担心什么？')).dy),
    );
    expect(
      tester.getTopLeft(find.text('当时在担心什么？')).dy,
      lessThan(tester.getTopLeft(find.text('担心准备不充分')).dy),
    );
    expect(
      find.byKey(const ValueKey<String>('anxiety_question_marker_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('anxiety_question_marker_1')),
      findsOneWidget,
    );
  });
}
