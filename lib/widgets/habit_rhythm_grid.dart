import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import '../theme/app_theme.dart';

/// 最近 7 天节奏谱。
/// 行：习惯（icon + 名称）；列：7 天。用圆点表示完成情况，每个习惯使用自己的主题色。
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最近 7 天', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            // 星期标题行
            Row(
              children: [
                const SizedBox(width: 72),
                ...List.generate(days.length, (i) {
                  final isToday = _isToday(i);
                  return Expanded(
                    child: Center(
                      child: Text(
                        weekdays[days[i].date.weekday - 1],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w400,
                          color: isToday
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            // 习惯行
            ...items.map((item) => _buildHabitRow(item)),
          ],
        ),
      ),
    );
  }

  bool _isToday(int index) {
    if (index >= days.length) return false;
    final today = DateTime.now();
    final d = days[index];
    return d.date.year == today.year &&
        d.date.month == today.month &&
        d.date.day == today.day;
  }

  Widget _buildHabitRow(HabitItemStats item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Row(
              children: [
                Text(item.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(item.recent7Values.length, (i) {
            final done = item.type == HabitStatType.boolean
                ? item.recent7Values[i] == 1
                : item.recent7Values[i] > 0;
            final isToday = _isToday(i);

            return Expanded(
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? (isToday
                            ? AppColors.primary
                            : item.color)
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
