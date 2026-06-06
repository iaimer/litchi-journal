import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../theme/app_theme.dart';
import 'section_card.dart';

class QuickNoteTimeline extends StatelessWidget {
  final QuickNoteSection section;

  const QuickNoteTimeline({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    if (section.notes.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: section.title,
      accentColor: AppColors.primary,
      children: section.notes
          .map((note) => _QuickNoteRow(note: note))
          .toList(growable: false),
    );
  }
}

class _QuickNoteRow extends StatelessWidget {
  final QuickNoteItem note;

  const _QuickNoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Text(
                note.time,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: 2,
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(60),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.content,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (note.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        note.tags.join(' '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary.withAlpha(180),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
