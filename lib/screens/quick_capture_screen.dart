import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/draft_repository.dart';
import '../services/api_client.dart';
import '../services/image_compress_service.dart';
import '../services/image_settings_repository.dart';
import '../services/polisher_service.dart';
import '../services/tag_settings_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/flora_icon.dart';

import '../models/diary_document.dart';
import '../models/image_settings.dart';
import '../models/image_upload_item.dart';
import '../models/polish_result.dart';
import '../models/quick_capture_submission.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../widgets/entry_type.dart';
import '../widgets/entry_photo_grid.dart';
import '../widgets/record_time_picker_sheet.dart';
import '../widgets/tag_picker.dart';

typedef QuickCaptureImagePicker =
    Future<List<XFile>> Function(ImageSettings settings, int limit);
typedef QuickCaptureImageCompressor =
    Future<String> Function(Uint8List bytes, ImageSettings settings);

class QuickCaptureScreen extends StatefulWidget {
  final EntryType entryType;
  final DateTime openedAt;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;
  final DateTime? recordDate;
  final String? initialContent;
  final String? initialTime;
  final List<String> initialTags;
  final DraftRepository? draftRepository;
  final ApiClient? apiClient;
  final DateTime? photoDate;
  final String? initialEntryId;
  final List<DiaryPhoto> initialPhotos;
  final ImageSettingsRepository? imageSettingsRepository;
  final QuickCaptureImagePicker? imagePicker;
  final QuickCaptureImageCompressor? imageCompressor;
  final Future<TimeOfDay?> Function(
    BuildContext context,
    TimeOfDay initialTime,
  )?
  timePicker;
  final Future<PolishResult> Function(String content, EntryType entryType)?
  onPolish;
  final Future<void> Function(QuickCaptureSubmission submission) onSave;

  const QuickCaptureScreen({
    super.key,
    required this.entryType,
    required this.openedAt,
    required this.onSave,
    this.tagConfig,
    this.tagSettings,
    this.recordDate,
    this.initialContent,
    this.initialTime,
    this.initialTags = const [],
    this.draftRepository,
    this.apiClient,
    this.photoDate,
    this.initialEntryId,
    this.initialPhotos = const [],
    this.imageSettingsRepository,
    this.imagePicker,
    this.imageCompressor,
    this.timePicker,
    this.onPolish,
  }) : assert(entryType != EntryType.anxiety);

  @override
  State<QuickCaptureScreen> createState() => _QuickCaptureScreenState();
}

enum QuickCaptureResult { discarded, saved, partiallySaved }

class _QuickCaptureScreenState extends State<QuickCaptureScreen> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _entryScrollController = ScrollController();
  late TimeOfDay _selectedTime;
  late final String _initialContent;
  late final String _initialTime;
  late final List<String> _initialTags;
  late List<String> _retainedHiddenTags;
  late List<String> _selectedTags;
  late final String _entryId;
  late final String _operationId;
  final ImagePicker _systemImagePicker = ImagePicker();
  final ImageSettingsRepository _defaultImageSettingsRepository =
      ImageSettingsRepository();
  final List<ImageUploadItem> _newPhotos = [];
  final Set<String> _removedPhotoNames = {};
  final Set<String> _completedPhotoRemovals = {};
  bool _entrySaved = false;
  bool _saving = false;
  bool _polishing = false;
  bool _allowPop = false;
  bool _tagPickerExpanded = false;
  bool _restoringDraft = false;
  String? _error;

  /// 草稿写入串行链，避免保存与清空竞争导致残留。
  Future<void> _draftWriteChain = Future.value();

  bool get _isEditing => widget.initialContent != null;

  bool get _supportsPhotos =>
      widget.apiClient != null &&
      (widget.entryType == EntryType.quickNote ||
          widget.entryType == EntryType.happiness);

  DateTime get _photoDate =>
      widget.photoDate ?? widget.recordDate ?? widget.openedAt;

  int get _activePhotoCount =>
      widget.initialPhotos.where((photo) {
        return !_removedPhotoNames.contains(photo.filename) &&
            !_completedPhotoRemovals.contains(photo.filename);
      }).length +
      _newPhotos.length;

  bool get _hasPendingPhotoOperations =>
      _newPhotos.any((photo) => photo.status != ImageUploadStatus.success) ||
      widget.initialPhotos.any(
        (photo) =>
            _removedPhotoNames.contains(photo.filename) &&
            !_completedPhotoRemovals.contains(photo.filename),
      );

  bool get _hasPhotoChanges =>
      _newPhotos.isNotEmpty || _removedPhotoNames.isNotEmpty;

  bool get _shouldAutofocus => !_isEditing && widget.recordDate == null;

  bool get _hasUnsavedChanges {
    if (!_isEditing) {
      return _controller.text.trim().isNotEmpty ||
          _selectedTags.isNotEmpty ||
          _newPhotos.isNotEmpty;
    }
    return _controller.text != _initialContent ||
        _timeText != _initialTime ||
        !_sameTags(_selectedTags, _initialTags) ||
        _hasPhotoChanges;
  }

  bool get _canSave =>
      !_saving &&
      !_polishing &&
      (_entrySaved
          ? _hasPendingPhotoOperations || _hasPhotoChanges
          : _controller.text.trim().isNotEmpty);

  bool get _canPolish =>
      !_saving &&
      !_polishing &&
      !_entrySaved &&
      _controller.text.trim().isNotEmpty &&
      widget.onPolish != null;

  @override
  void initState() {
    super.initState();
    _entryId = widget.initialEntryId ?? ApiClient.generateUuidV4();
    _operationId = ApiClient.generateUuidV4();
    _initialContent = widget.initialContent ?? '';
    _controller = TextEditingController(text: _initialContent);
    _selectedTime =
        _parseTime(widget.initialTime) ??
        TimeOfDay.fromDateTime(widget.openedAt);
    _initialTime = _timeText;
    _initialTags = widget.initialTags
        .map((tag) => tag.startsWith('#') ? tag.substring(1) : tag)
        .toList(growable: false);
    _selectedTags = List<String>.from(_initialTags);
    _retainedHiddenTags =
        (widget.tagConfig != null && widget.tagSettings != null)
        ? TagSettingsHelper.hiddenInitialTags(
            _selectedTags,
            widget.tagSettings!,
          )
        : const [];
    _controller.addListener(_handleContentChanged);
    _restoreDraft();
  }

  TimeOfDay? _parseTime(String? value) {
    final parts = value?.split(':');
    if (parts == null || parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        minute < 0 ||
        hour > 23 ||
        minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _sameTags(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleContentChanged);
    _controller.dispose();
    _focusNode.dispose();
    _entryScrollController.dispose();
    super.dispose();
  }

  void _handleContentChanged() {
    if (mounted) setState(() {});
    _saveDraft();
  }

  Future<void> _restoreDraft() async {
    if (_isEditing) return;
    final repository = widget.draftRepository;
    final date = widget.recordDate;
    if (repository == null || date == null) return;
    _restoringDraft = true;
    final draft = await repository.loadQuickDraft(
      date: date,
      entryType: widget.entryType,
    );
    if (!mounted) return;
    if (draft != null) {
      setState(() {
        _controller.text = draft.content;
        _selectedTags = draft.tags;
        _controller.selection = TextSelection.collapsed(
          offset: draft.content.length,
        );
      });
    }
    _restoringDraft = false;
  }

  void _saveDraft() {
    if (_isEditing) return;
    final repository = widget.draftRepository;
    final date = widget.recordDate;
    if (_restoringDraft || repository == null || date == null) return;
    final content = _controller.text;
    final tags = List<String>.from(_selectedTags);
    _draftWriteChain = _draftWriteChain
        .then(
          (_) => repository.saveQuickDraft(
            date: date,
            entryType: widget.entryType,
            content: content,
            tags: tags,
          ),
        )
        .catchError((_) {});
  }

  String get _timeText =>
      '${_selectedTime.hour.toString().padLeft(2, '0')}:'
      '${_selectedTime.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    if (_entrySaved) return;
    FocusScope.of(context).unfocus();
    final picker = widget.timePicker;
    final picked = picker != null
        ? await picker(context, _selectedTime)
        : await showRecordTimePickerSheet(
            context,
            targetDate: _photoDate,
            initialTime: _selectedTime,
          );
    if (picked == null || !mounted) return;
    setState(() => _selectedTime = picked);
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;
    final title = _entrySaved ? '照片尚未全部完成' : '放弃记录？';
    final message = _entrySaved
        ? '文字和部分照片已经保存。离开后，失败照片需要重新选择，确定离开吗？'
        : '当前内容或已选照片还没有保存，确定要离开吗？';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscard() && mounted) {
      await _pop(
        _entrySaved
            ? QuickCaptureResult.partiallySaved
            : QuickCaptureResult.discarded,
      );
    }
  }

  Future<void> _pop(QuickCaptureResult result) async {
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _polish() async {
    if (!_canPolish) return;
    setState(() {
      _polishing = true;
      _error = null;
    });

    try {
      final result = await widget.onPolish!(
        _controller.text.trim(),
        widget.entryType,
      );
      if (!mounted) return;
      final tags = <String>[
        ...result.tags,
        ..._retainedHiddenTags.where((tag) => !result.tags.contains(tag)),
      ];
      setState(() {
        _controller.text = result.content;
        _selectedTags = tags;
        _controller.selection = TextSelection.collapsed(
          offset: result.content.length,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = PolisherService.readableError(error));
    } finally {
      if (mounted) setState(() => _polishing = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (!_entrySaved) {
        final entryId = _supportsPhotos && _hasPhotoChanges
            ? _entryId
            : widget.initialEntryId;
        await widget.onSave(
          QuickCaptureSubmission(
            content: _controller.text.trim(),
            tags: _selectedTags,
            time: _timeText,
            entryId: entryId,
            operationId: _operationId,
          ),
        );
        _entrySaved = true;
        await _clearDraft();
      }
      if (_supportsPhotos) await _savePhotoChanges();
      if (_supportsPhotos && _hasPendingPhotoOperations) {
        if (mounted) {
          setState(() => _error = '文字已保存，部分照片操作未完成，请重试');
        }
        return;
      }
      final repository = widget.draftRepository;
      final date = widget.recordDate;
      if (!_isEditing && repository != null && date != null && !_entrySaved) {
        await repository.clearDraft(date: date, entryType: widget.entryType);
      }
      if (!mounted) return;
      await _pop(QuickCaptureResult.saved);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _entrySaved
            ? '文字已保存，部分照片操作失败，请重试'
            : (_isEditing ? '更新失败，请重试' : '保存失败，请重试');
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearDraft() async {
    final repository = widget.draftRepository;
    final date = widget.recordDate;
    if (_isEditing || repository == null || date == null) return;
    await _draftWriteChain;
    await repository.clearDraft(date: date, entryType: widget.entryType);
  }

  Future<void> _pickPhotos() async {
    if (!_supportsPhotos || _entrySaved || _saving || _activePhotoCount >= 9) {
      return;
    }
    _focusNode.unfocus();
    final settings = await _loadImageSettings();
    final remaining = 9 - _activePhotoCount;
    final picked = widget.imagePicker != null
        ? await widget.imagePicker!(settings, remaining)
        : await _systemImagePicker.pickMultiImage(
            maxWidth: settings.maxLongSidePx.toDouble(),
            maxHeight: settings.maxLongSidePx.toDouble(),
            imageQuality: settings.initialQuality,
            limit: remaining,
          );
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _newPhotos.addAll(
        picked
            .take(remaining)
            .map(
              (file) =>
                  ImageUploadItem(id: ApiClient.generateUuidV4(), file: file),
            ),
      );
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_entryScrollController.hasClients) return;
      unawaited(
        _entryScrollController.animateTo(
          _entryScrollController.position.maxScrollExtent,
          duration: FloraMotion.standardFor(MediaQuery.of(context)),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  Future<ImageSettings> _loadImageSettings() {
    return (widget.imageSettingsRepository ?? _defaultImageSettingsRepository)
        .load();
  }

  Future<void> _savePhotoChanges() async {
    final apiClient = widget.apiClient;
    if (!_supportsPhotos || apiClient == null || !_hasPhotoChanges) return;

    for (final photo in widget.initialPhotos) {
      if (!_removedPhotoNames.contains(photo.filename) ||
          _completedPhotoRemovals.contains(photo.filename)) {
        continue;
      }
      final deleted = await apiClient.deleteEntry(
        _photoDate,
        section: 'images',
        line: photo.rawLine,
      );
      if (!deleted) throw Exception('移除已保存照片失败');
      _completedPhotoRemovals.add(photo.filename);
    }

    final settings = await _loadImageSettings();
    for (final item in _newPhotos) {
      if (item.status == ImageUploadStatus.success) continue;
      await _uploadPhoto(item, settings);
      if (item.status == ImageUploadStatus.failed) break;
    }
  }

  Future<void> _uploadPhoto(
    ImageUploadItem item,
    ImageSettings settings,
  ) async {
    final apiClient = widget.apiClient;
    if (apiClient == null) return;
    setState(() {
      item.status = ImageUploadStatus.preparing;
      item.sentBytes = 0;
      item.totalBytes = 0;
      item.errorMessage = null;
    });
    try {
      final bytes = await item.file.readAsBytes();
      final base64 =
          await (widget.imageCompressor?.call(bytes, settings) ??
              ImageCompressService.fromSettings(
                settings,
              ).compressToBase64InBackground(bytes));
      if (base64.length > 9 * 1024 * 1024) {
        throw Exception('图片压缩后仍过大，请在图片设置中降低尺寸或质量');
      }
      final result = await apiClient.uploadImage(
        _photoDate,
        base64,
        operationId: item.id,
        imagePrefix: settings.filenamePrefix,
        entryId: _entryId,
        onProgress: (sentBytes, totalBytes) {
          if (!mounted) return;
          setState(() {
            item.status = ImageUploadStatus.uploading;
            item.sentBytes = sentBytes;
            item.totalBytes = totalBytes;
          });
        },
      );
      if (result['filename'] is! String) throw Exception('照片保存结果无法确认，请重试');
      if (mounted) setState(() => item.status = ImageUploadStatus.success);
    } catch (error) {
      if (mounted) {
        setState(() {
          item.status = ImageUploadStatus.failed;
          item.errorMessage = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _retryPhoto(ImageUploadItem item) async {
    if (item.status != ImageUploadStatus.failed || _saving) return;
    final settings = await _loadImageSettings();
    await _uploadPhoto(item, settings);
    if (mounted && !_hasPendingPhotoOperations) {
      setState(() => _error = null);
    }
  }

  void _removePhotoUpload(ImageUploadItem item) {
    if (item.status != ImageUploadStatus.selected &&
        item.status != ImageUploadStatus.failed) {
      return;
    }
    setState(() => _newPhotos.remove(item));
  }

  void _toggleSavedPhotoRemoval(DiaryPhoto photo) {
    setState(() {
      if (!_removedPhotoNames.add(photo.filename)) {
        _removedPhotoNames.remove(photo.filename);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope<QuickCaptureResult>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_allowPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const FloraIcon(FloraIcons.back),
            onPressed: _handleBack,
          ),
          title: Text(_isEditing ? '编辑记录' : widget.entryType.label),
        ),
        body: _buildBody(theme),
        bottomNavigationBar: _buildSaveBar(theme, keyboardInset),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return SafeArea(
      top: false,
      bottom: true,
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _buildBodyContent(theme, constraints),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme, BoxConstraints constraints) {
    final tagPanelMaxHeight = math.min(240.0, constraints.maxHeight * 0.4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeMetadata(theme),
          const SizedBox(height: 8),
          Expanded(child: _buildScrollableEntry(theme)),
          if (_selectedTags.isNotEmpty) ...[
            TagSelectionSummary(
              tagConfig: widget.tagConfig,
              tags: _selectedTags,
              hiddenTags: _retainedHiddenTags,
            ),
            const SizedBox(height: 8),
          ],
          _buildToolbar(theme),
          _buildErrorMessage(theme),
          _buildExpandedTagPanel(theme, tagPanelMaxHeight),
        ],
      ),
    );
  }

  Widget _buildScrollableEntry(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        key: const Key('quick_capture_entry_scroll'),
        controller: _entryScrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.zero,
        children: [
          SizedBox(height: constraints.maxHeight, child: _buildEditor(theme)),
          if (_supportsPhotos) ...[
            const SizedBox(height: FloraSpacing.sm),
            EntryPhotoGrid(
              photos: widget.initialPhotos
                  .where(
                    (photo) =>
                        !_completedPhotoRemovals.contains(photo.filename),
                  )
                  .toList(growable: false),
              uploads: _newPhotos,
              removedPhotoNames: _removedPhotoNames,
              apiClient: widget.apiClient!,
              date: _photoDate,
              onAdd: !_entrySaved && _activePhotoCount < 9 ? _pickPhotos : null,
              onTogglePhotoRemoval: _entrySaved
                  ? null
                  : _toggleSavedPhotoRemoval,
              onRetryUpload: _retryPhoto,
              onRemoveUpload: _entrySaved ? null : _removePhotoUpload,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorMessage(ThemeData theme) {
    final error = _error;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        key: const Key('quick_capture_error'),
        error,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildExpandedTagPanel(ThemeData theme, double maxHeight) {
    if (!_tagPickerExpanded || widget.tagConfig == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const Key('quick_capture_tag_panel'),
      padding: const EdgeInsets.only(top: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: IgnorePointer(
            ignoring: _saving || _polishing || _entrySaved,
            child: Opacity(
              opacity: _saving || _polishing || _entrySaved ? 0.55 : 1,
              child: _buildTagArea(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveBar(ThemeData theme, double keyboardInset) {
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : Text(
                    _entrySaved
                        ? (_hasPendingPhotoOperations ? '重试照片' : '完成')
                        : '保存',
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(ThemeData theme) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: _shouldAutofocus,
      expands: true,
      minLines: null,
      maxLines: null,
      enabled: !_saving && !_polishing && !_entrySaved,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
      decoration: InputDecoration(
        hintText: widget.entryType.placeholder,
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.6,
        ),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return SizedBox(
      key: const Key('quick_capture_toolbar'),
      height: 48,
      child: Row(
        children: [
          TextButton(
            key: const Key('quick_capture_polish'),
            onPressed: _canPolish ? _polish : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: theme.colorScheme.primary,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_polishing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  const FloraIcon(FloraIcons.coach, size: 14),
                const SizedBox(width: 6),
                const Text('润色'),
              ],
            ),
          ),
          const Spacer(),
          if (_supportsPhotos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                key: const Key('quick_capture_add_photo'),
                onPressed:
                    !_entrySaved &&
                        !_saving &&
                        !_polishing &&
                        _activePhotoCount < 9
                    ? _pickPhotos
                    : null,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FloraIcon(FloraIcons.fabPhoto, size: 16),
                    const SizedBox(width: 4),
                    Text('照片 $_activePhotoCount/9'),
                  ],
                ),
              ),
            ),
          if (widget.tagConfig != null) _buildTagToggleButton(theme),
        ],
      ),
    );
  }

  Widget _buildTagToggleButton(ThemeData theme) {
    return Semantics(
      button: true,
      toggled: _tagPickerExpanded,
      label: _tagPickerExpanded ? '收起标签' : '展开标签',
      child: TextButton(
        key: const Key('quick_capture_tag_toggle'),
        onPressed: _saving || _polishing || _entrySaved
            ? null
            : _toggleTagPicker,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: theme.colorScheme.onSurfaceVariant,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FloraIcon(FloraIcons.settingTags, size: 16),
            const SizedBox(width: 4),
            Text(_tagPickerExpanded ? '收起标签' : '标签'),
            const SizedBox(width: 2),
            FloraIcon(
              _tagPickerExpanded
                  ? FloraIcons.chevronUp
                  : FloraIcons.chevronDown,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleTagPicker() {
    FocusScope.of(context).unfocus();
    setState(() => _tagPickerExpanded = !_tagPickerExpanded);
  }

  Widget _buildTimeMetadata(ThemeData theme) {
    final date = widget.recordDate;
    final today = DateTime.now();
    final isToday =
        date == null ||
        (date.year == today.year &&
            date.month == today.month &&
            date.day == today.day);
    final dateText = isToday ? '今天' : '${date.year}年${date.month}月${date.day}日';
    final value = '$dateText $_timeText';
    return Semantics(
      button: true,
      label: '记录时间，$value，点击修改',
      child: InkWell(
        key: const Key('quick_capture_time_metadata'),
        onTap: _saving || _entrySaved ? null : _pickTime,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              FloraIcon(
                FloraIcons.clock,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              FloraIcon(
                FloraIcons.chevronRight,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagArea(ThemeData theme) {
    final tagConfig = (widget.tagConfig != null && widget.tagSettings != null)
        ? TagSettingsHelper.effectiveTagConfig(
            widget.tagConfig!,
            widget.tagSettings!,
          )
        : widget.tagConfig;
    if (tagConfig != null) {
      return TagPicker(
        tagConfig: tagConfig,
        initialTags: _selectedTags,
        showSummary: false,
        hiddenInitialTags: _retainedHiddenTags,
        forceExpanded: true,
        onChanged: (tags) {
          setState(() {
            _selectedTags = tags;
            _retainedHiddenTags = _retainedHiddenTags
                .where(tags.contains)
                .toList(growable: false);
          });
          _saveDraft();
        },
      );
    }
    return const SizedBox.shrink();
  }
}
