import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/theme/diary_reading_style.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/journal_section.dart';
import 'package:litchi_journal_flutter/widgets/tag_color_helper.dart';

const _diary = '''
## ✍️ 随手记 & 灵感
- **08:10** 随手记正文 #生活

### 💡 觉察与迭代
- **09:20** 觉察正文 #情绪

## ✨ 每日小确幸
> **10:30** 小确幸正文 #生活
''';

Future<void> _mount(
  WidgetTester tester,
  String markdown, {
  bool dark = false,
  double scale = 1,
  int readingSize = 16,
  bool readOnly = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: DiaryReadingStyle.applyTo(
        dark ? AppTheme.dark : AppTheme.light,
        fontSize: readingSize,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: const Size(320, 800),
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: DiaryMarkdownView(
            markdown: markdown,
            readOnly: readOnly,
            onEntryDelete: (_, _) async {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectTimelineSpacing(WidgetTester tester) {
  for (final element in find.byType(JournalTimelineRow).evaluate()) {
    final row = find.byElementPredicate((candidate) => candidate == element);
    final content = (element.widget as JournalTimelineRow).content;
    final tags = find.descendant(of: row, matching: find.byType(TagChipList));
    final rail = find.descendant(of: row, matching: find.byType(ColoredBox));
    expect(
      tester.getRect(tags).top - tester.getRect(find.text(content)).bottom,
      closeTo(12, .5),
    );
    expect(
      tester.getRect(rail).bottom,
      closeTo(tester.getRect(tags).bottom, .5),
    );
  }
}

void main() {
  testWidgets('320dp 4倍字上下排布时时间与时间轴节点不重叠', (tester) async {
    await _mount(tester, _diary, scale: 4);
    final row = find.byType(JournalTimelineRow).first;
    final node = find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(
      tester.getRect(node).top,
      greaterThanOrEqualTo(tester.getRect(find.text('08:10')).bottom),
    );
    _expectTimelineSpacing(tester);
  });

  testWidgets('三个记录模块都显示原时间，并采用同一时间轴布局', (tester) async {
    await _mount(tester, _diary);
    for (final time in ['08:10', '09:20', '10:30']) {
      expect(find.text(time), findsOneWidget);
    }
    expect(find.byType(JournalTimelineRow), findsNWidgets(3));
    final times = [
      '08:10',
      '09:20',
      '10:30',
    ].map((time) => tester.getRect(find.text(time)));
    expect(times.map((rect) => rect.left).toSet(), hasLength(1));
    expect(times.map((rect) => rect.width).toSet(), hasLength(1));
    _expectTimelineSpacing(tester);
  });

  for (final heading in ['### 💡 觉察与迭代', '## ✨ 每日小确幸']) {
    testWidgets('$heading 320dp 4倍字相邻记录的竖线连续且不遮挡时间', (tester) async {
      await _mount(
        tester,
        '$heading\n- **08:10** 第一条 #生活\n- **09:20** 第二条 #情绪',
        scale: 4,
      );
      final rows = find.byType(JournalTimelineRow);
      final rails = [
        for (var index = 0; index < 2; index++)
          find.descendant(
            of: rows.at(index),
            matching: find.byType(ColoredBox),
          ),
      ];
      expect(
        tester.getRect(rails.first).bottom,
        closeTo(tester.getRect(rails.last).top, .5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$heading 保留无时间旧正文并在正文、Callout和小标题处断开', (tester) async {
      await _mount(tester, '''
$heading
- **09:00** 第一条
- **08:00** 第二条

---
没有记录时间的旧正文

- **10:00** 第三条
> [!note] 旧引用
> 引用正文

- **11:00** 第四条
### 补充
- **12:00** 第五条
''');
      final rows = tester
          .widgetList<JournalTimelineRow>(find.byType(JournalTimelineRow))
          .toList();
      expect(rows.map((row) => row.time), [
        '09:00',
        '08:00',
        '10:00',
        '11:00',
        '12:00',
      ]);
      expect(rows.map((row) => (row.isFirst, row.isLast)), [
        (true, false),
        (false, true),
        (true, true),
        (true, true),
        (true, true),
      ]);
      expect(find.text('没有记录时间的旧正文', findRichText: true), findsOneWidget);
      expect(find.text('引用正文', findRichText: true), findsOneWidget);
      expect(find.text('补充'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$heading 只有无时间旧正文时仍可阅读', (tester) async {
      await _mount(tester, '$heading\n\n没有时间的记录');
      expect(find.text('没有时间的记录', findRichText: true), findsOneWidget);
      expect(find.byType(JournalTimelineRow), findsNothing);
    });
  }

  for (final dark in [false, true]) {
    for (final size in [14, 16, 18]) {
      for (final scale in [1.0, 1.3, 2.0, 3.0]) {
        testWidgets('320dp 三模块 dark=$dark 字号=$size 缩放=$scale', (tester) async {
          await _mount(
            tester,
            _diary,
            dark: dark,
            readingSize: size,
            scale: scale,
            readOnly: false,
          );
          expect(find.byType(JournalTimelineRow), findsNWidgets(3));
          for (final time in ['08:10', '09:20', '10:30']) {
            expect(find.text(time), findsOneWidget);
          }
          _expectTimelineSpacing(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
