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
        const minTabWidth = 44.0;
        final fittedWidth = constraints.maxWidth / widget.items.length;
        final tabWidth = fittedWidth >= minTabWidth ? fittedWidth : minTabWidth;
        final stripWidth = tabWidth * widget.items.length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _HabitHeatmapTabStrip(
            items: widget.items,
            selected: _selected,
            tabWidth: tabWidth,
            width: stripWidth + 4,
            onSelected: (item) => setState(() => _selected = item),
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

class _HabitHeatmapTabStrip extends StatelessWidget {
  final List<HabitItemStats> items;
  final HabitItemStats selected;
  final double tabWidth;
  final double width;
  final ValueChanged<HabitItemStats> onSelected;

  const _HabitHeatmapTabStrip({
    required this.items,
    required this.selected,
    required this.tabWidth,
    required this.width,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedIndex = items.indexOf(selected).clamp(0, items.length - 1);
    final trackColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest.withAlpha(120)
        : theme.colorScheme.onSurface.withAlpha(24);
    final indicatorColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surface;
    final shadowColor = Colors.black.withAlpha(
      theme.brightness == Brightness.dark ? 70 : 31,
    );

    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            top: 0,
            left: selectedIndex * tabWidth,
            width: tabWidth,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(
                    theme.brightness == Brightness.dark ? 70 : 42,
                  ),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(
                      theme.brightness == Brightness.dark ? 48 : 10,
                    ),
                    blurRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              for (final item in items)
                _HabitHeatmapTabButton(
                  item: item,
                  selected: item == selected,
                  width: tabWidth,
                  onTap: () => onSelected(item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitHeatmapTabButton extends StatelessWidget {
  final HabitItemStats item;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  const _HabitHeatmapTabButton({
    required this.item,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactiveColor = theme.colorScheme.onSurfaceVariant.withAlpha(
      theme.brightness == Brightness.dark ? 178 : 153,
    );

    return Tooltip(
      message: item.displayName,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.displayName,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: width,
            height: 44,
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                scale: selected ? 1.04 : 1,
                child: HabitIcon(
                  item.icon,
                  size: 22,
                  color: selected ? item.color : inactiveColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
