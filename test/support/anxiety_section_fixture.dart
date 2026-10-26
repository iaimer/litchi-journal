import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/services/markdown_parser.dart';

AnxietySection parseLegacyAnxietyFixture(
  String body, {
  String title = '😰 焦虑时刻',
}) =>
    const MarkdownParser().parse('## $title\n$body').sections.single
        as AnxietySection;
