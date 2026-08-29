import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/gallery_result.dart';
import '../models/memory_entry.dart';
import '../services/api_client.dart';
import '../services/gallery_service.dart';
import '../services/past_memory_service.dart';
import '../widgets/flora_empty.dart';
import '../widgets/flora_icon.dart';
import '../widgets/gallery_image_tile.dart';
import '../widgets/history_calendar.dart';
import 'gallery_image_viewer_screen.dart';
import 'read_only_diary_screen.dart';

class PastScreen extends StatefulWidget {
  final ApiClient apiClient;

  const PastScreen({super.key, required this.apiClient});

  @override
  State<PastScreen> createState() => _PastScreenState();
}

class _PastScreenState extends State<PastScreen> {
  late PastMemoryService _memoryService;
  late GalleryService _galleryService;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _galleryViewportKey = GlobalKey();
  final Map<String, GlobalKey> _monthKeys = {};
  final Map<String, Set<String>> _recordedDatesByMonth = {};

  MemoryEntry? _todayMemory;
  List<GalleryMonth> _galleryMonths = [];
  String? _nextCursor;
  String? _galleryError;
  String? _emptyMonthNotice;
  bool _galleryLoading = true;
  bool _galleryLoadingMore = false;
  bool _todayLoading = true;
  bool _calendarExpanded = false;
  bool _calendarLoading = false;
  bool _calendarLoadFailed = false;
  int _calendarRequestGeneration = 0;
  bool _monthSyncScheduled = false;
  int _galleryRequestGeneration = 0;
  int _todayRequestGeneration = 0;
  int _monthJumpGeneration = 0;
  DateTime _displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTime _calendarDisplayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  void initState() {
    super.initState();
    _memoryService = PastMemoryService(widget.apiClient);
    _galleryService = GalleryService(widget.apiClient);
    _scrollController.addListener(_handleScroll);
    _load();
  }

  @override
  void didUpdateWidget(covariant PastScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.apiClient, widget.apiClient)) return;

    // AppEntry 保存新地址后会复用 IndexedStack 中的页面 State；重建服务
    // 并让旧请求失效，确保画廊和「那年今日」立即使用新客户端。
    _memoryService = PastMemoryService(widget.apiClient);
    _galleryService = GalleryService(widget.apiClient);
    _calendarRequestGeneration++;
    _monthJumpGeneration++;
    setState(() {
      _todayMemory = null;
      _todayLoading = true;
      _recordedDatesByMonth.clear();
      _calendarLoading = false;
      _calendarLoadFailed = false;
      _calendarDisplayedMonth = _displayedMonth;
    });
    _load();
    if (_calendarExpanded) {
      _loadCalendarMonth(_calendarDisplayedMonth);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final todayRequestGeneration = ++_todayRequestGeneration;
    await Future.wait([
      _loadTodayHistory(todayRequestGeneration),
      _loadGallery(reset: true),
    ]);
  }

  Future<void> _loadTodayHistory(int requestGeneration) async {
    try {
      final memory = await _memoryService.getTodayHistory();
      if (!mounted || requestGeneration != _todayRequestGeneration) return;
      setState(() {
        _todayMemory = memory != null && memory.imageNames.isNotEmpty
            ? memory
            : null;
        _todayLoading = false;
      });
    } catch (_) {
      if (!mounted || requestGeneration != _todayRequestGeneration) return;
      setState(() => _todayLoading = false);
    }
  }

  Future<void> _loadGallery({String? cursor, bool reset = false}) async {
    final requestGeneration = reset
        ? ++_galleryRequestGeneration
        : _galleryRequestGeneration;
    if (reset) {
      setState(() {
        _galleryLoading = true;
        _galleryLoadingMore = false;
        _galleryError = null;
        _emptyMonthNotice = null;
        _galleryMonths = [];
        _nextCursor = null;
        _monthKeys.clear();
      });
      _galleryService.clearImageCache();
    } else {
      if (_galleryLoadingMore || _nextCursor == null) return;
      setState(() => _galleryLoadingMore = true);
    }

    try {
      final page = await _galleryService.fetchPage(cursor: cursor);
      if (!mounted || requestGeneration != _galleryRequestGeneration) return;
      setState(() {
        if (reset) {
          _galleryMonths = page.months;
        } else {
          final existing = _galleryMonths.map(_monthKey).toSet();
          _galleryMonths = [
            ..._galleryMonths,
            ...page.months.where(
              (month) => !existing.contains(_monthKey(month)),
            ),
          ];
        }
        _nextCursor = page.nextCursor;
        _galleryLoading = false;
        _galleryLoadingMore = false;
        _galleryError = null;
        if (reset && cursor != null && page.months.isNotEmpty) {
          final first = page.months.first;
          if (first.days.isEmpty) _emptyMonthNotice = _monthKey(first);
        }
      });
      _scheduleMonthSync();
    } catch (_) {
      if (!mounted || requestGeneration != _galleryRequestGeneration) return;
      setState(() {
        _galleryLoading = false;
        _galleryLoadingMore = false;
        _galleryError = '画廊加载失败，请检查网络后重试';
      });
    }
  }

  Future<void> _refresh() async {
    await _load();
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 600 &&
        !_galleryLoadingMore &&
        _nextCursor != null) {
      _loadGallery(cursor: _nextCursor);
    }
    _scheduleMonthSync();
  }

  void _scheduleMonthSync() {
    if (_monthSyncScheduled) return;
    _monthSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _monthSyncScheduled = false;
      if (mounted) _syncDisplayedMonth();
    });
  }

  void _syncDisplayedMonth() {
    final viewport = _galleryViewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox) return;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    DateTime? visibleMonth;
    var visibleTop = double.negativeInfinity;

    for (final month in _galleryMonths.where(
      (month) => month.days.isNotEmpty,
    )) {
      final box = _monthKeys[_monthKey(month)]?.currentContext
          ?.findRenderObject();
      if (box is! RenderBox) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= viewportTop + 40 && top > visibleTop) {
        visibleTop = top;
        visibleMonth = month.date;
      }
    }

    if (visibleMonth != null && !_sameMonth(visibleMonth, _displayedMonth)) {
      setState(() => _displayedMonth = visibleMonth!);
    }
  }

  String _monthKey(GalleryMonth month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  String _monthKeyForDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  DateTime get _currentMonth =>
      DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _toggleCalendar() async {
    setState(() => _calendarExpanded = !_calendarExpanded);
    if (_calendarExpanded) {
      await _loadCalendarMonth(_calendarDisplayedMonth);
    }
  }

  Future<void> _loadCalendarMonth(DateTime month, {bool force = false}) async {
    final key = _monthKeyForDate(month);
    final requestGeneration = ++_calendarRequestGeneration;
    if (!force && _recordedDatesByMonth.containsKey(key)) {
      if (!mounted || requestGeneration != _calendarRequestGeneration) return;
      setState(() {
        _calendarLoading = false;
        _calendarLoadFailed = false;
      });
      return;
    }
    setState(() {
      _calendarLoading = true;
      _calendarLoadFailed = false;
    });
    try {
      final result = await widget.apiClient.fetchHistoryMonth(
        month.year,
        month.month,
      );
      final dates = result.diaries
          .where((day) => day.hasContent || day.hasImages)
          .map((day) => day.date)
          .toSet();
      if (!mounted || requestGeneration != _calendarRequestGeneration) return;
      setState(() {
        _recordedDatesByMonth[key] = dates;
        _calendarLoading = false;
      });
    } catch (_) {
      if (!mounted || requestGeneration != _calendarRequestGeneration) return;
      setState(() {
        _calendarLoading = false;
        _calendarLoadFailed = true;
      });
    }
  }

  Future<void> _changeCalendarMonth(DateTime month) async {
    setState(() => _calendarDisplayedMonth = month);
    await _loadCalendarMonth(month);
  }

  Future<void> _openCalendarDate(DateTime date) async {
    setState(() => _calendarExpanded = false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReadOnlyDiaryScreen(date: date, apiClient: widget.apiClient),
      ),
    );
    _recordedDatesByMonth.remove(_monthKeyForDate(date));
    if (_calendarExpanded) {
      await _loadCalendarMonth(_displayedMonth, force: true);
    }
  }

  Future<void> _openGalleryDay(GalleryDay day) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GalleryImageViewerScreen(
          day: day,
          galleryService: _galleryService,
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day - 1);
    final requestedInitialDate = _displayedMonth.isAfter(_currentMonth)
        ? _currentMonth
        : _displayedMonth;
    final initialDate = requestedInitialDate.isAfter(lastDate)
        ? lastDate
        : requestedInitialDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: lastDate,
      helpText: '选择画廊月份',
    );
    if (selected == null) return;
    await _jumpToMonth(DateTime(selected.year, selected.month));
  }

  Future<void> _changeGalleryMonth(int offset) async {
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + offset);
    if (next.isAfter(_currentMonth)) return;
    await _jumpToMonth(next);
  }

  Future<void> _jumpToMonth(DateTime month) async {
    final normalized = DateTime(month.year, month.month);
    if (normalized.isAfter(_currentMonth)) return;
    final jumpGeneration = ++_monthJumpGeneration;
    setState(() => _displayedMonth = normalized);

    final monthKey = _monthKeyForDate(normalized);
    final key = _monthKeys[monthKey];
    if (key?.currentContext != null) {
      await _scrollToMonth(monthKey, jumpGeneration);
      return;
    }

    // 重载期间列表会变短；先回到顶部，避免旧滚动偏移把新月份夹在
    // 不可见位置。请求完成后再等一帧，让新的 GlobalKey 建立完成。
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    await _loadGallery(cursor: _monthKeyForDate(normalized), reset: true);
    if (!mounted || jumpGeneration != _monthJumpGeneration) return;
    await WidgetsBinding.instance.endOfFrame;
    await _scrollToMonth(monthKey, jumpGeneration);
  }

  Future<void> _scrollToMonth(String monthKey, int jumpGeneration) async {
    if (!mounted || jumpGeneration != _monthJumpGeneration) return;
    final key = _monthKeys[monthKey];
    final monthContext = key?.currentContext;
    if (monthContext == null) return;
    await Scrollable.ensureVisible(
      monthContext,
      duration: const Duration(milliseconds: 280),
      alignment: 0.05,
    );
  }

  Future<void> _openRandomDay() async {
    final days = _galleryMonths
        .expand((month) => month.days)
        .where((day) => day.images.isNotEmpty)
        .toList();
    if (days.isEmpty) return;
    await _openGalleryDay(days[Random().nextInt(days.length)]);
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
                onRefresh: _refresh,
                child: _buildGalleryScroll(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final canRandom = _galleryMonths.any((month) => month.days.isNotEmpty);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16 + MediaQuery.of(context).padding.top,
        16,
        _calendarExpanded ? 12 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('过往', style: theme.textTheme.headlineLarge)),
              IconButton(
                key: const Key('gallery_random_button'),
                tooltip: canRandom ? '随机回顾' : '暂无照片可回顾',
                onPressed: canRandom ? _openRandomDay : null,
                icon: const FloraIcon(FloraIcons.shuffle),
              ),
              IconButton(
                key: const Key('history_calendar_toggle'),
                tooltip: _calendarExpanded ? '收起日历' : '选择日期',
                onPressed: _toggleCalendar,
                icon: Icon(
                  _calendarExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.calendar_month_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '把值得记住的日子，慢慢翻出来',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          _buildMonthPicker(theme),
          if (_calendarExpanded) ...[
            const SizedBox(height: 16),
            HistoryCalendar(
              displayedMonth: _calendarDisplayedMonth,
              recordedDateKeys:
                  _recordedDatesByMonth[_monthKeyForDate(
                    _calendarDisplayedMonth,
                  )] ??
                  const {},
              loading: _calendarLoading,
              markerLoadFailed: _calendarLoadFailed,
              today: DateTime.now(),
              onMonthChanged: _changeCalendarMonth,
              onDateSelected: _openCalendarDate,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthPicker(ThemeData theme) {
    return Row(
      children: [
        IconButton(
          key: const Key('gallery_previous_month'),
          tooltip: '上个月',
          onPressed: () => _changeGalleryMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: InkWell(
            key: const Key('gallery_month_picker'),
            borderRadius: BorderRadius.circular(20),
            onTap: _pickMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor, width: 0.5),
              ),
              child: Text(
                '${_displayedMonth.year}年${_displayedMonth.month}月',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
        ),
        IconButton(
          key: const Key('gallery_next_month'),
          tooltip: '下个月',
          onPressed: _displayedMonth.isBefore(_currentMonth)
              ? () => _changeGalleryMonth(1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildGalleryScroll(ThemeData theme) {
    final visibleMonths = _galleryMonths.where(
      (month) => month.days.isNotEmpty,
    );
    final hasPhotos = visibleMonths.isNotEmpty;
    return CustomScrollView(
      key: _galleryViewportKey,
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (_todayMemory != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: _MemoryCapsule(
                entry: _todayMemory!,
                galleryService: _galleryService,
                onTap: () => _openGalleryDay(
                  GalleryDay(
                    date: ApiClient.formatDate(_todayMemory!.date),
                    images: _todayMemory!.imageNames,
                    hasContent: _todayMemory!.hasAnyContent,
                  ),
                ),
              ),
            ),
          ),
        if (_emptyMonthNotice != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildEmptyMonthNotice(theme, _emptyMonthNotice!),
            ),
          ),
        if (_galleryLoading && _galleryMonths.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_galleryError != null && _galleryMonths.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildGalleryError(theme),
          )
        else if (!hasPhotos && _todayLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!hasPhotos && !_todayLoading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildGalleryEmpty(theme),
          )
        else ...[
          for (final month in visibleMonths) ...[
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: _monthKeys.putIfAbsent(_monthKey(month), GlobalKey.new),
                child: _buildMonthHeader(theme, month),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final day = month.days[index];
                  return GalleryImageTile(
                    key: ValueKey('${day.date}-${day.firstImage}'),
                    day: day,
                    galleryService: _galleryService,
                    onTap: () => _openGalleryDay(day),
                  );
                }, childCount: month.days.length),
              ),
            ),
          ],
          if (_galleryLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          if (_galleryError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(child: _buildGalleryMoreError(theme)),
              ),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildMonthHeader(ThemeData theme, GalleryMonth month) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              '${month.year}年${month.month}月',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '${month.totalDays}天 · ${month.totalImages}张',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryEmpty(ThemeData theme) {
    final canLoadMore = _nextCursor != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FloraEmpty(name: FloraIcons.emptyPast),
          const SizedBox(height: 12),
          Text('还没有照片回忆', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '已有文字记录的日子，可以从右上角月历进入',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (canLoadMore) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _galleryLoadingMore
                  ? null
                  : () {
                      setState(() => _galleryError = null);
                      _loadGallery(cursor: _nextCursor);
                    },
              icon: _galleryLoadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.history),
              label: Text(_galleryError == null ? '加载更早的照片' : '更多回忆加载失败，重试'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGalleryError(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_galleryError!, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _loadGallery(reset: true),
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      ],
    );
  }

  Widget _buildGalleryMoreError(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('更多回忆加载失败', style: theme.textTheme.bodySmall),
        TextButton(
          onPressed: () {
            setState(() => _galleryError = null);
            _loadGallery(cursor: _nextCursor);
          },
          child: const Text('重试'),
        ),
      ],
    );
  }

  Widget _buildEmptyMonthNotice(ThemeData theme, String monthKey) {
    final parts = monthKey.split('-');
    final label = parts.length == 2
        ? '${parts[0]}年${int.parse(parts[1])}月'
        : monthKey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor, width: 0.5),
      ),
      child: Text('$label 暂无照片，继续向下看看更早的记录', style: theme.textTheme.bodySmall),
    );
  }
}

class _MemoryCapsule extends StatefulWidget {
  final MemoryEntry entry;
  final GalleryService galleryService;
  final VoidCallback onTap;

  const _MemoryCapsule({
    required this.entry,
    required this.galleryService,
    required this.onTap,
  });

  @override
  State<_MemoryCapsule> createState() => _MemoryCapsuleState();
}

class _MemoryCapsuleState extends State<_MemoryCapsule> {
  late Future<Uint8List> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImage();
  }

  @override
  void didUpdateWidget(covariant _MemoryCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.galleryService, widget.galleryService) ||
        oldWidget.entry.date != widget.entry.date ||
        oldWidget.entry.imageNames.join('\u0000') !=
            widget.entry.imageNames.join('\u0000')) {
      _imageFuture = _loadImage();
    }
  }

  Future<Uint8List> _loadImage() {
    return widget.galleryService.loadImage(
      day: GalleryDay(
        date: ApiClient.formatDate(widget.entry.date),
        images: widget.entry.imageNames,
        hasContent: widget.entry.hasAnyContent,
      ),
      imageName: widget.entry.imageNames.first,
      maxWidth: 240,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FutureBuilder<Uint8List>(
                    future: _imageFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.image_outlined),
                        );
                      }
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        cacheWidth: 240,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('那年今日', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.entry.date.year}年${widget.entry.date.month}月${widget.entry.date.day}日',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (widget.entry.joyText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.entry.joyText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
