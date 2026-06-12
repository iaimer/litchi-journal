import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import '../theme/app_theme.dart';

/// 分组习惯卡。
/// 将习惯按「照顾身体」和「照顾成长」分组显示。
class HabitGroupCard extends StatelessWidget {
  final String groupLabel;
  final List<HabitItemStats> items;

  const HabitGroupCard({
    super.key,
    required this.groupLabel,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...items.map((item) => _buildItemRow(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, HabitItemStats item) {
    final theme = Theme.of(context);
    final bool isNumeric = item.type == HabitStatType.numeric;

    // 统计文本
    String statText;
    String? subText;
    if (isNumeric) {
      statText =
          '${item.averageValue.toStringAsFixed(0)}${_unit(item.key)}/天';
    } else {
      statText = '${item.completedDays}/${item.totalDays} 天';
      if (item.completedDays == 0) {
        subText = '慢慢来，能开始就是节奏';
      } else if (item.currentStreak >= 3) {
        subText = '连续 ${item.currentStreak} 天';
      } else if (item.completedDays >= 5) {
        subText = '这项最稳定';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // 习惯名 + 7 天小点阵
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.icon, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      statText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                if (subText != null) ...[
                  const SizedBox(height: 2),
                  Text(subText, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: 6),
                // 7天小点阵（使用习惯主题色）
                Row(
                  children: List.generate(item.recent7Values.length, (i) {
                    final done = isNumeric
                        ? item.recent7Values[i] > 0
                        : item.recent7Values[i] == 1;
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? item.color : AppColors.border,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _unit(String key) {
    switch (key) {
      case 'water':
        return 'mL';
      case 'steps':
        return '步';
      default:
        return '';
    }
  }
}
