import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../theme/app_theme.dart';
import 'section_card.dart';

class QuickNoteTimeline extends StatelessWidget {
  final QuickNoteSection section;
  final Future<void> Function(QuickNoteItem note)? onDelete;

  const QuickNoteTimeline({
    super.key,
    required this.section,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (section.notes.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: section.title,
      accentColor: AppColors.primary,
      children: section.notes
          .map((note) => _QuickNoteRow(note: note, onDelete: onDelete))
          .toList(growable: false),
    );
  }
}

class _QuickNoteRow extends StatefulWidget {
  final QuickNoteItem note;
  final Future<void> Function(QuickNoteItem note)? onDelete;

  const _QuickNoteRow({required this.note, this.onDelete});

  @override
  State<_QuickNoteRow> createState() => _QuickNoteRowState();
}

class _QuickNoteRowState extends State<_QuickNoteRow> {
  bool _deleting = false;

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

    setState(() => _deleting = true);
    try {
      await widget.onDelete!(widget.note);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
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
                  if (widget.note.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.note.tags.join(' '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              theme.colorScheme.primary.withAlpha(180),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.onDelete != null && !_deleting)
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: const Icon(Icons.more_horiz, size: 16),
                  padding: EdgeInsets.zero,
                  onPressed: _confirmDelete,
                ),
              ),
            if (_deleting)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child:
                      CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
