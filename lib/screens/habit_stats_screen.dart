import 'package:flutter/material.dart';

import '../models/habit_settings.dart';
import '../models/habit_stats.dart';
import '../services/api_client.dart';
import '../services/habit_settings_repository.dart';
import '../services/habit_stats_cache_repository.dart';
import '../services/habit_stats_service.dart';
import '../widgets/flora_empty.dart';
import '../widgets/flora_icon.dart';
import '../widgets/habit_heatmap_tabs.dart';
import '../widgets/habit_rhythm_grid.dart';
import '../widgets/habit_summary_card.dart';

/// 习惯统计页面。
/// 只读展示长期生活节奏和习惯趋势。
///
/// 加载策略（cache-first）：
/// 1. 先读持久化缓存，有则立即显示
/// 2. 无论有无缓存，后台刷新最新数据
/// 3. 显示缓存时顶部显示轻量「正在更新最新节奏…」
/// 4. 刷新成功后更新 UI 并写入缓存
/// 5. 刷新失败保留旧缓存
class HabitStatsScreen extends StatefulWidget {
  final ApiClient apiClient;
  final HabitStatsCacheRepository? cacheRepo;
  final HabitSettingsRepository? habitSettingsRepo;
  final int refreshToken;

  const HabitStatsScreen({
    super.key,
    required this.apiClient,
    this.cacheRepo,
    this.habitSettingsRepo,
    this.refreshToken = 0,
  });

  @override
  State<HabitStatsScreen> createState() => _HabitStatsScreenState();
}

class _HabitStatsScreenState extends State<HabitStatsScreen> {
  late final HabitStatsService _service;
  late final HabitStatsCacheRepository _cacheRepo;

  /// 当前展示的统计（可能是缓存，可能是最新）
  HabitStats? _stats;

  /// 是否正在后台刷新
  bool _refreshing = false;

  /// 是否正在首次加载（无缓存时）
  bool _loading = true;

  /// 整体加载错误（仅无缓存时显示）
  String? _error;

  /// 当前展示的是缓存数据
  bool _isCached = false;

  /// 持久化 Future
  late Future<void> _loadFuture;

  /// 习惯设置
  HabitSettings _habitSettings = HabitSettings.defaults;

  /// 活跃习惯 key 列表
  List<String> _activeHabitKeys = const [
    'water',
    'steps',
    'reading',
    'language',
    'supplements',
  ];

  @override
  void initState() {
    super.initState();
    _service = HabitStatsService(widget.apiClient);
    _cacheRepo = widget.cacheRepo ?? HabitStatsCacheRepository();
    _loadFuture = _initLoad();
  }

  @override
  void didUpdateWidget(covariant HabitStatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadFuture = _loadFresh(force: true);
    }
  }

  Future<void> _initLoad() async {
    // 0. 加载习惯设置
    try {
      final settingsRepo =
          widget.habitSettingsRepo ?? HabitSettingsRepository();
      final settings = await settingsRepo.load();
      _activeHabitKeys = settings.activeKeys;
      _habitSettings = settings;
    } catch (_) {
      // 加载失败保持默认全部活跃
    }

    // 1. 尝试读缓存
    final cached = await _cacheRepo.load();
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _stats = cached;
        _isCached = true;
        _loading = false;
        _refreshing = true;
      });
    }

    // 2. 后台刷新最新数据
    await _loadFresh(force: true);
  }

  Future<void> _loadFresh({bool force = false}) async {
    // 每次刷新都重新读取习惯设置（用户可能在设置页已修改）
    // 同时重置实例级缓存，确保完全重新构建（包含最新视觉配置）
    _service.resetInstanceCache();
    await _reloadActiveKeys();
    if (!mounted) return;

    if (!force && !_isCached && !_loading) return;

    try {
      if (force && _stats != null && !_refreshing) {
        setState(() => _refreshing = true);
      }

      // 先加载 7 天，再加载 30 天
      await _service.loadRecent7(
        activeHabitKeys: _activeHabitKeys,
        habitSettings: _habitSettings,
      );
      if (!mounted) return;

      final stats30 = await _service.loadRecent30(
        activeHabitKeys: _activeHabitKeys,
        habitSettings: _habitSettings,
      );
      if (!mounted) return;

      // 写入缓存
      await _cacheRepo.save(stats30);

      if (!mounted) return;
      setState(() {
        _stats = stats30;
        _isCached = false;
        _refreshing = false;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      if (_stats != null) {
        // 有缓存：静默失败，保留缓存，去掉刷新标识
        setState(() => _refreshing = false);
      } else {
        // 无缓存：显示错误
        setState(() {
          _error = '习惯数据暂时没有加载出来。\n稍后再看看。';
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _reloadActiveKeys() async {
    try {
      final settingsRepo =
          widget.habitSettingsRepo ?? HabitSettingsRepository();
      final settings = await settingsRepo.load();
      if (!mounted) return;
      _activeHabitKeys = settings.activeKeys;
      _habitSettings = settings;
    } catch (_) {
      // 静默失败，保持现有过滤状态
    }
  }

  Future<void> _pullRefresh() async {
    // 重新加载习惯设置
    try {
      final settingsRepo =
          widget.habitSettingsRepo ?? HabitSettingsRepository();
      final settings = await settingsRepo.load();
      _activeHabitKeys = settings.activeKeys;
      _habitSettings = settings;
    } catch (_) {}

    HabitStatsService.clearDayCache();
    await _cacheRepo.clear();
    _stats = null;
    _isCached = false;
    _refreshing = false;
    _loading = true;
    _error = null;
    setState(() {});
    _loadFuture = _loadFresh(force: true);
    await _loadFuture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        bottom: true,
        child: _error != null ? _buildError(theme) : _buildBody(theme),
      ),
    );
  }

  // ── 主体 ──

  Widget _buildBody(ThemeData theme) {
    // 无缓存：显示 loading 骨架
    if (_loading && _stats == null) {
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

    final stats = _stats!;

    if (stats.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme),
        // 后台刷新中的轻量提示
        if (_refreshing) _buildRefreshBanner(theme),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _pullRefresh,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 4),
                // 温柔反馈卡
                HabitSummaryCard(stats: stats),

                // 最近7天节奏谱
                HabitRhythmGrid(days: stats.recentDays, items: stats.items),

                // 30 天热力图
                HabitHeatmapTabs(items: stats.items),

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
      padding: EdgeInsets.fromLTRB(16, 16 + MediaQuery.of(context).padding.top, 16, 0),
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

  // ── 后台刷新轻量提示 ──

  Widget _buildRefreshBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.primary.withAlpha(25),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '正在更新最新节奏…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
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
        const Expanded(
          child: Center(child: FloraEmpty(name: FloraIcons.emptyHabits)),
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
    final theme = Theme.of(context);
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
            Text(
              text,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
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
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.dividerColor,
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
                Text(
                  '正在整理这 30 天的小痕迹…',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
