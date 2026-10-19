import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/theme/diary_reading_style.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/journal_section.dart';
import 'package:litchi_journal_flutter/widgets/tag_color_helper.dart';

Widget _host(
  Widget child, {
  double scale = 1,
  int readingSize = 16,
  bool dark = false,
}) => MaterialApp(
  theme: DiaryReadingStyle.applyTo(
    dark ? AppTheme.dark : AppTheme.light,
    fontSize: readingSize,
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

Map<String, TextStyle> _visibleTextStyles(WidgetTester tester) {
  final styles = <String, TextStyle>{};
  void visit(InlineSpan span, TextStyle inherited) {
    final effective = inherited.merge(span.style);
    if (span is! TextSpan) return;
    final text = span.text?.trim();
    if (text != null && text.isNotEmpty) styles[text] = effective;
    for (final child in span.children ?? <InlineSpan>[]) {
      visit(child, effective);
    }
  }

  for (final text in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  )) {
    if (text.textSpan != null) {
      visit(text.textSpan!, text.style ?? const TextStyle());
    }
  }
  return styles;
}

const _formattedDiary = '''
## 自定义章节
#### 标题普通 **标题加粗** *标题斜体* [标题链接](https://test.local)

正文普通 **正文加粗** *正文斜体* [正文链接](https://test.local)

**外层粗体 *内层斜体***

*外层斜体 **内层粗体***
''';

void main() {
  for (final dark in [false, true]) {
    for (final size in [14, 16, 18]) {
      testWidgets('深色=$dark／$size档 标题强调仍为18sp，正文与粗斜体继承当前样式', (tester) async {
        await tester.pumpWidget(
          _host(
            const DiaryMarkdownView(markdown: _formattedDiary),
            readingSize: size,
            dark: dark,
          ),
        );
        final styles = _visibleTextStyles(tester);
        for (final text in ['标题普通', '标题加粗', '标题斜体', '标题链接']) {
          expect(styles[text]?.fontSize, 18, reason: text);
          expect(styles[text]?.height, 1.35, reason: text);
        }
        for (final text in ['正文普通', '正文加粗', '正文斜体', '正文链接', '内层斜体', '内层粗体']) {
          expect(styles[text]?.fontSize, size, reason: text);
          expect(styles[text]?.height, 1.6, reason: text);
        }
        for (final text in ['内层斜体', '内层粗体']) {
          expect(styles[text]?.fontWeight, FontWeight.bold, reason: text);
          expect(styles[text]?.fontStyle, FontStyle.italic, reason: text);
        }
        expect(styles['标题斜体']?.fontWeight, FontWeight.w600);
        expect(styles['正文加粗']?.fontWeight, FontWeight.bold);
        expect(styles['正文斜体']?.fontStyle, FontStyle.italic);
        final primary =
            (dark ? AppTheme.dark : AppTheme.light).colorScheme.primary;
        expect(styles['标题链接']?.color, primary);
        expect(styles['正文链接']?.color, primary);
      });
    }
  }

  for (final dark in [false, true]) {
    for (final busy in [false, true]) {
      testWidgets('深色=$dark／生成中=$busy 回顾按钮继承状态颜色，仍为16sp', (tester) async {
        var presses = 0;
        await tester.pumpWidget(
          _host(
            DiaryMarkdownView(
              markdown: '### 人生教练\n模式识别\n回顾正文',
              onGenerateCoach: () => presses++,
              generatingCoach: busy,
            ),
            dark: dark,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final label = find.text(busy ? '生成中...' : '更新回顾');
        final rich = tester.widget<RichText>(
          find.descendant(of: label, matching: find.byType(RichText)),
        );
        final expected = DefaultTextStyle.of(tester.element(label)).style;
        expect(rich.text.style?.color, expected.color);
        expect(rich.text.style?.fontSize, 16);
        final button = tester.widget<TextButton>(
          find
              .ancestor(
                of: label,
                matching: find.byWidgetPredicate(
                  (widget) => widget is TextButton,
                ),
              )
              .first,
        );
        expect(button.onPressed == null, busy);
        if (!busy) {
          await tester.tap(label);
          await tester.pump();
          expect(presses, 1);
        }
      });
    }
  }

  testWidgets('4倍系统字体时三点图标保持18dp，操作区可点击且至少48dp', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      _host(
        JournalEntryActionSlot(
          alignToTags: true,
          busy: false,
          onPressed: () => presses++,
        ),
        scale: 4,
      ),
    );
    final icon = tester.getRect(find.byType(FloraIcon));
    final slot = tester.getRect(find.byType(JournalEntryActionSlot));
    expect(icon.size, const Size(18, 18));
    expect(slot.width, greaterThanOrEqualTo(48));
    expect(slot.height, greaterThanOrEqualTo(48));
    expect(icon.bottom, lessThanOrEqualTo(slot.bottom));
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pump();
    expect(presses, 1);
  });

  for (final scale in [1.0, 2.0, 3.0, 4.0]) {
    for (final attachment in [false, true]) {
      for (final busy in [false, true]) {
        testWidgets('$scale倍字体／照片=$attachment／加载=$busy 图形不受操作区挤压', (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(
              JournalEntryActionSlot(
                alignToTags: true,
                attachmentAboveTags: attachment,
                busy: busy,
                onPressed: () {},
              ),
              scale: scale,
            ),
          );
          final graphic = tester.getRect(
            busy
                ? find.byType(CircularProgressIndicator)
                : find.byType(FloraIcon),
          );
          final slot = tester.getRect(find.byType(JournalEntryActionSlot));
          final size = busy ? 14.0 : 18.0;
          expect(graphic.width, closeTo(size, .01));
          expect(graphic.height, closeTo(size, .01));
          expect(graphic.top, greaterThanOrEqualTo(slot.top));
          expect(graphic.bottom, lessThanOrEqualTo(slot.bottom));
          expect(slot.height, greaterThanOrEqualTo(48));
          if (scale <= 2 || attachment) expect(slot.height, 48);
        });
      }
    }
  }

  for (final scale in [1.0, 4.0]) {
    for (final attachment in [false, true]) {
      for (final busy in [false, true]) {
        testWidgets('320dp／$scale倍／照片=$attachment／加载=$busy 对齐实际首行标签', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _host(
              JournalListEntryRow(
                content: '正文',
                tags: const ['#生活'],
                accentColor: TodayRainbow.quickNote,
                tagConfig: null,
                attachment: attachment ? const SizedBox(height: 120) : null,
                trailing: JournalEntryActionSlot(
                  alignToTags: true,
                  attachmentAboveTags: attachment,
                  busy: busy,
                  onPressed: () {},
                ),
              ),
              scale: scale,
            ),
          );
          final graphic = tester.getRect(
            busy
                ? find.byType(CircularProgressIndicator)
                : find.byType(FloraIcon),
          );
          final tags = tester.getRect(find.byType(TagChipList));
          // 字体行框按像素取整会带来约 0.1dp 差异。
          expect(graphic.center.dy, closeTo(tags.center.dy, .25));
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('$scale倍／照片=$attachment 时间轴仍连续且末条跟随标签收尾', (tester) async {
        await tester.pumpWidget(
          _host(
            Column(
              children: [
                for (var i = 0; i < 3; i++)
                  JournalTimelineRow(
                    time: '12:00',
                    content: '正文',
                    tags: const ['#生活', '#第二个较长标签'],
                    accentColor: TodayRainbow.quickNote,
                    tagConfig: null,
                    isFirst: i == 0,
                    isLast: i == 2,
                    attachment: attachment ? const SizedBox(height: 120) : null,
                    trailing: JournalEntryActionSlot(
                      alignToTags: true,
                      attachmentAboveTags: attachment,
                      busy: false,
                      onPressed: () {},
                    ),
                  ),
              ],
            ),
            scale: scale,
          ),
        );
        await tester.pump();
        final rails = find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox &&
              widget.color == TodayRainbow.quickNote.withAlpha(88),
        );
        expect(rails, findsNWidgets(3));
        expect(
          tester.getRect(rails.at(0)).bottom,
          closeTo(tester.getRect(rails.at(1)).top, .1),
        );
        expect(
          tester.getRect(rails.at(1)).bottom,
          closeTo(tester.getRect(rails.at(2)).top, .1),
        );
        expect(
          tester.getRect(rails.last).bottom,
          closeTo(tester.getRect(find.byType(TagChipList).last).bottom, .1),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
