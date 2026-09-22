import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/services/entry_line_builder.dart';
import 'package:litchi_journal_flutter/services/markdown_parser.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/tag_color_helper.dart';

const _firstParagraph = '第一自然段。';
const _secondParagraph = '第二自然段。';
const _tag = '#生活';

String _markdownFor(String section, String entry) =>
    '''
# 2026年9月22日 星期二

$section
$entry
''';

void main() {
  group('多段时间记录', () {
    test('编辑多段记录时保留可解析的整块格式', () {
      final replacement = rebuildTimelineLine(
        rawLine: '- **09:00** 原正文\n\n  原第二段。 #旧标签',
        content: '新第一段。\n\n新第二段。',
        tags: const ['生活'],
      );

      expect(replacement, '- **09:00** 新第一段。\n  \n  新第二段。 #生活');
    });

    test('Parser 将随手记的多段正文、标签和 rawLine 保持为一条记录', () {
      const entry = '- **09:00** $_firstParagraph\n\n$_secondParagraph $_tag';
      final document = const MarkdownParser().parse(
        _markdownFor('## ✍️ 随手记 & 灵感', entry),
      );

      final note = document.sections
          .whereType<QuickNoteSection>()
          .single
          .notes
          .single;
      expect(note.content, '$_firstParagraph\n\n$_secondParagraph');
      expect(note.tags, [_tag]);
      expect(note.rawLine, entry);
    });

    test('Parser 将觉察和小确幸的多段正文、标签和 rawLine 保持为一条记录', () {
      for (final section in const ['### 💡 觉察与迭代', '## ✨ 每日小确幸']) {
        const entry = '- **09:00** $_firstParagraph\n\n$_secondParagraph $_tag';
        final document = const MarkdownParser().parse(
          _markdownFor(section, entry),
        );
        final timeline = document.sections
            .expand((item) => item.contents)
            .whereType<TimelineContent>()
            .single;

        expect(timeline.text, '$_firstParagraph\n\n$_secondParagraph');
        expect(timeline.tags, [_tag]);
        expect(timeline.rawLine, entry);
      }
    });

    for (final scenario in const [
      (
        name: '随手记',
        section: '## ✍️ 随手记 & 灵感',
        prefix: '- **09:00**',
        continuation: '  ',
      ),
      (
        name: '觉察',
        section: '### 💡 觉察与迭代',
        prefix: '- **09:00**',
        continuation: '  ',
      ),
      (
        name: '小确幸',
        section: '## ✨ 每日小确幸',
        prefix: '> **09:00**',
        continuation: '> ',
      ),
    ]) {
      testWidgets('${scenario.name} 的操作入口和标签位于最后一段正文之后', (tester) async {
        final entry =
            '${scenario.prefix} $_firstParagraph\n${scenario.continuation}\n${scenario.continuation}$_secondParagraph $_tag';
        await tester.binding.setSurfaceSize(const Size(600, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiaryMarkdownView(
                  markdown: _markdownFor(scenario.section, entry),
                  onEntryDelete: (_, _) async {},
                  onEntryEdit: (_, _, _, _, _) async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final contentFinder = find.text(
          '$_firstParagraph\n\n$_secondParagraph',
        );
        expect(contentFinder, findsOneWidget);
        final tagsFinder = find.byType(TagChipList);
        final actionFinder = find.byTooltip('更多操作');
        expect(tagsFinder, findsOneWidget);
        expect(actionFinder, findsOneWidget);
        expect(
          tester.getTopLeft(tagsFinder).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(contentFinder).dy),
        );
        expect(
          tester.getTopLeft(actionFinder).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(contentFinder).dy),
        );
      });
    }
  });
}
