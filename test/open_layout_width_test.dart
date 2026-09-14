import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/widgets/anxiety_card.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/quick_note_timeline.dart';

void main() {
  const viewportWidth = 393.0;

  group('开放式内容宽度', () {
    testWidgets('随手记正文和三点操作贴近页面右侧', (tester) async {
      await tester.binding.setSurfaceSize(const Size(viewportWidth, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const content = '早晨把今天最重要的事情写在纸上，然后按自己的节奏完成它。';
      final section = QuickNoteSection(
        title: '随手记',
        contents: const [],
        notes: const [
          QuickNoteItem(
            time: '08:25',
            content: content,
            tags: [],
            rawLine: '- **08:25** 早晨把今天最重要的事情写在纸上，然后按自己的节奏完成它。',
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

      final contentRightGap =
          viewportWidth - tester.getRect(find.text(content)).right;
      final moreRightGap =
          viewportWidth -
          tester
              .getRect(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is FloraIcon && widget.name == FloraIcons.more,
                ),
              )
              .right;

      expect(contentRightGap, lessThanOrEqualTo(24));
      expect(moreRightGap, lessThanOrEqualTo(24));
    });

    testWidgets('紧凑屏放大字体为 FAB 保留局部避让区', (tester) async {
      const viewport = Size(320, 640);
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const content = '一段需要在窄屏上换行的随手记内容，用来确认放大字体时不会被右下角入口遮挡。';
      final section = QuickNoteSection(
        title: '随手记',
        contents: const [],
        notes: const [
          QuickNoteItem(
            time: '08:25',
            content: content,
            tags: [],
            rawLine: '- **08:25** 一段需要在窄屏上换行的随手记内容',
          ),
        ],
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(1.3),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: QuickNoteTimeline(section: section, onDelete: (_) async {}),
            ),
          ),
        ),
      );

      final contentRightGap =
          viewport.width - tester.getRect(find.text(content)).right;

      expect(contentRightGap, greaterThanOrEqualTo(60));
    });

    testWidgets('焦虑回答不被固定右侧留白截短', (tester) async {
      await tester.binding.setSurfaceSize(const Size(viewportWidth, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const answer = '下午准备汇报时，我先整理了重点，再按顺序完成说明。';
      final section = AnxietySection(
        title: '焦虑时刻',
        contents: const [MarkdownContent('- 什么时候感到焦虑？\n> $answer')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AnxietyCard(section: section)),
        ),
      );

      final answerRightGap =
          viewportWidth - tester.getRect(find.text(answer)).right;

      expect(answerRightGap, lessThanOrEqualTo(24));
    });

    testWidgets('今日回顾和明日寄语正文使用可用宽度', (tester) async {
      await tester.binding.setSurfaceSize(const Size(viewportWidth, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const coachText = '今天先完成最重要的一件事，再处理其他零碎安排，并在过程中留意自己的节奏和注意力变化。';
      const tomorrowText = '明天给自己留出一段不被打扰的专注时间，先处理真正重要的事情，再安排其他零碎任务。';
      const markdown =
          '''
# 今天

### 🧠 人生教练
📌 模式识别
$coachText

### 🌙 明日寄语
- $tomorrowText
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(markdown: markdown, onGenerateCoach: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final coachRightGap =
          viewportWidth - tester.getRect(find.text(coachText)).right;
      final tomorrowRightGap =
          viewportWidth - tester.getRect(find.text(tomorrowText)).right;

      expect(coachRightGap, lessThanOrEqualTo(24));
      expect(tomorrowRightGap, lessThanOrEqualTo(24));
    });
  });
}
