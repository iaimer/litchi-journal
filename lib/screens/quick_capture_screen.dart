import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/draft_repository.dart';
import '../services/polisher_service.dart';
import '../services/tag_settings_helper.dart';
import '../widgets/flora_icon.dart';

import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../widgets/entry_type.dart';
import '../widgets/tag_picker.dart';

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
  final Future<TimeOfDay?> Function(
    BuildContext context,
    TimeOfDay initialTime,
  )?
  timePicker;
  final Future<PolishResult> Function(String content, EntryType entryType)?
  onPolish;
  final Future<void> Function(String content, List<String> tags, String time)
  onSave;

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
    this.timePicker,
    this.onPolish,
  }) : assert(entryType != EntryType.anxiety);

  @override
  State<QuickCaptureScreen> createState() => _QuickCaptureScreenState();
}

class _QuickCaptureScreenState extends State<QuickCaptureScreen> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  late TimeOfDay _selectedTime;
  late final String _initialContent;
  late final String _initialTime;
  late final List<String> _initialTags;
  late List<String> _retainedHiddenTags;
  late List<String> _selectedTags;
  bool _saving = false;
  bool _polishing = false;
  bool _allowPop = false;
  bool _tagPickerExpanded = false;
  bool _restoringDraft = false;
  String? _error;

  /// 草稿写入串行链，避免保存与清空竞争导致残留。
  Future<void> _draftWriteChain = Future.value();

  bool get _isEditing => widget.initialContent != null;

  bool get _shouldAutofocus => !_isEditing && widget.recordDate == null;

  bool get _hasUnsavedChanges {
    if (!_isEditing) {
      return _controller.text.trim().isNotEmpty || _selectedTags.isNotEmpty;
    }
    return _controller.text != _initialContent ||
        _timeText != _initialTime ||
        !_sameTags(_selectedTags, _initialTags);
  }

  bool get _canSave =>
      !_saving && !_polishing && _controller.text.trim().isNotEmpty;

  bool get _canPolish =>
      !_saving &&
      !_polishing &&
      _controller.text.trim().isNotEmpty &&
      widget.onPolish != null;

  @override
  void initState() {
    super.initState();
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
    FocusScope.of(context).unfocus();
    final picker = widget.timePicker;
    final picked = picker != null
        ? await picker(context, _selectedTime)
        : await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked == null || !mounted) return;
    setState(() => _selectedTime = picked);
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃记录？'),
        content: const Text('当前内容还没有保存，确定要离开吗？'),
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
      await _pop(false);
    }
  }

  Future<void> _pop(bool result) async {
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
      await widget.onSave(_controller.text.trim(), _selectedTags, _timeText);
      final repository = widget.draftRepository;
      final date = widget.recordDate;
      if (!_isEditing && repository != null && date != null) {
        await _draftWriteChain;
        await repository.clearDraft(date: date, entryType: widget.entryType);
      }
      if (!mounted) return;
      await _pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = _isEditing ? '更新失败，请重试' : '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope<bool>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_allowPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
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
          Expanded(child: _buildEditor(theme)),
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
            ignoring: _saving || _polishing,
            child: Opacity(
              opacity: _saving || _polishing ? 0.55 : 1,
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
                : const Text('保存'),
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
      enabled: !_saving && !_polishing,
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
        onPressed: _saving || _polishing ? null : _toggleTagPicker,
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
            Icon(
              _tagPickerExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
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
        onTap: _saving ? null : _pickTime,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
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
              Icon(
                Icons.chevron_right_rounded,
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
