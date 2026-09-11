import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import '../models/habit_trend.dart';

/// 习惯趋势页顶部的极简指标条。
class HabitTrendDashboard extends StatelessWidget {
  final HabitTrendPeriod period;
  final List<HabitTrendItem> items;

  const HabitTrendDashboard({
    super.key,
    required this.period,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final visibleItems = items.take(4).toList(growable: false);
        final itemCount = visibleItems.length;
        final columns = itemCount == 4 && constraints.maxWidth < 400
            ? 2
            : itemCount;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final textScaler = MediaQuery.textScalerOf(context);
        final cardHeight =
            18.0 + textScaler.scale(17) * 1.4 + textScaler.scale(24);
        final resolvedCardHeight = cardHeight > 82 ? cardHeight : 82.0;
        final rowCount = (itemCount / columns).ceil();
        final dashboardHeight =
            rowCount * resolvedCardHeight + gap * (rowCount - 1);

        return SizedBox(
          height: dashboardHeight,
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in visibleItems)
                SizedBox(
                  width: itemWidth,
                  height: resolvedCardHeight,
                  child: _HabitTrendMetricCard(period: period, item: item),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HabitTrendMetricCard extends StatelessWidget {
  final HabitTrendPeriod period;
  final HabitTrendItem item;

  const _HabitTrendMetricCard({required this.period, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = _formatValue(item);
    final backgroundAlpha = theme.brightness == Brightness.dark ? 52 : 48;
    final borderAlpha = theme.brightness == Brightness.dark ? 90 : 72;

    return Semantics(
      key: ValueKey('habit_metric_${item.key}'),
      container: true,
      label: '${item.displayName}，${period.range.label}，$value',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: item.color.withAlpha(backgroundAlpha),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: item.color.withAlpha(borderAlpha),
            width: 0.7,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: Text(
                      item.displayName,
                      maxLines: 1,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatValue(HabitTrendItem item) {
    if (item.type == HabitStatType.duration) {
      return formatDurationMinutes(item.totalDurationMinutes);
    }
    return '${item.longestStreak} 天';
  }
}

/// 将分钟格式化为趋势页使用的一位小数小时。
String formatDurationMinutes(int minutes) {
  final safeMinutes = minutes < 0 ? 0 : minutes;
  if (safeMinutes > 0 && safeMinutes < 3) return '<0.1 小时';
  return '${(safeMinutes / 60).toStringAsFixed(1)} 小时';
}
