import 'package:flutter/material.dart';
import '../widgets/flora_page_route.dart';
import '../widgets/flora_app_bar.dart';

import '../models/default_tag_config.dart';
import '../models/diary_entry.dart';
import '../models/polish_result.dart';
import '../models/quick_capture_submission.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../services/ai_config_repository.dart';
import '../services/api_client.dart';
import '../services/draft_repository.dart';
import '../services/image_settings_repository.dart';
import '../services/polisher_service.dart';
import '../services/tag_repository.dart';
import '../services/tag_settings_helper.dart';
import '../services/tag_settings_repository.dart';
import '../widgets/diary_markdown_view.dart';
import '../widgets/diary_date_title.dart';
import '../widgets/entry_type.dart';
import '../widgets/flora_empty.dart';
import '../widgets/flora_error_state.dart';
import '../widgets/flora_icon.dart';
import '../widgets/flora_success_snackbar.dart';
import '../widgets/historical_quick_record_fab.dart';
import '../widgets/flora_skeleton.dart';
import '../widgets/quick_record_backdrop.dart';
import 'quick_capture_screen.dart';
import '../widgets/reading_cache_status.dart';

typedef HistoricalImagePicker = QuickCaptureImagePicker;
typedef HistoricalImageCompressor = QuickCaptureImageCompressor;

/// 历史日记详情页。
/// 已有内容保持只读，只允许补录随手记、觉察和小确幸。
class ReadOnlyDiaryScreen extends StatefulWidget {
  final DateTime date;
  final ApiClient apiClient;
  final HistoricalImagePicker? imagePicker;
  final DraftRepository? draftRepository;
  final ImageSettingsRepository? imageSettingsRepository;
  final HistoricalImageCompressor? imageCompressor;

  const ReadOnlyDiaryScreen({
    super.key,
    required this.date,
    required this.apiClient,
    this.imagePicker,
    this.draftRepository,
    this.imageSettingsRepository,
    this.imageCompressor,
  });

  @override
  State<ReadOnlyDiaryScreen> createState() => _ReadOnlyDiaryScreenState();
}

class _ReadOnlyDiaryScreenState extends State<ReadOnlyDiaryScreen>
    with WidgetsBindingObserver {
  late final DraftRepository _draftRepository;
  late final ImageSettingsRepository _imageSettingsRepository;

  DiaryEntry? _diary;
  TagConfig? _tagConfig;
  TagSettings? _tagSettings;
  bool _loading = true;
  bool _refreshing = false;
  bool _quickRecordExpanded = false;
  String? _error;
  DateTime? _cachedAt;
  bool _verified = false;
  int _requestSerial = 0;

  TagConfig get _effectiveTagConfig {
    final config = _tagConfig ?? DefaultTagConfig.value;
    final settings = _tagSettings;
    return settings == null
        ? config
        : TagSettingsHelper.effectiveTagConfig(config, settings);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draftRepository = widget.draftRepository ?? DraftRepository();
    _imageSettingsRepository =
        widget.imageSettingsRepository ?? ImageSettingsRepository();
    _loadDiary();
    _loadTagConfig();
  }

  Future<void> _loadDiary() async {
    final serial = ++_requestSerial;
    final hasVisibleContent = _diary != null;
    setState(() {
      _loading = !hasVisibleContent;
      _refreshing = hasVisibleContent;
      _error = null;
      _verified = false;
      _quickRecordExpanded = false;
    });

    try {
      final diary = await widget.apiClient.getDiary(
        widget.date,
        onCached: (cached) {
          if (!mounted || serial != _requestSerial || hasVisibleContent) return;
          setState(() {
            _diary = cached.value;
            _cachedAt = cached.updatedAt;
            _loading = false;
            _refreshing = true;
          });
        },
      );
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _diary = diary?.raw.isNotEmpty == true ? diary : null;
        _loading = false;
        _refreshing = false;
        _verified = true;
        _cachedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        if (error is ApiException && error.isAuthenticationFailure) {
          _diary = null;
          _cachedAt = null;
          _error = '认证失败，请检查连接设置后重试';
        } else {
          _error = _diary == null ? '此日记尚未缓存，连接服务器后可查看' : null;
        }
        _loading = false;
        _refreshing = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ReadOnlyDiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.apiClient, widget.apiClient) ||
        oldWidget.date != widget.date) {
      _diary = null;
      _cachedAt = null;
      _loadDiary();
      _loadTagConfig();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      _loadDiary();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadTagConfig() async {
    final client = widget.apiClient;
    final config = await TagRepository(
      apiClient: widget.apiClient,
    ).loadTagConfig();
    final settings = await TagSettingsRepository().loadTagSettings(config);
    if (!mounted || !identical(client, widget.apiClient)) return;
    setState(() {
      _tagConfig = config;
      _tagSettings = settings;
    });
  }

  Future<bool> _appendEntry(
    EntryType type,
    QuickCaptureSubmission submission,
  ) async {
    Future<bool> append() {
      return switch (type) {
        EntryType.quickNote => widget.apiClient.appendQuickNote(
          widget.date,
          submission.content,
          tags: submission.tags,
          time: submission.time,
          entryId: submission.entryId,
          operationId: submission.operationId,
        ),
        EntryType.reflection => widget.apiClient.appendReflection(
          widget.date,
          submission.content,
          tags: submission.tags,
          time: submission.time,
        ),
        EntryType.happiness => widget.apiClient.appendHappiness(
          widget.date,
          submission.content,
          tags: submission.tags,
          time: submission.time,
          entryId: submission.entryId,
          operationId: submission.operationId,
        ),
        EntryType.anxiety => Future.value(false),
      };
    }

    var success = await append();
    if (!success) {
      final created = await widget.apiClient.ensureDiary(widget.date);
      if (!created) return false;
      success = await append();
    }
    return success;
  }

  Future<PolishResult> _polish(String content, EntryType entryType) async {
    final aiConfig = await AIConfigRepository().loadAIConfig();
    if (!aiConfig.isUsable) {
      throw Exception('润色功能尚未配置，请前往设置');
    }
    final service = PolisherService();
    try {
      return await service.polish(
        content: content,
        entryType: entryType,
        tagConfig: _effectiveTagConfig,
        config: aiConfig,
        tagSettings: _tagSettings,
      );
    } finally {
      service.dispose();
    }
  }

  Future<void> _openQuickCapture(EntryType type) async {
    setState(() => _quickRecordExpanded = false);
    final result = await Navigator.of(context).push<QuickCaptureResult>(
      FloraPageRoute(
        builder: (_) => QuickCaptureScreen(
          entryType: type,
          openedAt: DateTime.now(),
          recordDate: widget.date,
          draftRepository: _draftRepository,
          apiClient: widget.apiClient,
          photoDate: widget.date,
          imageSettingsRepository: _imageSettingsRepository,
          imagePicker: widget.imagePicker,
          imageCompressor: widget.imageCompressor,
          tagConfig: _effectiveTagConfig,
          onPolish: _polish,
          onSave: (submission) async {
            final success = await _appendEntry(type, submission);
            if (!success) throw Exception('保存失败');
          },
        ),
      ),
    );
    if (!mounted || result == null || result == QuickCaptureResult.discarded) {
      return;
    }
    if (result == QuickCaptureResult.saved) {
      showFloraSuccessSnackBar(context, '已补录');
    }
    await _loadDiary();
  }

  void _handleBack() {
    if (!_quickRecordExpanded) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _quickRecordExpanded = false);
    // PopScope 会先拦住当前这一帧的返回；下一帧直接执行原有返回行为。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return FloraSkeletonRegion(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, _headerInset + 24, 16, 96),
          children: [
            FloraSkeletonBox(width: 220, height: 18),
            SizedBox(height: 20),
            FloraSkeletonBox(width: double.infinity, height: 18),
            SizedBox(height: 12),
            FloraSkeletonBox(width: double.infinity, height: 18),
            SizedBox(height: 12),
            FloraSkeletonBox(width: 240, height: 18),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDiary,
      edgeOffset: _headerInset,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, _headerInset, 16, 0),
        children: [
          if (_refreshing)
            const SizedBox(
              height: 2,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 16),
          if (_error != null && _diary == null)
            _buildError()
          else if (_diary == null)
            _buildEmpty(theme)
          else ...[
            if (!_verified)
              ReadingCacheStatus(
                updatedAt: _cachedAt,
                refreshing: _refreshing,
                onRetry: _loadDiary,
              ),
            if (_error != null) _buildInlineError(theme),
            DiaryMarkdownView(
              markdown: _diary?.raw ?? '',
              onHabitUpdate: null,
              onEntryDelete: null,
              onEntryEdit: null,
              onGenerateCoach: null,
              apiClient: widget.apiClient,
              date: widget.date,
              readOnly: true,
              hiddenSections: const {'tomorrow', 'habits'},
            ),
          ],
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return const Padding(
      padding: EdgeInsets.only(top: 64),
      child: FloraEmpty(
        name: FloraIcons.emptyPast,
        title: '这一天还没有留下记录',
        message: '点击右下角，为这一天补一条。',
      ),
    );
  }

  Widget _buildError() {
    return FloraErrorState(
      message: _error!,
      onRetry: _loadDiary,
      padding: const EdgeInsets.only(top: 64),
    );
  }

  Widget _buildInlineError(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          TextButton(onPressed: _loadDiary, child: const Text('重试')),
        ],
      ),
    );
  }

  double get _headerInset =>
      DiaryDateTitle.preferredToolbarHeight(context) +
      MediaQuery.paddingOf(context).top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope<void>(
      canPop: !_quickRecordExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _quickRecordExpanded) {
          setState(() => _quickRecordExpanded = false);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FloraAppBar(
          glassBackground: true,
          toolbarHeight: DiaryDateTitle.preferredToolbarHeight(context),
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: DiaryDateTitle(date: widget.date, showYear: true),
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const FloraIcon(FloraIcons.back),
            onPressed: _handleBack,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: QuickRecordBackdrop(
          expanded: _quickRecordExpanded,
          bannerBottom: _headerInset,
          onDismiss: () => setState(() => _quickRecordExpanded = false),
          child: Theme(
            data: theme.copyWith(canvasColor: theme.scaffoldBackgroundColor),
            child: _buildBody(theme),
          ),
        ),
        floatingActionButton: ExcludeSemantics(
          excluding: !_verified,
          child: IgnorePointer(
            ignoring: !_verified,
            child: Opacity(
              opacity: _verified ? 1 : 0.4,
              child: HistoricalQuickRecordFab(
                expanded: _quickRecordExpanded,
                onToggle: () {
                  setState(() => _quickRecordExpanded = !_quickRecordExpanded);
                },
                onEntrySelected: _openQuickCapture,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
