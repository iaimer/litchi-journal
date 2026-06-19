import 'package:flutter/material.dart';

import 'flora_icon.dart';

import '../models/diary_document.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../theme/app_theme.dart';
import 'entry_edit_sheet.dart';
import 'section_card.dart';

class QuickNoteTimeline extends StatelessWidget {
  final QuickNoteSection section;
  final Future<void> Function(QuickNoteItem note)? onDelete;
  final Future<void> Function(
      QuickNoteItem note, String content, List<String> tags)? onEdit;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;

  const QuickNoteTimeline({
    super.key,
    required this.section,
    this.onDelete,
    this.onEdit,
    this.tagConfig,
    this.tagSettings,
  });

  @override
  Widget build(BuildContext context) {
    if (section.notes.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: section.title,
      accentColor: AppColors.primary,
      children: section.notes
          .map((note) => _QuickNoteRow(
                note: note,
                onDelete: onDelete,
                onEdit: onEdit,
                tagConfig: tagConfig,
                tagSettings: tagSettings,
              ))
          .toList(growable: false),
    );
  }
}

class _QuickNoteRow extends StatefulWidget {
  final QuickNoteItem note;
  final Future<void> Function(QuickNoteItem note)? onDelete;
  final Future<void> Function(
      QuickNoteItem note, String content, List<String> tags)? onEdit;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;

  const _QuickNoteRow({
    required this.note,
    this.onDelete,
    this.onEdit,
    this.tagConfig,
    this.tagSettings,
  });

  @override
  State<_QuickNoteRow> createState() => _QuickNoteRowState();
}

class _QuickNoteRowState extends State<_QuickNoteRow> {
  bool _busy = false;

  bool get _showActions =>
      (widget.onEdit != null || widget.onDelete != null) && !_busy;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定删除这条记录吗？'),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openEdit() {
    if (widget.onEdit == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EntryEditSheet(
        initialContent: widget.note.content,
        initialTags: widget.note.tags,
        tagConfig: widget.tagConfig,
        tagSettings: widget.tagSettings,
        onSave: (content, tags) async {
          await widget.onEdit!(widget.note, content, tags);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Text(
                widget.note.time,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: 2,
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(60),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.note.content,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (widget.note.tags.isNotEmpty ||
                      _showActions ||
                      _busy)
                    Row(
                      children: [
                        if (widget.note.tags.isNotEmpty)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.note.tags.join(' '),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(
                                  color: theme.colorScheme.primary
                                      .withAlpha(180),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        if (_showActions)
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: PopupMenuButton<
                                _QuickNoteAction>(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              icon: const FloraIcon(FloraIcons.more,
                                  size: 16),
                              onSelected: (action) {
                              if (action == _QuickNoteAction.delete) {
                                _confirmDelete();
                              } else if (action ==
                                  _QuickNoteAction.edit) {
                                _openEdit();
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: _QuickNoteAction.edit,
                                child: Text('编辑'),
                              ),
                              const PopupMenuItem(
                                value: _QuickNoteAction.delete,
                                child: Text('删除'),
                              ),
                            ],
                          ),
                          ),
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _QuickNoteAction { edit, delete }
