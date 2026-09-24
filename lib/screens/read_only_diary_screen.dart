import 'package:flutter/material.dart';

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
import 'quick_capture_screen.dart';

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

class _ReadOnlyDiaryScreenState extends State<ReadOnlyDiaryScreen> {
  late final DraftRepository _draftRepository;
  late final ImageSettingsRepository _imageSettingsRepository;

  DiaryEntry? _diary;
  TagConfig? _tagConfig;
  TagSettings? _tagSettings;
  bool _loading = true;
  bool _refreshing = false;
  bool _quickRecordExpanded = false;
  String? _error;

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
    _draftRepository = widget.draftRepository ?? DraftRepository();
    _imageSettingsRepository =
        widget.imageSettingsRepository ?? ImageSettingsRepository();
    _loadDiary();
    _loadTagConfig();
  }

  Future<void> _loadDiary() async {
    final hasVisibleContent = _diary != null;
    setState(() {
      _loading = !hasVisibleContent;
      _refreshing = hasVisibleContent;
      _error = null;
    });

    try {
      final diary = await widget.apiClient.getDiary(widget.date);
      if (diary == null && hasVisibleContent) {
        throw StateError('diary refresh failed');
      }
      if (!mounted) return;
      setState(() {
        _diary = diary?.raw.isNotEmpty == true ? diary : null;
        _loading = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败，请检查网络后重试';
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _loadTagConfig() async {
    final config = await TagRepository(
      apiClient: widget.apiClient,
    ).loadTagConfig();
    final settings = await TagSettingsRepository().loadTagSettings(config);
    if (!mounted) return;
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
      MaterialPageRoute(
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

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return FloraSkeletonRegion(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 96),
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
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: DiaryDateTitle.preferredToolbarHeight(context),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: DiaryDateTitle(date: widget.date, showYear: true),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Theme(
        data: theme.copyWith(canvasColor: theme.scaffoldBackgroundColor),
        child: _buildBody(theme),
      ),
      floatingActionButton: HistoricalQuickRecordFab(
        expanded: _quickRecordExpanded,
        onToggle: () {
          setState(() => _quickRecordExpanded = !_quickRecordExpanded);
        },
        onEntrySelected: _openQuickCapture,
      ),
    );
  }
}
