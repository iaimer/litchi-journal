import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../models/tag_config.dart';
import '../services/api_client.dart';
import '../services/markdown_parser.dart';
import 'anxiety_card.dart';
import 'generic_section_card.dart';
import 'habit_card.dart';
import 'image_section_card.dart';
import 'quick_note_timeline.dart';
import 'review_card.dart';

class DiaryMarkdownView extends StatelessWidget {
  final String markdown;
  final Future<bool> Function(HabitStatus)? onHabitUpdate;
  final Future<void> Function(String sectionKey, String rawLine)?
      onEntryDelete;
  final Future<void> Function(String sectionKey, String rawLine,
      String content, List<String> tags)? onEntryEdit;
  final TagConfig? tagConfig;
  final ApiClient? apiClient;
  final DateTime? date;
  final VoidCallback? onGenerateCoach;
  final bool generatingCoach;

  const DiaryMarkdownView({
    super.key,
    required this.markdown,
    this.onHabitUpdate,
    this.onEntryDelete,
    this.onEntryEdit,
    this.tagConfig,
    this.apiClient,
    this.date,
    this.onGenerateCoach,
    this.generatingCoach = false,
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
      if (section.isEmpty && (section is! CoachSection || onGenerateCoach == null)) continue;
      widgets.add(_buildSection(section, context));
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildSection(DiarySection section, BuildContext context) {
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
          onEdit: onEntryEdit != null
              ? (note, content, tags) => onEntryEdit!(
                  'quick_notes', note.rawLine, content, tags)
              : null,
          tagConfig: tagConfig,
        );
      case AnxietySection():
        return AnxietyCard(section: section);
      case HappinessSection():
        return GenericSectionCard(
          section: section,
          onTimelineDelete: onEntryDelete != null
              ? (rawLine) => onEntryDelete!('happiness', rawLine)
              : null,
          onTimelineEdit: onEntryEdit != null
              ? (rawLine, content, tags) => onEntryEdit!(
                  'happiness', rawLine, content, tags)
              : null,
          tagConfig: tagConfig,
        );
      case ReviewSection():
        return ReviewCard(
          section: section,
          onTimelineDelete: onEntryDelete != null
              ? (rawLine) => onEntryDelete!('reflection', rawLine)
              : null,
          onTimelineEdit: onEntryEdit != null
              ? (rawLine, content, tags) => onEntryEdit!(
                  'reflection', rawLine, content, tags)
              : null,
          tagConfig: tagConfig,
        );
      case CoachSection():
        return _buildCoachCard(section, context);
      case MediaSection():
        if (apiClient != null && date != null) {
          return ImageSectionCard(
            section: section,
            apiClient: apiClient!,
            date: date!,
            onDeleteImage: onEntryDelete != null
                ? (rawLine) => onEntryDelete!('images', rawLine)
                : null,
          );
        }
        return GenericSectionCard(section: section);
      default:
        return GenericSectionCard(section: section);
    }
  }

  Widget _buildCoachCard(CoachSection section, BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = section.contents.any(
      (c) => c is MarkdownContent && c.text.trim().isNotEmpty,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    section.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onGenerateCoach != null)
                  TextButton.icon(
                    onPressed:
                        generatingCoach ? null : onGenerateCoach,
                    icon: generatingCoach
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5),
                          )
                        : const Text('🧠', style: TextStyle(fontSize: 14)),
                    label: Text(
                      generatingCoach
                          ? '生成中...'
                          : (hasContent ? '重新生成' : '生成今日反馈'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
            if (!hasContent && onGenerateCoach == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '暂无教练反馈',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
