import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/theme/diary_reading_style.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/journal_section.dart';
import 'package:litchi_journal_flutter/widgets/tag_color_helper.dart';

const _tags = ['#技术', '#实现能力', '#问题分析'];
const _body = '今天让 AI 做了一个插件，测试 OCR 后再记录 token。';

void main() {
  testWidgets('长短标签不同条目保持相同的时间轴和正文列', (tester) async {
    tester.view.physicalSize = const Size(393, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const bodies = ['短标签记录', '超长旧标签记录', '无标签记录', '多个标签记录'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                JournalTimelineRow(
                  time: '08:00',
                  content: bodies[0],
                  tags: ['#生活'],
                  accentColor: Colors.red,
                  tagConfig: null,
                  isFirst: true,
                ),
                JournalTimelineRow(
                  time: '08:10',
                  content: bodies[1],
                  tags: ['#这是很长很长很长很长很长很长很长很长很长很长很长很长的旧标签'],
                  accentColor: Colors.red,
                  tagConfig: null,
                ),
                JournalTimelineRow(
                  time: '08:15',
                  content: bodies[2],
                  tags: [],
                  accentColor: Colors.red,
                  tagConfig: null,
                ),
                JournalTimelineRow(
                  time: '08:20',
                  content: bodies[3],
                  tags: ['#技术', '#实现能力', '#问题分析'],
                  accentColor: Colors.red,
                  tagConfig: null,
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rows = find.byType(JournalTimelineRow);
    final railLefts = <double>[];
    final bodyLefts = <double>[];
    for (var i = 0; i < bodies.length; i++) {
      final row = rows.at(i);
      railLefts.add(
        tester
            .getRect(
              find.descendant(of: row, matching: find.byType(ColoredBox)),
            )
            .left,
      );
      bodyLefts.add(tester.getRect(find.text(bodies[i])).left);
    }
    expect(railLefts[1], closeTo(railLefts[0], 0.1));
    expect(railLefts[2], closeTo(railLefts[0], 0.1));
    expect(railLefts[3], closeTo(railLefts[0], 0.1));
    expect(bodyLefts[1], closeTo(bodyLefts[0], 0.1));
    expect(bodyLefts[2], closeTo(bodyLefts[0], 0.1));
    expect(bodyLefts[3], closeTo(bodyLefts[0], 0.1));
  });

  testWidgets('粗体和系统字距覆写使用与标签绘制相同的测量结果', (tester) async {
    const tag = '#iiiiiiii';
    late double measuredWidth;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(boldText: true, letterSpacingOverride: 2),
          child: Builder(
            builder: (context) {
              measuredWidth = readingTagWidth(context, [tag], 12);
              return Scaffold(
                body: SizedBox(
                  width: measuredWidth,
                  child: const TagChipList(
                    tags: [tag],
                    tagConfig: null,
                    singleLine: true,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(tag), matching: find.byType(RichText)),
    );
    expect(paragraph.text.style!.fontWeight, FontWeight.bold);
    expect(paragraph.text.style!.letterSpacing, 2);
    expect(
      paragraph.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(paragraph.size.width + 0.1),
    );
    expect(tester.widget<Text>(find.text(tag)).overflow, isNull);
  });

  testWidgets('截图中的三个标签在放大字体后仍完整显示在一行', (tester) async {
    tester.view.physicalSize = const Size(393, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: JournalTimelineRow(
              time: '18:27',
              content: _body,
              tags: _tags,
              accentColor: Colors.red,
              tagConfig: null,
              trailing: SizedBox.square(dimension: 48),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final topEdges = _tags.map((tag) => tester.getRect(find.text(tag)).top);
    expect(topEdges.toSet(), hasLength(1));
    for (final tag in _tags) {
      final text = tester.widget<Text>(find.text(tag));
      expect(text.style!.fontSize, lessThanOrEqualTo(12));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    }
    expect(tester.widget<Text>(find.text(_body)).textAlign, TextAlign.justify);
  });

  for (final busy in [false, true]) {
    for (final width in [320.0, 360.0, 393.0, 432.0]) {
      for (final scale in [1.0, 1.3, 2.0, 4.0]) {
        for (final fontSize in [14, 16, 18]) {
          testWidgets(
            '$width dp / $scale 倍 / $fontSize sp / 加载=$busy 标签与操作正常',
            (tester) async {
              var pressed = 0;
              tester.view.physicalSize = Size(width, 1500);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              await tester.pumpWidget(
                MaterialApp(
                  theme: DiaryReadingStyle.applyTo(
                    AppTheme.light,
                    fontSize: fontSize,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: JournalTimelineRow(
                        time: '18:27',
                        content: _body,
                        tags: _tags,
                        accentColor: Colors.red,
                        tagConfig: null,
                        isLast: true,
                        trailing: JournalEntryActionSlot(
                          alignToTags: true,
                          busy: busy,
                          onPressed: busy ? null : () => pressed++,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              await tester.pump();
              final labels = _tags
                  .map((tag) => tester.getRect(find.text(tag)))
                  .toList();
              expect(labels.map((rect) => rect.top).toSet(), hasLength(1));
              for (final tag in _tags) {
                final text = tester.widget<Text>(find.text(tag));
                expect(text.style!.fontSize, inInclusiveRange(10, 12));
                expect(text.overflow, isNot(TextOverflow.ellipsis));
                expect(text.textScaler, TextScaler.noScaling);
              }
              final row = tester.getRect(find.byType(JournalTimelineRow));
              expect(labels.last.right, lessThanOrEqualTo(row.right + 0.5));
              expect(
                tester.widget<Text>(find.text(_body)).textAlign,
                TextAlign.justify,
              );
              final action = find.byType(JournalEntryActionSlot);
              final actionRect = tester.getRect(action);
              expect(actionRect.width, 48);
              expect(actionRect.height, greaterThanOrEqualTo(48));
              final graphic = tester.getRect(
                busy
                    ? find.byType(CircularProgressIndicator)
                    : find.byType(FloraIcon),
              );
              expect(graphic.left, greaterThanOrEqualTo(actionRect.left));
              expect(graphic.right, lessThanOrEqualTo(actionRect.right));
              if (!busy && width == 393 && scale == 1.3 && fontSize == 16) {
                await tester.tapAt(actionRect.center);
                expect(pressed, 1);
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  for (final photo in [false, true]) {
    for (final busy in [false, true]) {
      testWidgets('照片=$photo 加载=$busy 操作图标对齐单行标签', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 393,
                child: JournalTimelineRow(
                  time: '18:27',
                  content: _body,
                  tags: _tags,
                  accentColor: Colors.red,
                  tagConfig: null,
                  isLast: true,
                  attachment: photo ? const SizedBox(height: 80) : null,
                  trailing: JournalEntryActionSlot(
                    alignToTags: true,
                    attachmentAboveTags: photo,
                    busy: busy,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final tags = tester.getRect(find.byType(TagChipList));
        final graphic = tester.getRect(
          busy
              ? find.byType(CircularProgressIndicator)
              : find.byType(FloraIcon),
        );
        expect(graphic.center.dy, closeTo(tags.center.dy, 0.3));
        expect(tester.getSize(find.byType(JournalEntryActionSlot)).width, 48);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('超长标签省略显示并保留完整语义', (tester) async {
    const longTag = '#这是很长很长很长很长很长很长很长很长很长的旧标签';
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: JournalTimelineRow(
              time: '18:27',
              content: _body,
              tags: [longTag, '#生活'],
              accentColor: Colors.red,
              tagConfig: null,
              trailing: JournalEntryActionSlot(alignToTags: true, busy: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<Text>(find.text(longTag)).overflow,
      TextOverflow.ellipsis,
    );
    expect(find.bySemanticsLabel(longTag), findsOneWidget);
    expect(
      tester.getRect(find.text(longTag)).top,
      closeTo(tester.getRect(find.text('#生活')).top, 0.1),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final mode in [(false, false), (true, true), (true, false)]) {
    testWidgets('三种记录只读=${mode.$1} 占位=${mode.$2} 正文与标签使用一致排版', (tester) async {
      const markdown = '''
## ✍️ 随手记 & 灵感
- **09:00** 随手记正文 #技术 #实现能力 #问题分析

## ✨ 每日小确幸
> **09:10** 小确幸正文 #技术 #实现能力 #问题分析

### 💡 觉察与迭代
- **09:20** 觉察正文 #技术 #实现能力 #问题分析
''';
      tester.view.physicalSize = const Size(393, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DiaryMarkdownView(
                markdown: markdown,
                readOnly: mode.$1,
                showTodayPlaceholders: mode.$2,
                onEntryDelete: mode.$1 ? null : (_, _) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(JournalTimelineRow), findsNWidgets(3));
      for (final element in find.byType(JournalTimelineRow).evaluate()) {
        final row = find.byElementPredicate(
          (candidate) => candidate == element,
        );
        final body = (element.widget as JournalTimelineRow).content;
        expect(
          tester
              .widget<Text>(find.descendant(of: row, matching: find.text(body)))
              .textAlign,
          TextAlign.justify,
        );
        final labels = _tags.map(
          (tag) => tester.getRect(
            find.descendant(of: row, matching: find.text(tag)),
          ),
        );
        expect(labels.map((rect) => rect.top).toSet(), hasLength(1));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
