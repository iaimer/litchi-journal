import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import 'habit_icon.dart';

/// 30 天热力图，按习惯图标 Tab 切换。
/// 展示选中习惯最近 30 天的热力图、完成率、最长连续天数和平均值。
class HabitHeatmapTabs extends StatefulWidget {
  final List<HabitItemStats> items;

  const HabitHeatmapTabs({super.key, required this.items});

  @override
  State<HabitHeatmapTabs> createState() => _HabitHeatmapTabsState();
}

class _HabitHeatmapTabsState extends State<HabitHeatmapTabs> {
  late HabitItemStats _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.items.first;
  }

  @override
  void didUpdateWidget(covariant HabitHeatmapTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.isNotEmpty && !widget.items.contains(_selected)) {
      _selected = widget.items.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('看看这 30 天的小痕迹', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _buildTabStrip(theme),
            const SizedBox(height: 12),
            // 统计概要
            _buildStatsRow(theme),
            const SizedBox(height: 8),
            // 30 天热力图
            _buildHeatmap(theme),
            const SizedBox(height: 8),
            // 平均值文案
            _buildAverageText(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTabStrip(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        const minTabWidth = 44.0;
        final totalGap = gap * (widget.items.length - 1).clamp(0, 99);
        final fittedWidth =
            (constraints.maxWidth - totalGap) / widget.items.length;
        final tabWidth = fittedWidth >= minTabWidth ? fittedWidth : minTabWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < widget.items.length; i++) ...[
                _HabitHeatmapTab(
                  item: widget.items[i],
                  selected: widget.items[i] == _selected,
                  width: tabWidth,
                  onTap: () => setState(() => _selected = widget.items[i]),
                ),
                if (i != widget.items.length - 1) const SizedBox(width: gap),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    final ratePercent = (_selected.completionRate30 * 100).toStringAsFixed(0);

    return Row(
      children: [
        Text(
          '完成率 $ratePercent%',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '最长连续 ${_selected.longestStreak30} 天',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmap(ThemeData theme) {
    final values = _selected.recent30Values;
    final color = _selected.color;

    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 10;
        const gap = 2.0;
        final rows = (values.length / cols).ceil();
        final cellSize = (constraints.maxWidth / cols) - gap;

        if (cellSize <= 0) return const SizedBox.shrink();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(rows, (row) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(cols, (col) {
                final index = row * cols + col;
                if (index >= values.length) {
                  return SizedBox(
                    width: cellSize + gap,
                    height: cellSize + gap,
                  );
                }
                final done = _selected.type == HabitStatType.boolean
                    ? values[index] == 1
                    : values[index] > 0;

                return Container(
                  width: cellSize,
                  height: cellSize,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: done ? color : theme.dividerColor,
                  ),
                );
              }),
            );
          }),
        );
      },
    );
  }

  Widget _buildAverageText(ThemeData theme) {
    String text;
    final daysWithValue = _selected.recent30Values.where((v) => v > 0).length;

    if (_selected.type == HabitStatType.numeric) {
      if (daysWithValue == 0) {
        text = '最近 30 天还没有记录。';
      } else {
        var sum = 0;
        for (final v in _selected.recent30Values) {
          sum += v;
        }
        final avg = (sum / daysWithValue).toStringAsFixed(0);
        final unit = _unit(_selected.key);
        text = '最近 30 天，平均每天${_selected.displayName} $avg $unit。';
      }
    } else {
      text = '最近 30 天，完成了 ${_selected.completedDays30}/30 天。';
    }

    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.6,
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

class _HabitHeatmapTab extends StatelessWidget {
  final HabitItemStats item;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  const _HabitHeatmapTab({
    required this.item,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = item.color;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;
    final backgroundColor = selected
        ? activeColor.withAlpha(theme.brightness == Brightness.dark ? 46 : 34)
        : theme.colorScheme.surfaceContainerHighest.withAlpha(
            theme.brightness == Brightness.dark ? 72 : 92,
          );
    final borderColor = selected
        ? activeColor.withAlpha(theme.brightness == Brightness.dark ? 190 : 145)
        : theme.dividerColor;

    return Tooltip(
      message: item.displayName,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.displayName,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: width,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: HabitIcon(
              item.icon,
              size: 22,
              color: selected ? activeColor : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }
}
