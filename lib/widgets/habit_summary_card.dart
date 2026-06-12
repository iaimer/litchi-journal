import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import '../theme/app_theme.dart';

/// 温柔反馈卡。
/// 根据统计数据展示温和的文案，不制造压力。
class HabitSummaryCard extends StatelessWidget {
  final HabitStats stats;

  const HabitSummaryCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 12),
              child: Text('🌿', style: TextStyle(fontSize: 22)),
            ),
            Expanded(
              child: Text(
                stats.feedbackText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.7,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
