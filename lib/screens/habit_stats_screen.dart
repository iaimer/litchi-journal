import 'package:flutter/material.dart';

import '../models/habit_stats.dart';
import '../services/api_client.dart';
import '../services/habit_stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/habit_heatmap_tabs.dart';
import '../widgets/habit_rhythm_grid.dart';
import '../widgets/habit_summary_card.dart';

/// 习惯统计页面。
/// 只读展示长期生活节奏和习惯趋势。
///
/// 分阶段加载：
/// - 阶段 1：header 立即显示 + loading 骨架
/// - 阶段 2：最近 7 天数据优先显示（反馈卡 + 节奏谱）
/// - 阶段 3：最近 30 天热力图后台加载
class HabitStatsScreen extends StatefulWidget {
  final ApiClient apiClient;

  const HabitStatsScreen({super.key, required this.apiClient});

  @override
  State<HabitStatsScreen> createState() => _HabitStatsScreenState();
}

class _HabitStatsScreenState extends State<HabitStatsScreen> {
  late final HabitStatsService _service;

  /// 阶段 1 完成后的 7 天统计（null = 还在加载）
  HabitStats? _stats7;

  /// 阶段 2 完成后的完整统计（null = 还在加载）
  HabitStats? _stats30;

  /// 整体加载错误
  String? _error;

  /// 30 天模块加载失败（不影响 7 天显示）
  bool _days30Failed = false;

  /// 持久化 Future，不在 build 中创建
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _service = HabitStatsService(widget.apiClient);
    _loadFuture = _load();
  }

  Future<void> _load() async {
    // 阶段 1：加载最近 7 天
    try {
      final stats7 = await _service.loadRecent7();
      if (!mounted) return;
      setState(() {
        _stats7 = stats7;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '习惯数据暂时没有加载出来。\n稍后再看看。';
      });
      return;
    }

    // 阶段 2：后台加载最近 30 天
    try {
      final stats30 = await _service.loadRecent30();
      if (!mounted) return;
      setState(() {
        _stats30 = stats30;
        _days30Failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _days30Failed = true;
        // 仍然保留 7 天数据
        _stats30 = _stats7;
      });
    }
  }

  Future<void> _refresh() async {
    HabitStatsService.clearDayCache();
    _stats7 = null;
    _stats30 = null;
    _error = null;
    _days30Failed = false;
    _loadFuture = _load();
    setState(() {});
    await _loadFuture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _error != null
            ? _buildError(theme)
            : _buildBody(theme),
      ),
    );
  }

  // ── 主体 ──

  Widget _buildBody(ThemeData theme) {
    // 7 天数据未就绪：显示 loading 骨架
    if (_stats7 == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 4),
                _buildLoadingCard('正在看看最近的生活节奏…'),
                _buildSkeletonRhythm(theme),
                _buildSkeletonHeatmap(theme),
              ],
            ),
          ),
        ],
      );
    }

    // 7 天数据就绪，30 天可能还在加载
    final stats = _stats30 ?? _stats7!;
    final has30 = _stats30 != null && !_days30Failed;
    final loading30 = !has30 && _days30Failed == false;

    if (stats.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 4),
                // 温柔反馈卡
                HabitSummaryCard(stats: stats),

                // 最近7天节奏谱
                HabitRhythmGrid(
                  days: stats.recentDays,
                  items: stats.items,
                ),

                // 30 天热力图区域
                if (has30)
                  HabitHeatmapTabs(items: stats.items)
                else if (loading30)
                  _buildLoading30Card(theme)
                else
                  _build30FailedCard(theme),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ──

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('习惯统计', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 4),
          Text(
            '看看最近的生活节奏',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme),
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

  // ── Error ──

  Widget _buildError(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme),
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

  // ── Loading 骨架 ──

  Widget _buildLoadingCard(String text) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(text, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonRhythm(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最近 7 天', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            // 占位小点行
            ...List.generate(5, (_) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const SizedBox(width: 72, height: 12),
                    ...List.generate(7, (_) {
                      return Expanded(
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.border,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonHeatmap(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('看看这 30 天的小痕迹', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                const Text(
                  '正在整理这 30 天的小痕迹…',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 30 天 loading / error ──

  Widget _buildLoading30Card(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('看看这 30 天的小痕迹', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                const Text(
                  '正在整理这 30 天的小痕迹…',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _build30FailedCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('看看这 30 天的小痕迹', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              '30 天数据暂时没有加载出来，稍后再看看。',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
