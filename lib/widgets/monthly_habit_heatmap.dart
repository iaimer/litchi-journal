import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import '../theme/app_theme.dart';

/// 月度总体节奏热力图。
/// 当前月每天一个格子，用颜色深浅表示整体习惯完成程度。
class MonthlyHabitHeatmap extends StatelessWidget {
  final List<HabitDayRecord> monthDays;
  final int year;
  final int month;

  const MonthlyHabitHeatmap({
    super.key,
    required this.monthDays,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    // 按月日组织
    final dayMap = <int, HabitDayRecord>{};
    for (final d in monthDays) {
      dayMap[d.date.day] = d;
    }

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final today = DateTime.now();
    final isToday = today.year == year && today.month == month;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '这个月的节奏',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            // 星期头
            Row(
              children: const ['一', '二', '三', '四', '五', '六', '日']
                  .map((w) => Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // 日期格
            ..._buildWeeks(dayMap, firstWeekday, daysInMonth, isToday, today),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWeeks(
    Map<int, HabitDayRecord> dayMap,
    int firstWeekday,
    int daysInMonth,
    bool isCurrentMonth,
    DateTime today,
  ) {
    final weeks = <Widget>[];
    var day = 1;
    // 周一 = 1
    final startCol = firstWeekday - 1;
    const totalCols = 7;

    while (day <= daysInMonth) {
      final row = <Widget>[];
      for (var col = 0; col < totalCols; col++) {
        final isEmptyBefore = weeks.isEmpty && col < startCol;
        if (isEmptyBefore || day > daysInMonth) {
          row.add(const Expanded(child: SizedBox.shrink()));
        } else {
          row.add(_buildDayCell(dayMap, day,
              isToday: isCurrentMonth && today.day == day));
          day++;
        }
      }
      weeks.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(children: row),
        ),
      );
    }
    return weeks;
  }

  Widget _buildDayCell(
      Map<int, HabitDayRecord> dayMap, int day, {required bool isToday}) {
    final record = dayMap[day];
    final rate = record != null ? record.completedCount / HabitDayRecord.totalCount : 0.0;

    Color fillColor;
    if (record == null || !record.hasDiary) {
      fillColor = Colors.transparent;
    } else if (rate >= 0.8) {
      fillColor = AppColors.success.withValues(alpha: 0.7);
    } else if (rate >= 0.4) {
      fillColor = AppColors.success.withValues(alpha: 0.45);
    } else {
      fillColor = AppColors.success.withValues(alpha: 0.2);
    }

    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(3),
            border: isToday
                ? Border.all(color: AppColors.primary, width: 1.5)
                : (record != null && !record.hasDiary
                    ? Border.all(color: AppColors.border)
                    : null),
          ),
        ),
      ),
    );
  }
}
