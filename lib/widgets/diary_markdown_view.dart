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
  final Future<bool> Function(HabitStatus)? onHabitUpdate;
  final Future<void> Function(String sectionKey, String rawLine)?
      onEntryDelete;

  const DiaryMarkdownView({
    super.key,
    required this.markdown,
    this.onHabitUpdate,
    this.onEntryDelete,
  });

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
        return HabitCard(
          key: const ValueKey('habit_card'),
          section: section,
          onUpdate: onHabitUpdate ?? (_) async => true,
        );
      case QuickNoteSection():
        return QuickNoteTimeline(
          section: section,
          onDelete: onEntryDelete != null
              ? (note) => onEntryDelete!('quick_notes', note.rawLine)
              : null,
        );
      case AnxietySection():
        return AnxietyCard(section: section);
      case HappinessSection():
        return GenericSectionCard(
          section: section,
          onTimelineDelete: onEntryDelete != null
              ? (rawLine) => onEntryDelete!('happiness', rawLine)
              : null,
        );
      case ReviewSection():
        return ReviewCard(
          section: section,
          onTimelineDelete: onEntryDelete != null
              ? (rawLine) => onEntryDelete!('reflection', rawLine)
              : null,
        );
      default:
        return GenericSectionCard(section: section);
    }
  }
}
