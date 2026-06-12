import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import '../services/api_client.dart';
import '../services/habit_stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/habit_group_card.dart';
import '../widgets/habit_rhythm_grid.dart';
import '../widgets/habit_summary_card.dart';
import '../widgets/monthly_habit_heatmap.dart';

/// 习惯页面。
/// 只读展示长期生活节奏和习惯趋势。
class HabitStatsScreen extends StatefulWidget {
  final ApiClient apiClient;

  const HabitStatsScreen({super.key, required this.apiClient});

  @override
  State<HabitStatsScreen> createState() => _HabitStatsScreenState();
}

class _HabitStatsScreenState extends State<HabitStatsScreen> {
  late final HabitStatsService _service;
  HabitStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = HabitStatsService(widget.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _service.loadStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '习惯数据暂时没有加载出来。\n稍后再看看。';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError(theme)
                : _buildContent(theme),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return ListView(
      children: [
        const SizedBox(height: 48),
        Text(
          '习惯',
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '看看最近的生活节奏',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    final stats = _stats!;
    final now = DateTime.now();

    if (stats.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 16),
          Text('习惯', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 4),
          Text(
            '看看最近的生活节奏',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '还没有足够的习惯记录。\n今天先照顾一个小习惯就很好。',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        // 标题区
        Text('习惯', style: theme.textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          '看看最近的生活节奏',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),

        // 温柔反馈卡
        HabitSummaryCard(stats: stats),

        // 最近7天节奏谱
        HabitRhythmGrid(
          days: stats.recentDays,
          items: stats.items,
        ),

        // 月度热力图
        MonthlyHabitHeatmap(
          monthDays: stats.monthDays,
          year: now.year,
          month: now.month,
        ),

        // 分组习惯卡 — 照顾身体
        HabitGroupCard(
          groupLabel: '照顾身体',
          items: stats.items
              .where((i) => i.group == HabitGroup.body)
              .toList(),
        ),

        // 分组习惯卡 — 照顾成长
        HabitGroupCard(
          groupLabel: '照顾成长',
          items: stats.items
              .where((i) => i.group == HabitGroup.growth)
              .toList(),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}
