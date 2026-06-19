import 'package:flutter/material.dart';

import 'flora_icon.dart';

import '../models/habit_stats.dart';

/// 温柔反馈卡。
/// 展示稳定习惯总结和温和改进建议。
class HabitSummaryCard extends StatelessWidget {
  final HabitStats stats;

  const HabitSummaryCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSummary = stats.feedbackSummary.isNotEmpty;
    final hasSuggestion = stats.feedbackSuggestion.isNotEmpty;

    if (!hasSummary && !hasSuggestion) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasSummary)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 12),
                    child: FloraIcon(FloraIcons.candidateSprout, size: 22),
                  ),
                  Expanded(
                    child: Text(
                      stats.feedbackSummary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            if (hasSummary && hasSuggestion) const SizedBox(height: 8),
            if (hasSuggestion)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 12),
                    child: FloraIcon(FloraIcons.coach, size: 22),
                  ),
                  Expanded(
                    child: Text(
                      stats.feedbackSuggestion,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
