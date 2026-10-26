import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/screens/home_screen.dart';
import 'package:litchi_journal_flutter/widgets/anxiety_card.dart';
import 'support/anxiety_section_fixture.dart';

AnxietySection _section(String body) => parseLegacyAnxietyFixture(body);

void main() {
  test('保留旧编辑器未加引用符的后续回答行和段落', () {
    const body = '''
- 今天什么时候我感到焦虑/紧张？
> 上午开会
一直捏着手指
- 我是不是说错了？

想到可能说错话，又有些担心。
- 当时我在担心什么？（具体到一句话）
> 怕自己说不清楚
''';
    final section = _section(body);
    expect(
      section.answers.first.answer,
      '上午开会\n一直捏着手指\n- 我是不是说错了？\n\n想到可能说错话，又有些担心。',
    );
    expect(section.coachAnswers.first, section.answers.first.answer);
  });

  test('独立 Callout 不会并入尚未回答的问题或回顾上下文', () {
    final section = _section('''
- 我做了什么？
>

> [!note] 独立备忘
> 这是非问答的私人笔记
''');
    expect(section.coachAnswers[2], isEmpty);
    expect(section.isEmpty, isFalse);
    expect(
      buildCoachDiaryContext('''
## 😰 焦虑时刻
- 我做了什么？
>

> [!note] 独立备忘
> 这是非问答的私人笔记
'''),
      '今天暂无日记内容',
    );
  });

  testWidgets('旧正文、问答和独立 Callout 按原顺序显示', (tester) async {
    const question = '今天什么时候我感到焦虑/紧张？';
    final section = _section('''
开会前，我先记下一段背景。
- $question
> 上午开会

> [!note] 独立备忘
> 这是私人备注
''');

    expect(section.contents.map((content) => content.runtimeType), [
      AnxietyLegacyBody,
      AnxietyAnswer,
      AnxietyLegacyBody,
    ]);
    expect(section.coachAnswers.first, '上午开会');
    expect(section.coachAnswers, isNot(contains('这是私人备注')));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnxietyCard(section: section)),
      ),
    );
    final backgroundTop = tester.getTopLeft(find.text('开会前，我先记下一段背景。')).dy;
    final answerTop = tester.getTopLeft(find.text('上午开会')).dy;
    final noteTop = tester.getTopLeft(find.textContaining('这是私人备注')).dy;
    expect(backgroundTop, lessThan(answerTop));
    expect(answerTop, lessThan(noteTop));
  });

  testWidgets('未知旧问题仍可读，标准括号变体映射到同一回顾问题', (tester) async {
    final unknown = _section('- 还有什么让我紧张？\n> 临时改变安排');
    expect(unknown.isEmpty, isFalse);
    expect(unknown.answers.single.question, '还有什么让我紧张？');
    expect(unknown.coachAnswers, ['', '', '', '']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnxietyCard(section: unknown)),
      ),
    );
    expect(find.text('还有什么让我紧张？'), findsOneWidget);
    final unanswered = _section('- 我是不是说错了？');
    expect(unanswered.isEmpty, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnxietyCard(section: unanswered)),
      ),
    );
    expect(find.text('我是不是说错了？'), findsOneWidget);

    final variant = _section('- 当时我在担心什么？(具体到一句话）\n> 怕说不清楚');
    expect(
      variant.answers.single.standardQuestion,
      LegacyAnxietyQuestion.worry,
    );
    expect(variant.coachAnswers[1], '怕说不清楚');
  });

  test('领域问答拒绝空问题和空回答', () {
    expect(
      () => AnxietyAnswer(question: '我做了什么？', answer: '   '),
      throwsArgumentError,
    );
    expect(
      () => AnxietyAnswer(question: ' ', answer: '做了深呼吸'),
      throwsArgumentError,
    );
  });

  test('焦虑领域结果只保留一份不可变有序内容', () {
    final contents = <DiaryContent>[
      AnxietyAnswer(question: '我做了什么？', answer: '先停下来'),
      const AnxietyLegacyBody(MarkdownContent('之后我记下了原因。')),
    ];
    final section = AnxietySection(title: '焦虑时刻', contents: contents);
    contents.clear();

    expect(section.contents, hasLength(2));
    expect(section.answers.single.answer, '先停下来');
    expect(section.coachAnswers[2], '先停下来');
    expect(section.isEmpty, isFalse);
    expect(
      () => section.contents.add(
        const AnxietyLegacyBody(MarkdownContent('冲突状态')),
      ),
      throwsUnsupportedError,
    );
  });

  test('空 Callout 不会让纯模板焦虑章节变成真实内容', () {
    final section = _section('''
- 我做了什么？
>
> [!note]
''');
    expect(section.isEmpty, isTrue);
    expect(section.coachAnswers[2], isEmpty);
  });

  test('非问答旧正文保留段落和时间条目，不扩展回顾输入', () {
    const body = '先写一段。\n\n再写一段。\n- **09:00** 当时有些紧张\n';
    final section = _section(body);
    final fallback = section.contents
        .whereType<AnxietyLegacyBody>()
        .map((content) => content.content)
        .whereType<MarkdownContent>()
        .map((content) => content.text)
        .join('\n');
    expect(fallback, contains('先写一段。\n\n再写一段。'));
    expect(
      section.contents
          .whereType<AnxietyLegacyBody>()
          .map((content) => content.content)
          .whereType<TimelineContent>()
          .single
          .text,
      '当时有些紧张',
    );
    expect(_section('- **09:00** 当时有些紧张').isEmpty, isFalse);
    expect(buildCoachDiaryContext('## 焦虑时刻\n$body'), '今天暂无日记内容');
  });

  testWidgets('旧回答保留多行、重复记录，回顾取最后非空回答', (tester) async {
    const body = '''
- 今天什么时候我感到焦虑/紧张？
> 上午开会
> 一直捏着手指
- 今天什么时候我感到焦虑/紧张？
> 下午汇报
> 后来慢慢缓过来
- 今天什么时候我感到焦虑/紧张？
>
- 当时我在担心什么？（具体到一句话)
> 怕自己说不清楚
''';
    final section = _section(body);
    expect(section.isEmpty, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnxietyCard(section: section)),
      ),
    );
    expect(find.text('上午开会\n一直捏着手指'), findsOneWidget);
    expect(find.text('下午汇报\n后来慢慢缓过来'), findsOneWidget);
    expect(find.text('怕自己说不清楚'), findsOneWidget);
    final context = buildCoachDiaryContext('## 😰 焦虑时刻\n$body');
    expect(context, contains('下午汇报\n后来慢慢缓过来'));
    expect(context, contains('怕自己说不清楚'));
    expect(context, isNot(contains('上午开会')));
  });

  testWidgets('空四问无标题，未配对旧正文仍然可读且不扩大回顾输入', (tester) async {
    const empty =
        '- 今天什么时候我感到焦虑/紧张？\n>\n'
        '- 当时我在担心什么？（具体到一句话)\n>\n'
        '- 我做了什么？\n>\n'
        '- 这个应对是帮我面对了，还是帮我躲开了？\n>\n';
    expect(_section(empty).isEmpty, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnxietyCard(section: _section(empty))),
      ),
    );
    expect(find.text('焦虑时刻'), findsNothing);
    expect(buildCoachDiaryContext('## 焦虑时刻\n$empty'), '今天暂无日记内容');
    const oldBody = '当时还没想明白，只想先写下来。';
    expect(_section(oldBody).isEmpty, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnxietyCard(section: _section(oldBody))),
      ),
    );
    expect(find.text(oldBody), findsOneWidget);
    expect(buildCoachDiaryContext('## 焦虑时刻\n$oldBody'), '今天暂无日记内容');
  });
}
