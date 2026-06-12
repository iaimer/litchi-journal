import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import '../theme/app_theme.dart';

/// 最近 7 天节奏谱。
/// 行：习惯；列：7 天。用圆点表示完成情况。
class HabitRhythmGrid extends StatelessWidget {
  final List<HabitDayRecord> days;
  final List<HabitItemStats> items;

  const HabitRhythmGrid({
    super.key,
    required this.days,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty || items.isEmpty) return const SizedBox.shrink();

    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final today = DateTime.now();
    final isToday = (int index) {
      if (index >= days.length) return false;
      final d = days[index];
      return d.date.year == today.year &&
          d.date.month == today.month &&
          d.date.day == today.day;
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 星期标题行
            Row(
              children: [
                const SizedBox(width: 80),
                ...List.generate(days.length, (i) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        weekdays[days[i].date.weekday - 1],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isToday(i) ? FontWeight.w700 : FontWeight.w400,
                          color: isToday(i)
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            // 习惯行
            ...items.map((item) => _buildHabitRow(item, isToday)),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitRow(
      HabitItemStats item, bool Function(int) isToday) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              item.title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...List.generate(item.recent7Values.length, (i) {
            final done = item.type == HabitStatType.boolean
                ? item.recent7Values[i] == 1
                : item.recent7Values[i] > 0;

            return Expanded(
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? (isToday(i)
                            ? AppColors.primary
                            : AppColors.success.withValues(alpha: 0.7))
                        : AppColors.border,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
