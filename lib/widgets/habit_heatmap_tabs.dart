import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import 'habit_icon.dart';

/// 30 天热力图，按习惯下拉选择器切换。
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
            // 习惯选择器
            _buildSelector(theme),
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

  Widget _buildSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<HabitItemStats>(
        value: _selected,
        isDense: true,
        isExpanded: false,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
        selectedItemBuilder: (context) {
          return widget.items.map((item) {
            return DropdownMenuItem<HabitItemStats>(
              value: item,
              child: _buildItemLabel(theme, item),
            );
          }).toList();
        },
        items: widget.items.map((item) {
          return DropdownMenuItem<HabitItemStats>(
            value: item,
            child: _buildItemLabel(theme, item),
          );
        }).toList(),
        onChanged: (item) {
          if (item != null) setState(() => _selected = item);
        },
      ),
    );
  }

  Widget _buildItemLabel(ThemeData theme, HabitItemStats item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HabitIcon(item.icon, size: 16, color: theme.colorScheme.onSurface),
        const SizedBox(width: 6),
        Text(item.displayName, style: theme.textTheme.bodyMedium),
      ],
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
