import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import '../theme/app_theme.dart';

/// 30 天热力图，按习惯 tab 切换。
/// 展示每个习惯最近 30 天的完成情况、完成率和最长连续天数。
class HabitHeatmapTabs extends StatefulWidget {
  final List<HabitItemStats> items;

  const HabitHeatmapTabs({super.key, required this.items});

  @override
  State<HabitHeatmapTabs> createState() => _HabitHeatmapTabsState();
}

class _HabitHeatmapTabsState extends State<HabitHeatmapTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.items.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '看看这 30 天的小痕迹',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            // Tab 标签栏
            TabBar(
              controller: _tabController,
              isScrollable: false,
              labelStyle: const TextStyle(fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              dividerColor: Colors.transparent,
              tabs: widget.items.map((item) {
                return Tab(text: '${item.icon} ${item.displayName}');
              }).toList(),
            ),
            const SizedBox(height: 12),
            // 内容区
            SizedBox(
              height: 130,
              child: TabBarView(
                controller: _tabController,
                children: widget.items.map((item) {
                  return _buildItemTab(item);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTab(HabitItemStats item) {
    final theme = Theme.of(context);
    final rate = item.completionRate30;
    final ratePercent = (rate * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 统计概要
        Row(
          children: [
            Text(
              '完成率 $ratePercent%',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 12),
            Text(
              '最长连续 ${item.longestStreak30} 天',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 30 天小格子
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const cols = 10;
              final rows = (item.recent30Values.length / cols).ceil();
              final cellSize = (constraints.maxWidth) / cols - 2;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(rows, (row) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(cols, (col) {
                      final index = row * cols + col;
                      if (index >= item.recent30Values.length) {
                        return SizedBox(
                            width: cellSize + 2, height: cellSize + 2);
                      }
                      final done = item.type == HabitStatType.boolean
                          ? item.recent30Values[index] == 1
                          : item.recent30Values[index] > 0;

                      return Container(
                        width: cellSize,
                        height: cellSize,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: done
                              ? item.color
                              : AppColors.border,
                        ),
                      );
                    }),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
