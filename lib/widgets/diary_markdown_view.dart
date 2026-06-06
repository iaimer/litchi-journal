import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../services/markdown_parser.dart';
import 'anxiety_card.dart';
import 'generic_section_card.dart';
import 'habit_card.dart';
import 'quick_note_timeline.dart';
import 'review_card.dart';

class DiaryMarkdownView extends StatelessWidget {
  final String markdown;

  const DiaryMarkdownView({super.key, required this.markdown});

  @override
  Widget build(BuildContext context) {
    final document = const MarkdownParser().parse(markdown);
    if (document.isEmpty) return const SizedBox.shrink();

    final widgets = <Widget>[];
    final preamble = GenericDiarySection(
      title: '',
      contents: document.preamble,
    );

    if (!preamble.isEmpty) {
      widgets.add(GenericSectionCard(section: preamble));
    }

    for (final section in document.sections) {
      if (section.isEmpty) continue;
      widgets.add(_buildSection(section));
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildSection(DiarySection section) {
    switch (section) {
      case HabitSection():
        return HabitCard(section: section);
      case QuickNoteSection():
        return QuickNoteTimeline(section: section);
      case AnxietySection():
        return AnxietyCard(section: section);
      case ReviewSection():
        return ReviewCard(section: section);
      default:
        return GenericSectionCard(section: section);
    }
  }
}
