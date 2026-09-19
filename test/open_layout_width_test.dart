import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/widgets/anxiety_card.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/generic_section_card.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/journal_section.dart';
import 'package:litchi_journal_flutter/widgets/quick_note_timeline.dart';

void main() {
  const viewportWidth = 393.0;

  Finder moreIconFinder() {
    return find.byWidgetPredicate(
      (widget) => widget is FloraIcon && widget.name == FloraIcons.more,
    );
  }

  Future<void> expectTagAndMenuAligned(
    WidgetTester tester, {
    required Widget child,
    required String tag,
    TextScaler? textScaler,
  }) async {
    final app = MaterialApp(home: Scaffold(body: child));
    await tester.pumpWidget(
      textScaler == null
          ? app
          : MediaQuery(
              data: MediaQueryData(textScaler: textScaler),
              child: app,
            ),
    );
    await tester.pumpAndSettle();

    final tagRect = tester.getRect(find.text(tag));
    final moreRect = tester.getRect(moreIconFinder());
    expect(
      (tagRect.center.dy - moreRect.center.dy).abs(),
      lessThanOrEqualTo(2),
    );
    expect(find.byType(IconButton), findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
  }

  Future<void> expectNoTagMenuCentered(
    WidgetTester tester, {
    required Widget child,
  }) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();

    final buttonRect = tester.getRect(find.byType(IconButton));
    final moreRect = tester.getRect(moreIconFinder());
    expect(moreRect.center.dy, closeTo(buttonRect.center.dy, 0.5));
    expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
  }

  Future<void> expectBusyMenuKeepsPosition(
    WidgetTester tester, {
    required Widget Function(Future<void> Function()) buildChild,
    required String tag,
  }) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildChild(() => pending.future))),
    );
    await tester.pumpAndSettle();

    final tagRect = tester.getRect(find.text(tag));
    final menuRect = tester.getRect(moreIconFinder());
    await tester.tap(moreIconFinder());
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pump();

    final indicatorRect = tester.getRect(
      find.byType(CircularProgressIndicator),
    );
    expect(
      (tagRect.center.dy - indicatorRect.center.dy).abs(),
      lessThanOrEqualTo(2),
    );
    expect(
      (menuRect.center.dy - indicatorRect.center.dy).abs(),
      lessThanOrEqualTo(0.5),
    );

    pending.complete();
    await tester.pumpAndSettle();
  }

  group('标签与操作菜单对齐', () {
    testWidgets('随手记、觉察和小确幸标签与三点菜单对齐', (tester) async {
      await tester.binding.setSurfaceSize(const Size(viewportWidth, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const tags = ['#生活', '#记录', '#工作'];
      await expectTagAndMenuAligned(
        tester,
        child: QuickNoteTimeline(
          section: QuickNoteSection(
            title: '随手记',
            contents: const [],
            notes: [
              QuickNoteItem(
                time: '08:25',
                content: '早晨记录',
                tags: tags,
                rawLine: '- **08:25** 早晨记录 #生活 #记录 #工作',
              ),
            ],
          ),
          onDelete: (_) async {},
        ),
        tag: '#生活',
      );

      await expectTagAndMenuAligned(
        tester,
        child: GenericSectionCard(
          section: ReviewSection(
            title: '觉察',
            contents: const [
              TimelineContent(
                time: '10:00',
                text: '觉察记录',
                tags: tags,
                rawLine: '- **10:00** 觉察记录 #生活 #记录 #工作',
              ),
            ],
          ),
          onTimelineDelete: (_) async {},
        ),
        tag: '#生活',
      );

      await expectTagAndMenuAligned(
        tester,
        child: GenericSectionCard(
          section: HappinessSection(
            title: '小确幸',
            contents: const [
              TimelineContent(
                time: '14:00',
                text: '小确幸记录',
                tags: tags,
                rawLine: '> **14:00** 小确幸记录 #生活 #记录 #工作',
              ),
            ],
          ),
          onTimelineDelete: (_) async {},
        ),
        tag: '#生活',
      );
    });

    testWidgets('1.3 倍字体下标签与三点菜单仍保持对齐', (tester) async {
      await tester.binding.setSurfaceSize(const Size(viewportWidth, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const tags = ['#生活', '#记录', '#工作'];
      const textScaler = TextScaler.linear(1.3);

      await expectTagAndMenuAligned(
        tester,
        child: QuickNoteTimeline(
          section: QuickNoteSection(
            title: '随手记',
            contents: const [],
            notes: [
              QuickNoteItem(
                time: '08:25',
                content: '放大字体下的随手记记录',
                tags: tags,
                rawLine: '- **08:25** 放大字体下的随手记记录 #生活 #记录 #工作',
              ),
            ],
          ),
          onDelete: (_) async {},
        ),
        tag: '#生活',
        textScaler: textScaler,
      );

      await expectTagAndMenuAligned(
        tester,
        child: GenericSectionCard(
          section: ReviewSection(
            title: '觉察',
            contents: const [
              TimelineContent(
                time: '10:00',
                text: '放大字体下的觉察记录',
                tags: tags,
                rawLine: '- **10:00** 放大字体下的觉察记录 #生活 #记录 #工作',
              ),
            ],
          ),
          onTimelineDelete: (_) async {},
        ),
        tag: '#生活',
        textScaler: textScaler,
      );

      await expectTagAndMenuAligned(
        tester,
        child: GenericSectionCard(
          section: HappinessSection(
            title: '小确幸',
            contents: const [
              TimelineContent(
                time: '14:00',
                text: '放大字体下的小确幸记录',
                tags: tags,
                rawLine: '> **14:00** 放大字体下的小确幸记录 #生活 #记录 #工作',
              ),
            ],
          ),
          onTimelineDelete: (_) async {},
        ),
        tag: '#生活',
        textScaler: textScaler,
      );

      expect(find.text('#记录'), findsOneWidget);
      expect(find.text('#工作'), findsOneWidget);
    });

    testWidgets('窄屏放大字体下长标签换行后仍与菜单首行对齐', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const tags = ['#生活标签特别长', '#第二个标签很长', '#第三个标签很长'];
      const textScaler = TextScaler.linear(1.3);

      Future<void> check(Widget child, String firstTag) async {
        await expectTagAndMenuAligned(
          tester,
          child: child,
          tag: firstTag,
          textScaler: textScaler,
        );
        expect(find.text('#第二个标签很长'), findsOneWidget);
        expect(find.text('#第三个标签很长'), findsOneWidget);
        expect(
          tester.getRect(find.text('#第二个标签很长')).top,
          greaterThan(tester.getRect(find.text(firstTag)).bottom),
        );
        expect(tester.takeException(), isNull);
      }

      await check(
        QuickNoteTimeline(
          section: QuickNoteSection(
            title: '随手记',
            contents: const [],
            notes: [
              QuickNoteItem(
                time: '08:25',
                content: '窄屏下的随手记记录',
                tags: tags,
                rawLine: '- **08:25** 窄屏下的随手记记录 #生活标签特别长',
              ),
            ],
          ),
          onDelete: (_) async {},
        ),
        '#生活标签特别长',
      );

      await check(
        GenericSectionCard(
          section: ReviewSection(
            title: '觉察',
            contents: const [
              TimelineContent(
                time: '10:00',
                text: '窄屏下的觉察记录',
                tags: tags,
                rawLine: '- **10:00** 窄屏下的觉察记录 #生活标签特别长',
              ),
            ],
          ),
          onTimelineDelete: (_) async {},
        ),
        '#生活标签特别长',
      );

      await check(
        GenericSectionCard(
          section: HappinessSection(
            title: '小确幸',
            contents: const [
              TimelineContent(
                time: '14:00',
                text: '窄屏下的小确幸记录',
                tags: tags,
                rawLine: '> **14:00** 窄屏下的小确幸记录 #生活标签特别长',
              ),
            ],
          ),
          onTimelineDelete: (_) async {},
        ),
        '#生活标签特别长',
      );
    });

    testWidgets('无标签时三类条目的三点菜单在热区内保持居中', (tester) async {
      await tester.binding.setSurfaceSize(const Size(viewportWidth, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await expectNoTagMenuCentered(
        tester,
        child: QuickNoteTimeline(
          section: const QuickNoteSection(
            title: '随手记',
            contents: [],
            notes: [
              QuickNoteItem(
                time: '08:25',
                content: '没有标签的记录',
                tags: [],
                rawLine: '- **08:25** 没有标签的记录',
              ),
            ],
          ),
          onDelete: (_) async {},
        ),
      );
      await expectNoTagMenuCentered(
        tester,
        child: GenericSectionCard(
          section: const ReviewSection(
            title: '觉察',
            contents: [
              TimelineContent(
                time: '10:00',
                text: '没有标签的觉察',
                tags: [],
                rawLine: '- **10:00** 没有标签的觉察',
              ),
            ],
          ),
          onTimelineDelete: (_) async {},
        ),
      );
      await expectNoTagMenuCentered(
        tester,
        child: GenericSectionCard(
          section: const HappinessSection(
            title: '小确幸',
            contents: [
              TimelineContent(
                time: '14:00',
                text: '没有标签的小确幸',
                tags: [],
                rawLine: '> **14:00** 没有标签的小确幸',
              ),
            ],
          ),
          onTimelineDelete: (_) async {},
        ),
      );
    });

    testWidgets('三类条目删除等待期间加载指示器保持菜单位置', (tester) async {
      await tester.binding.setSurfaceSize(const Size(viewportWidth, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await expectBusyMenuKeepsPosition(
        tester,
        tag: '#生活',
        buildChild: (onDelete) => QuickNoteTimeline(
          section: const QuickNoteSection(
            title: '随手记',
            contents: [],
            notes: [
              QuickNoteItem(
                time: '08:25',
                content: '等待删除的随手记',
                tags: ['#生活'],
                rawLine: '- **08:25** 等待删除的随手记 #生活',
              ),
            ],
          ),
          onDelete: (_) => onDelete(),
        ),
      );
      await expectBusyMenuKeepsPosition(
        tester,
        tag: '#生活',
        buildChild: (onDelete) => GenericSectionCard(
          section: const ReviewSection(
            title: '觉察',
            contents: [
              TimelineContent(
                time: '10:00',
                text: '等待删除的觉察',
                tags: ['#生活'],
                rawLine: '- **10:00** 等待删除的觉察 #生活',
              ),
            ],
          ),
          onTimelineDelete: (_) => onDelete(),
        ),
      );
      await expectBusyMenuKeepsPosition(
        tester,
        tag: '#生活',
        buildChild: (onDelete) => GenericSectionCard(
          section: const HappinessSection(
            title: '小确幸',
            contents: [
              TimelineContent(
                time: '14:00',
                text: '等待删除的小确幸',
                tags: ['#生活'],
                rawLine: '> **14:00** 等待删除的小确幸 #生活',
              ),
            ],
          ),
          onTimelineDelete: (_) => onDelete(),
        ),
      );
    });
  });

  group('开放式内容宽度', () {
    Finder timelineRows() => find.byType(JournalTimelineRow);

    Finder timelineRailAt(int index) {
      return find.descendant(
        of: timelineRows().at(index),
        matching: find.byType(ColoredBox),
      );
    }

    Finder timelineNodeAt(int index) {
      return find.descendant(
        of: timelineRows().at(index),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle;
        }),
      );
    }

    testWidgets('时间轴覆盖每条记录并在末条底部结束', (tester) async {
      await tester.binding.setSurfaceSize(const Size(viewportWidth, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final section = QuickNoteSection(
        title: '随手记',
        contents: const [],
        notes: [
          QuickNoteItem(
            time: '08:25',
            content: '第一条记录',
            tags: ['#第一条'],
            rawLine: '- **08:25** 第一条记录 #第一条',
          ),
          QuickNoteItem(
            time: '12:10',
            content: '第二条记录',
            tags: ['#第二条'],
            rawLine: '- **12:10** 第二条记录 #第二条',
          ),
          QuickNoteItem(
            time: '21:26',
            content: '最后一条记录',
            tags: ['#末条'],
            rawLine: '- **21:26** 最后一条记录 #末条',
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
      await tester.pumpAndSettle();

      expect(timelineRows(), findsNWidgets(3));
      for (var index = 0; index < 3; index++) {
        expect(timelineRailAt(index), findsOneWidget);
        expect(timelineNodeAt(index), findsOneWidget);
      }

      final firstRow = tester.getRect(timelineRows().at(0));
      final secondRow = tester.getRect(timelineRows().at(1));
      final lastRow = tester.getRect(timelineRows().at(2));
      final firstRail = tester.getRect(timelineRailAt(0));
      final secondRail = tester.getRect(timelineRailAt(1));
      final lastRail = tester.getRect(timelineRailAt(2));
      final firstNode = tester.getRect(timelineNodeAt(0));
      final lastTag = tester.getRect(find.text('#末条'));

      expect(firstRail.top, closeTo(firstNode.center.dy, 0.5));
      expect(firstRail.bottom, closeTo(secondRail.top, 0.5));
      expect(secondRail.top, closeTo(secondRow.top, 0.5));
      expect(secondRail.bottom, closeTo(lastRail.top, 0.5));
      expect(lastRail.top, closeTo(lastRow.top, 0.5));
      expect(lastRail.bottom, closeTo(lastRow.bottom, 0.5));
      expect(lastRail.bottom, greaterThan(lastTag.bottom));
      expect(firstRail.bottom, closeTo(firstRow.bottom, 0.5));
      expect(tester.getSize(timelineRailAt(0)).width, closeTo(1, 0.001));
      expect(tester.getSize(timelineRailAt(1)).width, closeTo(1, 0.001));
      expect(tester.getSize(timelineRailAt(2)).width, closeTo(1, 0.001));
      expect(tester.getSize(timelineNodeAt(0)), const Size(8, 8));
      expect(tester.getSize(timelineNodeAt(1)), const Size(8, 8));
      expect(tester.getSize(timelineNodeAt(2)), const Size(8, 8));
    });

    testWidgets('两条记录的时间轴在记录边界无缝连接', (tester) async {
      await tester.binding.setSurfaceSize(const Size(viewportWidth, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '08:25',
            content: '第一条记录',
            tags: ['#第一条'],
            rawLine: '- **08:25** 第一条记录 #第一条',
          ),
          QuickNoteItem(
            time: '21:26',
            content: '最后一条记录',
            tags: ['#末条'],
            rawLine: '- **21:26** 最后一条记录 #末条',
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
      await tester.pumpAndSettle();

      final firstRow = tester.getRect(timelineRows().at(0));
      final lastRow = tester.getRect(timelineRows().at(1));
      final firstRail = tester.getRect(timelineRailAt(0));
      final lastRail = tester.getRect(timelineRailAt(1));
      final firstNode = tester.getRect(timelineNodeAt(0));

      expect(firstRail.top, closeTo(firstNode.center.dy, 0.5));
      expect(firstRail.bottom, closeTo(firstRow.bottom, 0.5));
      expect(lastRail.top, closeTo(lastRow.top, 0.5));
      expect(lastRail.bottom, closeTo(lastRow.bottom, 0.5));
      expect(firstRail.bottom, closeTo(lastRail.top, 0.5));
    });

    testWidgets('单条记录的时间轴从圆点延伸到条目底部', (tester) async {
      await tester.binding.setSurfaceSize(const Size(viewportWidth, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '08:25',
            content: '单条记录',
            tags: ['#记录'],
            rawLine: '- **08:25** 单条记录 #记录',
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
      await tester.pumpAndSettle();

      final row = tester.getRect(timelineRows().at(0));
      final rail = tester.getRect(timelineRailAt(0));
      final node = tester.getRect(timelineNodeAt(0));
      expect(rail.top, closeTo(node.center.dy, 0.5));
      expect(rail.bottom, closeTo(row.bottom, 0.5));
    });

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
          viewportWidth - tester.getRect(moreIconFinder()).right;

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
