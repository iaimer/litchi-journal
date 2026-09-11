import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import '../models/habit_trend.dart';
import 'habit_icon.dart';
import 'habit_trend_dashboard.dart';

/// 习惯趋势页的纯点阵卡片列表。
class HabitTrendHeatmapList extends StatelessWidget {
  final HabitTrendPeriod period;
  final List<HabitTrendItem> items;

  const HabitTrendHeatmapList({
    super.key,
    required this.period,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _HabitTrendHeatmapCard(period: period, item: item),
          ),
      ],
    );
  }
}

class _HabitTrendHeatmapCard extends StatelessWidget {
  final HabitTrendPeriod period;
  final HabitTrendItem item;

  const _HabitTrendHeatmapCard({required this.period, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _summaryLabel();
    return Semantics(
      container: true,
      label: summary,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HabitIcon(item.icon, size: 20, color: item.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (period.range != HabitTrendRange.year) ...[
                const _HabitTrendWeekdayHeader(),
                const SizedBox(height: 6),
              ],
              ExcludeSemantics(
                child: _HabitTrendHeatmap(period: period, item: item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _summaryLabel() {
    final visibleDays = item.days.where((day) => !day.future).length;
    if (item.type == HabitStatType.duration) {
      return '${item.displayName}，${period.range.label}，累计 ${formatDurationMinutes(item.totalDurationMinutes)}，$visibleDays 天';
    }
    return '${item.displayName}，${period.range.label}，最长连续 ${item.longestStreak} 天，$visibleDays 天';
  }
}

class _HabitTrendHeatmap extends StatelessWidget {
  final HabitTrendPeriod period;
  final HabitTrendItem item;

  const _HabitTrendHeatmap({required this.period, required this.item});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isYear = period.range == HabitTrendRange.year;
        const labelsWidth = 18.0;
        const labelsGap = 6.0;
        final gridWidth = isYear
            ? math.max(0.0, constraints.maxWidth - labelsWidth - labelsGap)
            : constraints.maxWidth;
        final layout = _GridLayout.forPeriod(period, gridWidth);
        final grid = SizedBox(
          width: gridWidth,
          height: layout.height,
          child: CustomPaint(
            key: ValueKey('habit_heatmap_${item.key}'),
            painter: _HabitTrendHeatmapPainter(
              period: period,
              item: item,
              theme: Theme.of(context),
            ),
          ),
        );
        if (!isYear) return grid;

        return SizedBox(
          width: double.infinity,
          height: layout.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HabitTrendYearWeekdayLabels(width: labelsWidth, layout: layout),
              const SizedBox(width: labelsGap),
              Expanded(child: grid),
            ],
          ),
        );
      },
    );
  }
}

class _HabitTrendYearWeekdayLabels extends StatelessWidget {
  final double width;
  final _GridLayout layout;

  const _HabitTrendYearWeekdayLabels({
    required this.width,
    required this.layout,
  });

  static const labels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return SizedBox(
      key: const ValueKey('habit_heatmap_year_weekday_labels'),
      width: width,
      child: Column(
        children: [
          for (var row = 0; row < labels.length; row++)
            SizedBox(
              height: row == labels.length - 1
                  ? layout.cellSize
                  : layout.rowStep,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(labels[row], style: style),
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitTrendWeekdayHeader extends StatelessWidget {
  const _HabitTrendWeekdayHeader();

  static const labels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(child: Text(label, style: style)),
          ),
      ],
    );
  }
}

class _HabitTrendHeatmapPainter extends CustomPainter {
  final HabitTrendPeriod period;
  final HabitTrendItem item;
  final ThemeData theme;

  _HabitTrendHeatmapPainter({
    required this.period,
    required this.item,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _GridLayout.forPeriod(period, size.width);
    final byDate = <String, HabitTrendDay>{
      for (final day in item.days) _dateKey(day.date): day,
    };

    for (var row = 0; row < layout.rows; row++) {
      for (var column = 0; column < layout.columns; column++) {
        final date = layout.dateAt(row, column);
        final day = date == null ? null : byDate[_dateKey(date)];

        final center = layout.center(row, column);
        final radius = layout.cellSize * 0.28;
        final paint = Paint()
          ..color = resolveHabitTrendSlotColor(
            day: day,
            item: item,
            theme: theme,
          );
        final rect = Rect.fromCenter(
          center: center,
          width: layout.cellSize,
          height: layout.cellSize,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HabitTrendHeatmapPainter oldDelegate) {
    return oldDelegate.period.cacheKey != period.cacheKey ||
        oldDelegate.item != item ||
        oldDelegate.theme.brightness != theme.brightness;
  }
}

/// 将某天的统计语义映射为热力图颜色。
Color resolveHabitTrendDayColor({
  required HabitTrendItem item,
  required HabitTrendDay day,
  required ThemeData theme,
}) {
  final emptyColor = theme.dividerColor.withAlpha(
    theme.brightness == Brightness.dark ? 110 : 125,
  );
  if (item.type == HabitStatType.boolean) {
    return day.completed ? item.color : emptyColor;
  }
  if (item.type == HabitStatType.duration && !day.known) {
    return day.completed ? item.color : emptyColor;
  }

  final target = item.dailyTarget;
  if (target == null) {
    return day.completed || day.value > 0 ? item.color : emptyColor;
  }

  final ratio = day.value / target;
  if (ratio <= 0) return emptyColor;
  if (ratio < 0.5) return item.color.withAlpha(80);
  if (ratio < 1) return item.color.withAlpha(150);
  return item.color;
}

class _GridLayout {
  final int rows;
  final int columns;
  final double cellSize;
  final double columnStep;
  final double rowStep;
  final DateTime? Function(int row, int column) dateAt;

  const _GridLayout({
    required this.rows,
    required this.columns,
    required this.cellSize,
    required this.columnStep,
    required this.rowStep,
    required this.dateAt,
  });

  double get height => rows * cellSize + (rows - 1) * (rowStep - cellSize);

  factory _GridLayout.forPeriod(HabitTrendPeriod period, double width) {
    switch (period.range) {
      case HabitTrendRange.week:
        const columns = 7;
        final step = width / columns;
        const cellSize = 24.0;
        return _GridLayout(
          rows: 1,
          columns: columns,
          cellSize: math.min(cellSize, step),
          columnStep: step,
          rowStep: math.min(cellSize, step),
          dateAt: (_, column) => period.start.add(Duration(days: column)),
        );
      case HabitTrendRange.month:
        const columns = 7;
        const rows = 6;
        final step = width / columns;
        const cellSize = 24.0;
        final actualCellSize = math.min(cellSize, step);
        const rowGap = 4.0;
        final dates = buildHabitTrendMonthDateGrid(period);
        return _GridLayout(
          rows: rows,
          columns: columns,
          cellSize: actualCellSize,
          columnStep: step,
          rowStep: actualCellSize + rowGap,
          dateAt: (row, column) => dates[row][column],
        );
      case HabitTrendRange.year:
        final dates = buildHabitTrendYearDateGrid(period);
        final rows = dates.length;
        final columns = dates.first.length;
        const gap = 2.0;
        final cellSize = math.max(0.0, (width - gap * (columns - 1)) / columns);
        return _GridLayout(
          rows: rows,
          columns: columns,
          cellSize: cellSize,
          columnStep: cellSize + gap,
          rowStep: cellSize + gap,
          dateAt: (row, column) => dates[row][column],
        );
    }
  }

  Offset center(int row, int column) {
    return Offset(
      columnStep * column + columnStep / 2,
      rowStep * row + cellSize / 2,
    );
  }
}

/// 返回年度点阵的日期槽位，供绘制与边界测试共享同一映射。
@visibleForTesting
List<List<DateTime?>> buildHabitTrendYearDateGrid(HabitTrendPeriod period) {
  const rows = 7;
  const columns = 26;
  final start = period.heatmapStart;
  return List.generate(rows, (row) {
    return List.generate(columns, (column) {
      return start.add(Duration(days: column * 7 + row));
    }, growable: false);
  }, growable: false);
}

/// 将月份映射为完整的 7 列 × 6 行日历槽位，补位交给绘制层使用占位色。
@visibleForTesting
List<List<DateTime?>> buildHabitTrendMonthDateGrid(HabitTrendPeriod period) {
  const rows = 6;
  const columns = 7;
  final offset = period.start.weekday - 1;
  return List.generate(rows, (row) {
    return List.generate(columns, (column) {
      final index = row * columns + column - offset;
      if (index < 0 || index >= period.dayCount) return null;
      return period.start.add(Duration(days: index));
    }, growable: false);
  }, growable: false);
}

/// 返回真实日期和补位/未来日期在热力图中的颜色，便于回归测试覆盖槽位语义。
@visibleForTesting
Color resolveHabitTrendSlotColor({
  required HabitTrendDay? day,
  required HabitTrendItem item,
  required ThemeData theme,
}) {
  if (day == null || day.future) return habitTrendPlaceholderColor(theme);
  return resolveHabitTrendDayColor(item: item, day: day, theme: theme);
}

@visibleForTesting
Color habitTrendPlaceholderColor(ThemeData theme) =>
    theme.dividerColor.withAlpha(theme.brightness == Brightness.dark ? 40 : 52);

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
