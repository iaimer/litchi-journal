import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import '../models/habit_trend.dart';
import '../theme/app_theme.dart';

/// 习惯趋势页顶部的淡彩指标卡。
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
    final value = _metricValue(item);
    final label = _metricLabel(item);

    return Semantics(
      key: ValueKey('habit_metric_${item.key}'),
      container: true,
      label: '${item.displayName}，${period.range.label}，$label $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            item.color.withValues(
              alpha: theme.brightness == Brightness.dark ? .14 : .10,
            ),
            theme.colorScheme.surface,
          ),
          borderRadius: BorderRadius.circular(FloraRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
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
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topRight,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: MediaQuery.highContrastOf(context)
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                      style: TextStyle(
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
}

String _metricLabel(HabitTrendItem item) =>
    item.type == HabitStatType.duration ? '累计' : '最长连续';

String _metricValue(HabitTrendItem item) => item.type == HabitStatType.duration
    ? formatDurationMinutes(item.totalDurationMinutes)
    : '${item.longestStreak} 天';

/// 将分钟格式化为趋势页使用的一位小数小时。
String formatDurationMinutes(int minutes) {
  final safeMinutes = minutes < 0 ? 0 : minutes;
  if (safeMinutes > 0 && safeMinutes < 3) return '<0.1 小时';
  return '${(safeMinutes / 60).toStringAsFixed(1)} 小时';
}
