import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../widgets/flora_dock.dart';
import '../widgets/flora_glass.dart';
import '../widgets/flora_page_route.dart';
import '../widgets/flora_origin.dart';
import '../widgets/flora_dialog.dart';

import '../models/gallery_result.dart';
import '../models/memory_entry.dart';
import '../services/api_client.dart';
import '../services/gallery_service.dart';
import '../services/past_memory_service.dart';
import '../theme/app_theme.dart';
import '../widgets/flora_empty.dart';
import '../widgets/flora_error_state.dart';
import '../widgets/flora_icon.dart';
import '../widgets/flora_primary_header.dart';
import '../widgets/flora_skeleton.dart';
import '../widgets/gallery_image_tile.dart';
import '../widgets/history_calendar.dart';
import 'gallery_image_viewer_screen.dart';
import 'read_only_diary_screen.dart';
import '../widgets/reading_cache_status.dart';

typedef _CalendarSelection = ({DateTime date, FloraOrigin? origin});

class PastScreen extends StatefulWidget {
  final ApiClient apiClient;
  final bool active;

  const PastScreen({super.key, required this.apiClient, this.active = true});

  @override
  State<PastScreen> createState() => _PastScreenState();
}

class _PastScreenState extends State<PastScreen> with WidgetsBindingObserver {
  late PastMemoryService _memoryService;
  late GalleryService _galleryService;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _galleryViewportKey = GlobalKey();
  final GlobalKey _headerKey = GlobalKey();
  final ValueNotifier<int> _calendarRevision = ValueNotifier(0);
  double _headerExtent = 0;
  final Map<String, GlobalKey> _monthKeys = {};
  final Map<String, Set<String>> _recordedDatesByMonth = {};

  MemoryEntry? _todayMemory;
  List<GalleryMonth> _galleryMonths = [];
  String? _nextCursor;
  String? _galleryError;
  bool _galleryLocal = false;
  DateTime? _calendarCachedAt;
  String? _calendarError;
  final Set<String?> _failedCursors = {};
  bool _restoredEarlierPages = false;
  final Set<String> _loadedPageStarts = {};
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
    WidgetsBinding.instance.addObserver(this);
    _memoryService = PastMemoryService(widget.apiClient);
    _galleryService = GalleryService(widget.apiClient);
    _scrollController.addListener(_handleScroll);
    _load();
  }

  @override
  void didUpdateWidget(covariant PastScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.apiClient, widget.apiClient)) {
      if (widget.active && !oldWidget.active) _load();
      return;
    }

    // AppEntry 保存新地址后会复用 IndexedStack 中的页面 State；重建服务
    // 并让旧请求失效，确保画廊和「随机漫步」立即使用新客户端。
    _memoryService = PastMemoryService(widget.apiClient);
    _galleryService = GalleryService(widget.apiClient);
    _calendarRequestGeneration++;
    setState(() {
      _todayMemory = null;
      _todayLoading = true;
      _recordedDatesByMonth.clear();
      _calendarLoading = false;
      _calendarLoadFailed = false;
      _galleryLocal = false;
      _galleryMonths = [];
      _loadedPageStarts.clear();
      _restoredEarlierPages = false;
      _calendarDisplayedMonth = _displayedMonth;
    });
    _load();
    if (_calendarExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _calendarExpanded) {
          _loadCalendarMonth(_calendarDisplayedMonth);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calendarRequestGeneration++;
    _calendarRevision.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.active &&
        (_calendarExpanded || (ModalRoute.of(context)?.isCurrent ?? true))) {
      _load();
      if (_calendarExpanded) _loadCalendarMonth(_calendarDisplayedMonth);
    }
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
      _failedCursors.clear();
      final preserveVisibleContent =
          _galleryMonths.isNotEmpty && cursor == null;
      setState(() {
        _galleryLoading = true;
        _galleryLoadingMore = false;
        _galleryError = null;
        if (!preserveVisibleContent) {
          _galleryMonths = [];
          _nextCursor = null;
          _monthKeys.clear();
        }
      });
    } else {
      if (_galleryLoadingMore || _nextCursor == null) return;
      setState(() => _galleryLoadingMore = true);
    }

    try {
      if (reset &&
          _galleryMonths.isEmpty &&
          widget.apiClient.readingCache.enabled) {
        await _restoreCachedGallery(requestGeneration);
      }
      final page = await _galleryService.fetchPage(
        cursor: cursor,
        onCached: (cached) {
          if (!mounted || requestGeneration != _galleryRequestGeneration) {
            return;
          }
          // 恢复链已按每月最新副本合并，旧首页不能再次覆盖它或当前正文。
          if (reset && _galleryMonths.isNotEmpty) return;
          setState(() {
            _applyGalleryPage(
              cached.value,
              reset: reset,
              requestedCursor: cursor,
            );
            _galleryLocal = true;
          });
          _scheduleMonthSync();
        },
      );
      if (!mounted || requestGeneration != _galleryRequestGeneration) return;
      setState(() {
        _applyGalleryPage(page, reset: reset, requestedCursor: cursor);
        _galleryLocal = reset;
        _galleryLoading = reset;
        _galleryLoadingMore = false;
        _galleryError = null;
      });
      if (reset) {
        await _refreshLoadedMonths(page, requestGeneration);
        if (!mounted || requestGeneration != _galleryRequestGeneration) return;
        setState(() {
          _galleryLoading = false;
          _galleryLocal = false;
        });
      }
      _scheduleMonthSync();
    } catch (error) {
      if (!mounted || requestGeneration != _galleryRequestGeneration) return;
      setState(() {
        _failedCursors.add(cursor);
        if (error is ApiException && error.isAuthenticationFailure) {
          _galleryMonths = [];
          _galleryLocal = false;
          _todayMemory = null;
        }
        _galleryLoading = false;
        _galleryLoadingMore = false;
        _galleryError = error is ApiException && error.isAuthenticationFailure
            ? '认证失败，请检查连接设置后重试'
            : '暂时无法获取更多月份，连接服务器后重试';
      });
    }
  }

  Future<void> _refreshLoadedMonths(
    GalleryPage firstPage,
    int generation,
  ) async {
    final firstStart = firstPage.months.isEmpty
        ? null
        : _monthKey(firstPage.months.first);
    final starts =
        _loadedPageStarts.where((cursor) => cursor != firstStart).toList()
          ..sort((a, b) => b.compareTo(a));
    const batchSize = 3;
    for (var offset = 0; offset < starts.length; offset += batchSize) {
      if (!mounted || generation != _galleryRequestGeneration) return;
      final batch = starts.skip(offset).take(batchSize);
      final results = await Future.wait(
        batch.map((cursor) async {
          try {
            final page = await _galleryService.fetchPage(cursor: cursor);
            return (cursor: cursor, page: page, error: null as ApiException?);
          } on ApiException catch (error) {
            if (error.isAuthenticationFailure) rethrow;
            return (cursor: cursor, page: null as GalleryPage?, error: error);
          }
        }),
        eagerError: true,
      );
      if (!mounted || generation != _galleryRequestGeneration) return;
      // 同批请求并发，仍按游标顺序合并，防止响应乱序使旧照片复活。
      setState(() {
        for (final result in results) {
          final page = result.page;
          if (page == null) {
            _failedCursors.add(result.cursor);
            _galleryError = '部分过往内容更新失败，请重试';
            continue;
          }
          _applyGalleryPage(
            page,
            reset: false,
            requestedCursor: result.cursor,
            updateCursor: false,
          );
          if (result.cursor == starts.last) _nextCursor = page.nextCursor;
        }
      });
    }
  }

  void _applyGalleryPage(
    GalleryPage page, {
    required bool reset,
    String? requestedCursor,
    bool updateCursor = true,
    bool replaceCoveredMonths = true,
    bool rememberStart = true,
  }) {
    final updated = page.months.map(_monthKey).toSet();
    if (rememberStart && page.months.isNotEmpty) {
      _loadedPageStarts.add(_monthKey(page.months.first));
    }
    final start = requestedCursor == null
        ? DateTime(
            widget.apiClient.readingCache.now().year,
            widget.apiClient.readingCache.now().month,
          )
        : DateTime.parse('$requestedCursor-01');
    final end = page.nextCursor == null
        ? DateTime(1)
        : DateTime.parse('${page.nextCursor}-01');
    _galleryMonths = [
      ...page.months,
      ..._galleryMonths.where(
        (month) =>
            !updated.contains(_monthKey(month)) &&
            (!replaceCoveredMonths ||
                month.date.isAfter(start) ||
                !month.date.isAfter(end)),
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    // 顶部更新不覆盖已经浏览到的更早分页游标。
    if (updateCursor &&
        (!reset || (_nextCursor == null && !_restoredEarlierPages))) {
      _nextCursor = page.nextCursor;
    }
  }

  Future<void> _restoreCachedGallery(int generation) async {
    final starts = await widget.apiClient.visitedGalleryPageStarts();
    if (!mounted || generation != _galleryRequestGeneration) return;
    _loadedPageStarts.addAll(starts);
    var pages = 0;
    final updatedAtByMonth = <String, DateTime>{};
    await for (final cached in widget.apiClient.cachedGalleryPages()) {
      if (!mounted || generation != _galleryRequestGeneration) return;
      final original = cached.value;
      final months = original.months.where((month) {
        final key = _monthKey(month);
        final previous = updatedAtByMonth[key];
        if (previous != null && !cached.updatedAt.isAfter(previous)) {
          return false;
        }
        updatedAtByMonth[key] = cached.updatedAt;
        return true;
      }).toList();
      setState(() {
        if (original.months.isNotEmpty) {
          _loadedPageStarts.add(_monthKey(original.months.first));
        }
        _applyGalleryPage(
          GalleryPage(months: months, nextCursor: original.nextCursor),
          reset: false,
          replaceCoveredMonths: false,
          rememberStart: false,
          requestedCursor: original.months.isEmpty
              ? null
              : _monthKey(original.months.first),
        );
        _galleryLocal = true;
        _restoredEarlierPages = ++pages > 1;
      });
      _scheduleMonthSync();
    }
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 600 &&
        !_galleryLoadingMore &&
        !_galleryLoading &&
        !_failedCursors.contains(_nextCursor) &&
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
    final header = _headerKey.currentContext?.findRenderObject();
    if (header is! RenderBox) return;
    final viewportTop =
        header.localToGlobal(Offset.zero).dy + header.size.height;
    DateTime? visibleMonth;
    var visibleTop = double.negativeInfinity;
    DateTime? upcomingMonth;
    var upcomingTop = double.infinity;

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
      } else if (top > viewportTop + 40 && top < upcomingTop) {
        upcomingTop = top;
        upcomingMonth = month.date;
      }
    }

    // 顶部回忆卡片会把首个月份推离 Banner，仍应识别眼前的首组相册。
    visibleMonth ??= upcomingMonth;
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

  Future<void> _toggleCalendar() async {
    if (_calendarExpanded) return;
    _syncDisplayedMonth();
    final fallback = DateTime(DateTime.now().year, DateTime.now().month);
    final displayedMonth = _galleryMonths.any((month) => month.days.isNotEmpty)
        ? _displayedMonth
        : fallback;
    setState(() {
      _calendarExpanded = true;
      _calendarDisplayedMonth = displayedMonth;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.offset);
    }
    _loadCalendarMonth(displayedMonth);
    _CalendarSelection? selected;
    try {
      selected = await showFloraDialog<_CalendarSelection>(
        context: context,
        barrierColor: Colors.transparent,
        builder: _buildCalendarDialog,
      );
    } finally {
      _calendarRequestGeneration++;
      if (mounted) setState(() => _calendarExpanded = false);
    }
    if (mounted && selected != null) {
      final selection = selected;
      await FloraOrigin.withOrigin(
        selection.origin,
        () => _openCalendarDate(selection.date),
      );
    }
  }

  void _updateCalendar(VoidCallback update) {
    setState(update);
    _calendarRevision.value++;
  }

  Widget _buildCalendarDialog(BuildContext dialogContext) {
    return Dialog(
      key: const Key('history_calendar_dialog'),
      insetPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 400),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ValueListenableBuilder<int>(
        valueListenable: _calendarRevision,
        builder: (context, _, _) => _buildCalendarPanel(dialogContext),
      ),
    );
  }

  Widget _buildCalendarPanel(BuildContext dialogContext) {
    final theme = Theme.of(dialogContext);
    return ClipRRect(
      borderRadius: BorderRadius.circular(FloraRadius.lg),
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: RefreshIndicator(
          onRefresh: () => _loadCalendarMonth(_calendarDisplayedMonth),
          child: SingleChildScrollView(
            key: const Key('history_calendar_scroll'),
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  onDateSelected: (date) => Navigator.of(
                    dialogContext,
                  ).pop((date: date, origin: FloraOrigin.current)),
                ),
                ..._buildCalendarMessages(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCalendarMessages(ThemeData theme) => [
    if (_calendarCachedAt != null)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ReadingCacheStatus(
          message: _calendarLoadFailed ? '暂时无法连接，请稍后重试' : null,
        ),
      ),
    if (_calendarError != null)
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _calendarError!,
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
  ];

  Future<void> _loadCalendarMonth(DateTime month) async {
    final key = _monthKeyForDate(month);
    final requestGeneration = ++_calendarRequestGeneration;
    _calendarCachedAt = null;
    _updateCalendar(() {
      _calendarLoading = true;
      _calendarError = null;
      _calendarLoadFailed = false;
    });
    try {
      final result = await widget.apiClient.fetchHistoryMonth(
        month.year,
        month.month,
        allowCachedFallback: false,
        onCached: (cached) {
          if (!mounted || requestGeneration != _calendarRequestGeneration) {
            return;
          }
          _updateCalendar(() {
            _recordedDatesByMonth[key] = cached.value.diaries
                .where((day) => day.hasContent || day.hasImages)
                .map((day) => day.date)
                .toSet();
            _calendarCachedAt = cached.updatedAt;
            _calendarLoading = false;
          });
        },
      );
      final dates = result.diaries
          .where((day) => day.hasContent || day.hasImages)
          .map((day) => day.date)
          .toSet();
      if (!mounted || requestGeneration != _calendarRequestGeneration) return;
      _updateCalendar(() {
        _recordedDatesByMonth[key] = dates;
        _calendarLoading = false;
        _calendarCachedAt = null;
      });
    } catch (error) {
      if (!mounted || requestGeneration != _calendarRequestGeneration) return;
      _updateCalendar(() {
        if (error is ApiException && error.isAuthenticationFailure) {
          _recordedDatesByMonth.remove(key);
          _calendarCachedAt = null;
          _calendarError = '认证失败，请检查连接设置后重试';
        }
        _calendarLoading = false;
        _calendarLoadFailed = true;
      });
    }
  }

  Future<void> _changeCalendarMonth(DateTime month) async {
    _updateCalendar(() => _calendarDisplayedMonth = month);
    await _loadCalendarMonth(month);
  }

  Future<void> _openCalendarDate(DateTime date) async {
    final generation = widget.apiClient.readingCache.dataGeneration;
    await Navigator.of(context).push(
      FloraPageRoute(
        builder: (_) =>
            ReadOnlyDiaryScreen(date: date, apiClient: widget.apiClient),
      ),
    );
    _recordedDatesByMonth.remove(_monthKeyForDate(date));
    if (mounted && generation != widget.apiClient.readingCache.dataGeneration) {
      _load();
    }
  }

  Future<void> _openGalleryDay(GalleryDay day) async {
    final generation = widget.apiClient.readingCache.dataGeneration;
    await Navigator.of(context).push(
      FloraPageRoute(
        builder: (_) => GalleryImageViewerScreen(
          day: day,
          galleryService: _galleryService,
          apiClient: widget.apiClient,
        ),
      ),
    );
    if (mounted && generation != widget.apiClient.readingCache.dataGeneration) {
      _load();
    }
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
    _measureHeader();
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _load,
              edgeOffset: _headerExtent,
              child: _buildGalleryScroll(theme),
            ),
            if (_calendarExpanded) _buildCalendarBackdrop(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarBackdrop(ThemeData theme) {
    final highContrast = MediaQuery.highContrastOf(context);
    final shade = ColoredBox(
      color: highContrast
          ? theme.colorScheme.surface
          : theme.colorScheme.scrim.withValues(alpha: 0.18),
    );
    return Positioned.fill(
      top: _headerExtent,
      // 阅读 clearance 还包含 FAB 留白；此处只避让实际 Dock。
      bottom: max(0, (FloraDockScope.maybeOf(context)?.fabBottom ?? 12) - 12),
      child: ClipRect(
        key: const Key('history_calendar_backdrop'),
        child: highContrast
            ? shade
            : BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: FloraGlass.blurSigma,
                  sigmaY: FloraGlass.blurSigma,
                ),
                child: shade,
              ),
      ),
    );
  }

  void _measureHeader() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final header = _headerKey.currentContext?.findRenderObject();
      if (header is! RenderBox || header.size.height == _headerExtent) return;
      setState(() => _headerExtent = header.size.height);
      _scheduleMonthSync();
    });
  }

  Widget _buildHeader(ThemeData theme) {
    final canRandom = _galleryMonths.any((month) => month.days.isNotEmpty);
    return FloraPrimaryHeader(
      child: Row(
        children: [
          Expanded(child: Text('过往', style: theme.textTheme.headlineLarge)),
          _buildHeaderButton(
            IconButton(
              key: const Key('gallery_random_button'),
              tooltip: canRandom ? '随机回顾' : '暂无照片可回顾',
              onPressed: canRandom ? _openRandomDay : null,
              icon: const FloraIcon(FloraIcons.shuffle),
            ),
          ),
          _buildHeaderButton(
            IconButton(
              key: const Key('history_calendar_toggle'),
              tooltip: _calendarExpanded ? '收起日历' : '选择日期',
              onPressed: _toggleCalendar,
              icon: FloraIcon(
                _calendarExpanded ? FloraIcons.chevronUp : FloraIcons.calendar,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconButton button) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox.square(
        dimension: 48,
        child: FloraOriginIconButton(button: button),
      ),
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
      // 图墙先绘制，置顶头部才能采样已经滚入背后的真实内容。
      paintOrder: SliverPaintOrder.firstIsTop,
      slivers: [
        PinnedHeaderSliver(
          child: FloraGlassHeader(key: _headerKey, child: _buildHeader(theme)),
        ),
        if (_galleryLocal && _galleryMonths.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ReadingCacheStatus(message: _galleryError),
            ),
          ),
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
        if (_galleryLoading && _galleryMonths.isEmpty)
          const SliverToBoxAdapter(child: _GalleryLoadingPlaceholder())
        else if (_galleryError != null && _galleryMonths.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _buildGalleryError())
        else if (!hasPhotos && _todayLoading)
          const SliverToBoxAdapter(child: _GalleryLoadingPlaceholder())
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
        SliverToBoxAdapter(
          child: SizedBox(
            height: 32 + (FloraDockScope.maybeOf(context)?.clearance ?? 0),
          ),
        ),
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
    return FloraEmpty(
      name: FloraIcons.emptyPast,
      title: '还没有照片回忆',
      message: '已有文字记录的日子，可以从右上角月历进入',
      action: canLoadMore
          ? TextButton.icon(
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
                  : const FloraIcon(FloraIcons.historyAction),
              label: Text(_galleryError == null ? '加载更早的照片' : '更多回忆加载失败，重试'),
            )
          : null,
    );
  }

  Widget _buildGalleryError() {
    return FloraErrorState(
      message: _galleryError!,
      onRetry: () => _loadGallery(reset: true),
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
}

class _GalleryLoadingPlaceholder extends StatelessWidget {
  const _GalleryLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return FloraSkeletonRegion(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cell = max(0.0, (constraints.maxWidth - 12) / 3);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FloraSkeletonBox(width: 150, height: 20),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var index = 0; index < 6; index++)
                      FloraSkeletonBox(
                        width: cell,
                        height: cell,
                        radius: FloraRadius.sm,
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FloraRadius.md),
      ),
      child: FloraInkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(FloraRadius.sm),
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
                          child: const FloraIcon(FloraIcons.imagePlaceholder),
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
                    Text('随机漫步', style: theme.textTheme.titleMedium),
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
              FloraIcon(
                FloraIcons.chevronRight,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
