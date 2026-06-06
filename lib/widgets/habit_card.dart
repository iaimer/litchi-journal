import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../theme/app_theme.dart';
import 'section_card.dart';

class HabitCard extends StatelessWidget {
  final HabitSection section;

  const HabitCard({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    if (section.habits.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: section.title,
      accentColor: AppColors.primary,
      children: section.habits
          .map((habit) => _HabitRow(habit: habit))
          .toList(growable: false),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final HabitItem habit;

  const _HabitRow({required this.habit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (habit.checkable) ...[
            Icon(
              habit.checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: habit.checked ? Colors.green : theme.disabledColor,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              habit.label,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
