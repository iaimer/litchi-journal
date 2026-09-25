import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../services/api_client.dart';
import '../screens/quick_capture_screen.dart';
import 'entry_type.dart';
import 'journal_section.dart';
import 'timeline_action_sheet.dart';
import 'entry_photo_grid.dart';

class QuickNoteTimeline extends StatelessWidget {
  final QuickNoteSection section;
  final Color? accentColor;
  final Future<void> Function(QuickNoteItem note)? onDelete;
  final Future<void> Function(
    QuickNoteItem note,
    String content,
    List<String> tags,
    String time,
  )?
  onEdit;
  final Future<void> Function(
    QuickNoteItem note,
    String content,
    List<String> tags,
    String time,
    String? entryId,
  )?
  onEditWithEntryId;
  final Future<void> Function()? onEditCompleted;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;
  final DateTime? recordDate;
  final Future<PolishResult> Function(String content, EntryType entryType)?
  onPolish;
  final ApiClient? apiClient;
  final QuickCaptureImagePicker? imagePicker;
  final QuickCaptureImageCompressor? imageCompressor;

  const QuickNoteTimeline({
    super.key,
    required this.section,
    this.accentColor,
    this.onDelete,
    this.onEdit,
    this.onEditWithEntryId,
    this.onEditCompleted,
    this.tagConfig,
    this.tagSettings,
    this.recordDate,
    this.onPolish,
    this.apiClient,
    this.imagePicker,
    this.imageCompressor,
  });

  @override
  Widget build(BuildContext context) {
    if (section.notes.isEmpty) return const SizedBox.shrink();

    return JournalSection(
      title: '随手记',
      accentColor: accentColor ?? Theme.of(context).colorScheme.primary,
      children: [
        for (var index = 0; index < section.notes.length; index++)
          _QuickNoteRow(
            note: section.notes[index],
            isFirst: index == 0,
            isLast: index == section.notes.length - 1,
            onDelete: onDelete,
            onEdit: onEdit,
            onEditWithEntryId: onEditWithEntryId,
            onEditCompleted: onEditCompleted,
            tagConfig: tagConfig,
            tagSettings: tagSettings,
            accentColor: accentColor,
            recordDate: recordDate,
            onPolish: onPolish,
            apiClient: apiClient,
            imagePicker: imagePicker,
            imageCompressor: imageCompressor,
          ),
      ],
    );
  }
}

class _QuickNoteRow extends StatefulWidget {
  final QuickNoteItem note;
  final bool isFirst;
  final bool isLast;
  final Future<void> Function(QuickNoteItem note)? onDelete;
  final Future<void> Function(
    QuickNoteItem note,
    String content,
    List<String> tags,
    String time,
  )?
  onEdit;
  final Future<void> Function(
    QuickNoteItem note,
    String content,
    List<String> tags,
    String time,
    String? entryId,
  )?
  onEditWithEntryId;
  final Future<void> Function()? onEditCompleted;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;
  final Color? accentColor;
  final DateTime? recordDate;
  final Future<PolishResult> Function(String content, EntryType entryType)?
  onPolish;
  final ApiClient? apiClient;
  final QuickCaptureImagePicker? imagePicker;
  final QuickCaptureImageCompressor? imageCompressor;

  const _QuickNoteRow({
    required this.note,
    required this.isFirst,
    required this.isLast,
    this.onDelete,
    this.onEdit,
    this.onEditWithEntryId,
    this.onEditCompleted,
    this.tagConfig,
    this.tagSettings,
    this.accentColor,
    this.recordDate,
    this.onPolish,
    this.apiClient,
    this.imagePicker,
    this.imageCompressor,
  });

  @override
  State<_QuickNoteRow> createState() => _QuickNoteRowState();
}

class _QuickNoteRowState extends State<_QuickNoteRow> {
  bool _busy = false;

  bool get _showActions =>
      (widget.onEdit != null ||
          widget.onEditWithEntryId != null ||
          widget.onDelete != null) &&
      !_busy;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          widget.note.photos.isEmpty
              ? '确定删除这条记录吗？'
              : '同时删除关联的 ${widget.note.photos.length} 张照片，确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (widget.onDelete == null) return;

    setState(() => _busy = true);
    try {
      await widget.onDelete!(widget.note);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEdit() async {
    if (widget.onEdit == null && widget.onEditWithEntryId == null) return;
    final result = await Navigator.of(context).push<QuickCaptureResult>(
      MaterialPageRoute(
        builder: (_) => QuickCaptureScreen(
          entryType: EntryType.quickNote,
          openedAt: DateTime.now(),
          recordDate: widget.recordDate,
          initialContent: widget.note.content,
          initialTime: widget.note.time,
          initialTags: widget.note.tags,
          initialEntryId: widget.note.entryId,
          initialPhotos: widget.note.photos,
          apiClient: widget.apiClient,
          photoDate: widget.recordDate,
          imagePicker: widget.imagePicker,
          imageCompressor: widget.imageCompressor,
          tagConfig: widget.tagConfig,
          tagSettings: widget.tagSettings,
          onPolish: widget.onPolish,
          onSave: (submission) {
            final save = widget.onEditWithEntryId;
            if (save != null) {
              return save(
                widget.note,
                submission.content,
                submission.tags,
                submission.time,
                submission.entryId,
              );
            }
            return widget.onEdit!(
              widget.note,
              submission.content,
              submission.tags,
              submission.time,
            );
          },
        ),
      ),
    );
    if (!mounted || result == null || result == QuickCaptureResult.discarded) {
      return;
    }
    await widget.onEditCompleted?.call();
  }

  Future<void> _openActions() async {
    if (!_showActions) return;
    final action = await showTimelineActionSheet(
      context,
      showEdit: widget.onEdit != null || widget.onEditWithEntryId != null,
      showDelete: widget.onDelete != null,
    );
    if (!mounted) return;
    switch (action) {
      case TimelineAction.edit:
        _openEdit();
      case TimelineAction.delete:
        _confirmDelete();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.accentColor ?? theme.colorScheme.primary;

    return JournalTimelineRow(
      time: widget.note.time,
      content: widget.note.content,
      tags: widget.note.tags,
      accentColor: accentColor,
      tagConfig: widget.tagConfig,
      isFirst: widget.isFirst,
      isLast: widget.isLast,
      trailing: (_showActions || _busy)
          ? JournalEntryActionSlot(
              alignToTags: widget.note.tags.isNotEmpty,
              attachmentAboveTags:
                  widget.note.photos.isNotEmpty &&
                  widget.apiClient != null &&
                  widget.recordDate != null,
              busy: _busy,
              onPressed: _showActions ? _openActions : null,
            )
          : null,
      attachment:
          widget.note.photos.isNotEmpty &&
              widget.apiClient != null &&
              widget.recordDate != null
          ? EntryPhotoGrid(
              photos: widget.note.photos,
              uploads: const [],
              removedPhotoNames: const {},
              apiClient: widget.apiClient!,
              date: widget.recordDate!,
            )
          : null,
    );
  }
}
