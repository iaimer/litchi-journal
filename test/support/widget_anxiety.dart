part of '../widget_test.dart';

void registerAnxietyTests() {
  group('AnxietyComposer', () {
    final date = DateTime(2026, 6, 7);

    Widget buildComposer({
      required Future<void> Function(String, List<String>) onSubmit,
      Future<String> Function(String)? onPolish,
      VoidCallback? onClose,
      DateTime? date,
      DraftRepository? draftRepository,
      List<String>? initialAnswers,
      bool isEdit = false,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AnxietyComposer(
            onSubmit: onSubmit,
            onPolish: onPolish,
            onClose: onClose,
            date: date,
            draftRepository: draftRepository,
            initialAnswers: initialAnswers,
            isEdit: isEdit,
          ),
        ),
      );
    }

    testWidgets('shows first question initially', (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      expect(find.text('今天什么时候我感到焦虑/紧张？'), findsOneWidget);
      expect(find.text('1/4'), findsOneWidget);
    });

    testWidgets('uses larger input areas for standalone capture', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, 5);

      await tester.tap(find.text('下一步'));
      await tester.pump();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, 4);
    });

    testWidgets('dark mode keeps answer field readable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildComposer(onSubmit: (_, _) async {}, theme: AppTheme.dark),
      );

      // 输入框使用主题默认样式（inputDecorationTheme），确保可交互
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);
      expect(textField.decoration?.hintText, isNotEmpty);
    });

    testWidgets('next button advances to second question', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(find.text('下一步'));
      await tester.pump();

      expect(find.text('当时我在担心什么？（具体到一句话）'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);
    });

    testWidgets('skip button advances to next step', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is TextButton &&
              w.child is Text &&
              (w.child as Text).data == '跳过',
        ),
      );
      await tester.pump();

      expect(find.text('当时我在担心什么？（具体到一句话）'), findsOneWidget);
    });

    testWidgets('shows save on last step', (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();

      expect(find.text('保存'), findsOneWidget);
      expect(find.text('下一步'), findsNothing);
    });

    testWidgets('submits formatted content with empty tags', (
      WidgetTester tester,
    ) async {
      String? submittedContent;
      List<String>? submittedTags;
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (content, tags) async {
            submittedContent = content;
            submittedTags = tags;
          },
        ),
      );

      await tester.enterText(find.byType(TextField), '下午开会时');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '担心项目延期');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '列出优先级');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '帮我面对了');
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(submittedTags, isEmpty);
      expect(
        submittedContent,
        '- 今天什么时候我感到焦虑/紧张？\n> 下午开会时\n'
        '- 当时我在担心什么？（具体到一句话）\n> 担心项目延期\n'
        '- 我做了什么？\n> 列出优先级\n'
        '- 这个应对是帮我面对了，还是帮我躲开了？\n> 帮我面对了',
      );
    });

    testWidgets('resets to step 1 on successful submit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('1/4'), findsOneWidget);
    });

    testWidgets('preserves answers on failed submit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {
            throw Exception('fail');
          },
        ),
      );

      await tester.enterText(find.byType(TextField), '下午开会时');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(find.text('4/4'), findsOneWidget);
    });

    testWidgets('close button calls onClose', (WidgetTester tester) async {
      bool closed = false;
      await tester.pumpWidget(
        buildComposer(onSubmit: (_, _) async {}, onClose: () => closed = true),
      );

      await tester.tap(find.text('关闭'));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('restores draft step and answers on init', (
      WidgetTester tester,
    ) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);
      await repo.saveAnxietyDraft(
        date: date,
        step: 2,
        answers: ['a1', 'a2', '', ''],
      );

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          draftRepository: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3/4'), findsOneWidget);
    });

    testWidgets('saves draft after next tap', (WidgetTester tester) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          draftRepository: repo,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      final draft = await repo.loadAnxietyDraft(date: date);
      expect(draft, isNotNull);
      expect(draft!.step, 1);
      expect(draft.answers[0], 'hello');
    });

    testWidgets('clears draft on successful submit', (
      WidgetTester tester,
    ) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);
      await repo.saveAnxietyDraft(
        date: date,
        step: 3,
        answers: ['a1', '', '', ''],
      );

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          draftRepository: repo,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final draft = await repo.loadAnxietyDraft(date: date);
      expect(draft, isNull);
    });

    testWidgets('keeps draft on failed submit', (WidgetTester tester) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {
            throw Exception('fail');
          },
          date: date,
          draftRepository: repo,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final draft = await repo.loadAnxietyDraft(date: date);
      expect(draft, isNotNull);
    });

    testWidgets('back button hidden on step 1', (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      expect(find.text('上一步'), findsNothing);
    });

    testWidgets('back button visible on step 2', (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(find.text('下一步'));
      await tester.pump();

      expect(find.text('上一步'), findsOneWidget);
    });

    testWidgets('back button returns to previous step', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('上一步'));
      await tester.pump();

      expect(find.text('1/4'), findsOneWidget);
    });

    testWidgets('back button shows previous answer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('上一步'));
      await tester.pump();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, 'hello');
    });

    testWidgets('modified answer after back is submitted', (
      WidgetTester tester,
    ) async {
      String? submitted;
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (content, _) async {
            submitted = content;
          },
        ),
      );

      await tester.enterText(find.byType(TextField), 'old');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('上一步'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(submitted, contains('new'));
      expect(submitted, isNot(contains('old')));
    });

    testWidgets('polish button disabled when answer empty', (tester) async {
      await tester.pumpWidget(
        buildComposer(onSubmit: (_, _) async {}, onPolish: (_) async => 'ok'),
      );

      expect(find.text('润色当前回答'), findsOneWidget);

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '润色当前回答'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('polish button calls onPolish when answer not empty', (
      tester,
    ) async {
      String? polished;

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          onPolish: (content) async {
            polished = content;
            return '润色后';
          },
        ),
      );

      await tester.enterText(find.byType(TextField), '原始回答');
      await tester.pump();

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '润色当前回答'),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
      await tester.pump();

      expect(polished, '原始回答');
    });

    testWidgets(
      'polish success updates only current TextField and saves draft',
      (tester) async {
        final storage = _TestStorage();
        final repo = DraftRepository(storage: storage);

        await tester.pumpWidget(
          buildComposer(
            onSubmit: (_, _) async {},
            onPolish: (_) async => '润色后的回答',
            draftRepository: repo,
            date: DateTime(2026, 6, 7),
          ),
        );

        await tester.enterText(find.byType(TextField), '原始回答');
        await tester.pump();

        await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
        await tester.pump();

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          '润色后的回答',
        );

        final draft = await repo.loadAnxietyDraft(date: DateTime(2026, 6, 7));
        expect(draft, isNotNull);
        expect(draft!.answers[0], '润色后的回答');
      },
    );

    testWidgets('polish failure preserves original answer', (tester) async {
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          onPolish: (_) async => throw Exception('网络错误'),
        ),
      );

      await tester.enterText(find.byType(TextField), '原始回答');
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '原始回答',
      );
      expect(find.text('润色服务暂不可用，请稍后重试'), findsOneWidget);
    });

    testWidgets('polish does not affect other answers in AnxietyComposer', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          onPolish: (_) async => '第一问答润色',
        ),
      );

      await tester.enterText(find.byType(TextField), 'Q1 原始回答');
      await tester.pump();

      await tester.tap(find.text('下一步'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Q2 原始回答');
      await tester.pump();

      await tester.tap(find.text('上一步'));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '第一问答润色',
      );

      await tester.tap(find.text('下一步'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Q2 原始回答',
      );
    });

    testWidgets('submit format unchanged after polish', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (content, _) async => submitted = content,
          onPolish: (_) async => '润色后的问答',
        ),
      );

      await tester.enterText(find.byType(TextField), '原始');
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
      await tester.pump();

      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(submitted, isNotNull);
      expect(submitted, contains('- 今天什么时候我感到焦虑/紧张？'));
      expect(submitted, contains('> 润色后的问答'));
      expect(submitted, contains('- 当时我在担心什么？'));
    });

    testWidgets('TextField auto-expands from larger minimum to 8 lines', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, 5);
      expect(textField.maxLines, 8);
      expect(textField.keyboardType, TextInputType.multiline);
    });

    test('parseAnswers extracts 4 empty strings from template', () {
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

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, hasLength(4));
      expect(answers.every((a) => a.trim().isEmpty), isTrue);
    });

    test('parseAnswers extracts 4 real answers', () {
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

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, ['下午开会时', '担心项目延期', '列了任务清单', '面对了']);
    });

    test('parseAnswers handles empty and real answers mixed', () {
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

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, ['下午开会', '', '做了深呼吸', '']);
    });

    test('parseAnswers handles template + real duplicate questions '
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

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, ['午休的时候刷视频', '任务安排有冲突', '优先处理截止日期近的', '继续拖到最后一刻，躲不开']);
    });

    test('parseAnswers handles repeated questions with multiple real answers '
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

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, ['第二次回答才是真的', '第一次担心', '', '']);
    });

    test('parseAnswers handles partial duplicate - some questions '
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

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, ['实际场景', '实际担心', '什么都不做', '']);
    });

    test(
      'parseAnswers empty answer does not overwrite previous real answer',
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

        final answers = AnxietyComposer.parseAnswers(markdown);
        expect(answers, ['真实回答', '真实担心', '', '']);
      },
    );

    testWidgets('edit mode prefills initialAnswers', (tester) async {
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          initialAnswers: ['a1', 'a2', 'a3', 'a4'],
          isEdit: true,
        ),
      );

      await tester.pump();

      expect(find.text('编辑今日焦虑记录'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'a1',
      );

      // Move to step 2
      await tester.tap(find.text('下一步'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'a2',
      );
    });

    testWidgets('edit mode draft takes priority over initialAnswers', (
      tester,
    ) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);

      await repo.saveAnxietyDraft(
        date: DateTime(2026, 6, 7),
        step: 0,
        answers: ['draft1', 'draft2', '', ''],
      );

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          initialAnswers: ['init1', 'init2', 'init3', 'init4'],
          isEdit: true,
          draftRepository: repo,
          date: DateTime(2026, 6, 7),
        ),
      );

      await tester.pump();

      // Draft restored — should be on step 1 with draft content
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'draft1',
      );
    });

    testWidgets(
      'edit mode polish current answer still works with initialAnswers',
      (tester) async {
        await tester.pumpWidget(
          buildComposer(
            onSubmit: (_, _) async {},
            onPolish: (_) async => '润色后',
            initialAnswers: ['a1', 'a2', '', ''],
            isEdit: true,
          ),
        );

        await tester.pump();

        await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
        await tester.pump();

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          '润色后',
        );
      },
    );
  });

  testWidgets('AnxietyCard shows template when no real answers', (
    WidgetTester tester,
  ) async {
    final section = AnxietySection(
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

    expect(find.text('今天什么时候我感到焦虑/紧张？'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox || widget.key is! ValueKey<String>) {
          return false;
        }
        return (widget.key! as ValueKey<String>).value.startsWith(
          'anxiety_question_marker_',
        );
      }),
      findsNWidgets(4),
    );
  });

  testWidgets('AnxietyCard hides template when real answers exist', (
    WidgetTester tester,
  ) async {
    final section = AnxietySection(
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
    final section = AnxietySection(
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

    const anxietyAccentColor = Color(0xFFFFD43B);
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
    final section = AnxietySection(
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
