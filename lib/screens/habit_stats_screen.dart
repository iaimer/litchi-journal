import 'dart:async';

import 'package:flutter/material.dart';

import '../models/habit_settings.dart';
import '../models/habit_trend.dart';
import '../services/api_client.dart';
import '../services/habit_settings_repository.dart';
import '../services/habit_stats_cache_repository.dart';
import '../services/habit_trend_cache_repository.dart';
import '../services/habit_trend_service.dart';
import '../widgets/flora_empty.dart';
import '../widgets/flora_icon.dart';
import '../widgets/habit_trend_dashboard.dart';
import '../widgets/habit_trend_heatmap.dart';

/// 习惯趋势页。
///
/// 页面只负责周期选择、缓存状态和展示。Markdown 解析仍由服务端完成，
/// 周期内的聚合则由 [HabitTrendService] 使用领域模型计算。
class HabitStatsScreen extends StatefulWidget {
  final ApiClient apiClient;

  /// 旧缓存参数保留用于兼容已有调用方；趋势页使用 [trendCacheRepo]。
  @Deprecated('请使用 trendCacheRepo')
  final HabitStatsCacheRepository? cacheRepo;
  final HabitTrendCacheRepository? trendCacheRepo;
  final HabitSettingsRepository? habitSettingsRepo;
  final int refreshToken;

  const HabitStatsScreen({
    super.key,
    required this.apiClient,
    this.cacheRepo,
    this.trendCacheRepo,
    this.habitSettingsRepo,
    this.refreshToken = 0,
  });

  @override
  State<HabitStatsScreen> createState() => _HabitStatsScreenState();
}

class _HabitStatsScreenState extends State<HabitStatsScreen>
    with WidgetsBindingObserver {
  late HabitTrendService _service;
  late HabitTrendCacheRepository _trendCacheRepo;

  HabitSettings _settings = HabitSettings.defaults;
  HabitTrendRange _range = HabitTrendRange.month;
  DateTime _anchor = _dateOnly(DateTime.now());
  HabitTrendStats? _stats;
  String? _error;
  int _requestSerial = 0;
  DateTime _referenceDate = _dateOnly(DateTime.now());
  Timer? _dayBoundaryTimer;

  HabitTrendPeriod get _period => HabitTrendPeriod.forAnchor(
    _range,
    _anchor,
    referenceDate: _referenceDate,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayBoundaryRefresh();
    _configureRepositories();
    _initLoad();
  }

  @override
  void dispose() {
    _dayBoundaryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refreshForDateChange();
    _scheduleDayBoundaryRefresh();
  }

  void _scheduleDayBoundaryRefresh() {
    _dayBoundaryTimer?.cancel();
    final nextDate = DateTime(
      _referenceDate.year,
      _referenceDate.month,
      _referenceDate.day + 1,
    );
    final delay =
        nextDate.difference(DateTime.now()) + const Duration(seconds: 1);
    _dayBoundaryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!mounted) return;
      _refreshForDateChange();
      _scheduleDayBoundaryRefresh();
    });
  }

  void _refreshForDateChange() {
    final today = _dateOnly(DateTime.now());
    if (today == _referenceDate) return;
    _referenceDate = today;
    _anchor = today;
    _requestSerial++;
    if (mounted) {
      setState(() {
        _stats = null;
        _error = null;
      });
      _loadPeriod(reset: true, useCache: false);
    }
  }

  @override
  void didUpdateWidget(covariant HabitStatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final apiClientChanged = !identical(widget.apiClient, oldWidget.apiClient);
    final cacheRepositoryChanged = !identical(
      widget.trendCacheRepo,
      oldWidget.trendCacheRepo,
    );
    if (apiClientChanged || cacheRepositoryChanged) {
      _requestSerial++;
      _configureRepositories();
      _stats = null;
      _error = null;
      _refreshFromSource(reset: true);
      return;
    }
    if (widget.refreshToken != oldWidget.refreshToken) {
      _refreshFromSource(reset: true);
    }
  }

  void _configureRepositories() {
    _service = HabitTrendService(widget.apiClient);
    _trendCacheRepo =
        widget.trendCacheRepo ??
        HabitTrendCacheRepository(namespace: widget.apiClient.cacheNamespace);
  }

  Future<void> _initLoad() async {
    await _reloadSettings();
    if (!mounted) return;
    await _loadPeriod(reset: true);
  }

  Future<void> _reloadSettings() async {
    try {
      final repo = widget.habitSettingsRepo ?? HabitSettingsRepository();
      final settings = await repo.load();
      _settings = settings;
      if (mounted) setState(() {});
    } catch (_) {
      // 仓储本身会回退默认值；这里保留内存中的默认设置作为最后兜底。
    }
  }

  Future<void> _refreshFromSource({bool reset = false}) async {
    await _reloadSettings();
    if (!mounted) return;
    await _loadPeriod(reset: reset, useCache: !reset);
  }

  Future<void> _loadPeriod({bool reset = false, bool useCache = true}) async {
    final period = _period;
    final settings = _settings;
    final requestId = ++_requestSerial;

    if (mounted && (reset || _stats == null)) {
      setState(() {
        if (reset) _stats = null;
        _error = null;
      });
    }

    if (useCache) {
      final cached = await _trendCacheRepo.load(period);
      if (!mounted || requestId != _requestSerial) return;
      if (cached != null &&
          cached.settingsSignature == _service.settingsSignature(settings)) {
        setState(() {
          _stats = cached;
          _error = null;
        });
      }
    }

    try {
      final fresh = await _service.load(period: period, settings: settings);
      if (!mounted || requestId != _requestSerial) return;
      await _trendCacheRepo.save(fresh);
      if (!mounted || requestId != _requestSerial) return;
      setState(() {
        _stats = fresh;
        _error = null;
      });
    } catch (_) {
      if (!mounted || requestId != _requestSerial) return;
      if (_stats == null) {
        setState(() {
          _error = '习惯趋势暂时无法加载';
        });
      }
      // 已经有缓存时，刷新失败不打断当前可读内容。
    }
  }

  Future<void> _pullRefresh() => _refreshFromSource();

  void _selectRange(HabitTrendRange range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _anchor = _referenceDate;
      _stats = null;
      _error = null;
    });
    _loadPeriod(reset: true);
  }

  void _shiftPeriod(int amount) {
    if (amount == 0 || _range == HabitTrendRange.year) return;
    final current = _period;
    if (amount > 0 && !current.canMoveForward(_today)) return;
    final next = current.shift(amount);
    setState(() {
      _anchor = next.start;
      _stats = null;
      _error = null;
    });
    _loadPeriod(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _pullRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _buildRangeSelector(theme),
                    const SizedBox(height: 8),
                    _buildPeriodNavigator(theme),
                    const SizedBox(height: 2),
                    if (_error != null)
                      _buildError(theme)
                    else if (_stats == null)
                      _buildLoading(theme)
                    else
                      _buildStats(_stats!, theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16 + MediaQuery.of(context).padding.top,
        16,
        0,
      ),
      child: Text('习惯趋势', style: theme.textTheme.headlineLarge),
    );
  }

  Widget _buildRangeSelector(ThemeData theme) {
    return Semantics(
      label: '统计周期',
      child: SegmentedButton<HabitTrendRange>(
        segments: [
          for (final range in HabitTrendRange.values)
            ButtonSegment<HabitTrendRange>(
              value: range,
              label: Text(range.label),
            ),
        ],
        selected: {_range},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) _selectRange(selection.first);
        },
      ),
    );
  }

  Widget _buildPeriodNavigator(ThemeData theme) {
    if (_range == HabitTrendRange.year) return const SizedBox.shrink();
    final period = _period;
    final canMoveForward = period.canMoveForward(_today);
    return Row(
      children: [
        IconButton(
          tooltip: '上一个${_range.label}',
          onPressed: () => _shiftPeriod(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            _periodLabel(period),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: '下一个${_range.label}',
          onPressed: canMoveForward ? () => _shiftPeriod(1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  String _periodLabel(HabitTrendPeriod period) {
    final start = period.start;
    final end = period.end;
    switch (period.range) {
      case HabitTrendRange.week:
        return '${start.year}年${start.month}月${start.day}日 - '
            '${end.month}月${end.day}日';
      case HabitTrendRange.month:
        return '${start.year}年${start.month}月';
      case HabitTrendRange.year:
        return '最近6个月';
    }
  }

  Widget _buildLoading(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 20),
          Text(
            '加载习惯趋势',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _loadPeriod(reset: true, useCache: false),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(HabitTrendStats stats, ThemeData theme) {
    if (stats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: FloraEmpty(name: FloraIcons.emptyHabits)),
      );
    }

    final itemsByKey = {for (final item in stats.items) item.key: item};
    final dashboardItems = <HabitTrendItem>[];
    for (final key in _settings.resolvedTrendDashboardHabitKeys) {
      final item = itemsByKey[key];
      if (item != null) dashboardItems.add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        HabitTrendDashboard(period: stats.period, items: dashboardItems),
        if (stats.period.range == HabitTrendRange.year) ...[
          const SizedBox(height: 14),
          Text(
            '最近6个月',
            key: const ValueKey('habit_heatmap_recent_label'),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        HabitTrendHeatmapList(period: stats.period, items: stats.items),
      ],
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime get _today => _referenceDate;
}
