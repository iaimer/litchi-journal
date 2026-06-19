import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'flora_icon.dart';

import '../models/diary_document.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../theme/app_theme.dart';
import 'entry_edit_sheet.dart';
import 'section_card.dart';

final _questionHint = RegExp(r'[？?]$|吗[？?]?$');

class GenericSectionCard extends StatelessWidget {
  final DiarySection section;
  final Future<void> Function(String rawLine)? onTimelineDelete;
  final Future<void> Function(
      String rawLine, String content, List<String> tags)? onTimelineEdit;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;

  const GenericSectionCard({
    super.key,
    required this.section,
    this.onTimelineDelete,
    this.onTimelineEdit,
    this.tagConfig,
    this.tagSettings,
  });

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) return const SizedBox.shrink();

    // 小确幸：全部走专用渲染（单条纯文本，多条 bullet list，不用 Timeline）
    if (section is HappinessSection) {
      return _buildHappinessSection(context, section);
    }

    final children = <Widget>[];
    if (_hasCollapsibleCallout(section)) {
      children.add(_buildCollapsedCallout(context, section));
    } else {
      for (int i = 0; i < section.contents.length; i++) {
        final content = section.contents[i];
        if (content is SubSectionContent) {
          if (_subSectionHasContent(section.contents, i)) {
            children.add(_buildSubSectionHeader(context, content.title));
          }
        } else {
          if (_isHappinessSlogan(section, content)) continue;
          _buildContent(context, content, children);
        }
      }
    }

    return SectionCard(
      title: section.title.isEmpty ? null : section.title,
      accentColor: AppColors.primary,
      children: children,
    );
  }

  static bool _subSectionHasContent(List<DiaryContent> contents, int from) {
    for (int i = from + 1; i < contents.length; i++) {
      final next = contents[i];
      if (next is SubSectionContent) break;
      if (next.hasRealContent) return true;
    }
    return false;
  }

  static bool _hasCollapsibleCallout(DiarySection section) {
    if (section.contents.length != 1) return false;
    final content = section.contents.first;
    if (content is! CalloutContent) return false;
    if (content.body.isNotEmpty) return false;
    return _questionHint.hasMatch(content.title);
  }

  static bool _isHappinessSlogan(DiarySection section, DiaryContent content) {
    if (section is! HappinessSection) return false;
    if (content is! CalloutContent) return false;
    if (content.body.isNotEmpty) return false;
    if (content.type != 'success') return false;
    return content.title.contains('值得感恩');
  }

  void _buildContent(
    BuildContext context,
    DiaryContent content,
    List<Widget> widgets,
  ) {
    switch (content) {
      case CalloutContent():
        widgets.add(_buildCallout(context, content));
      case CheckboxContent():
        widgets.add(_buildCheckbox(context, content));
      case TimelineContent():
        widgets.add(
          _TimelineDeleteRow(
            content: content,
            onDelete: onTimelineDelete,
            onEdit: onTimelineEdit,
            tagConfig: tagConfig,
            tagSettings: tagSettings,
          ),
        );
      case MarkdownContent():
        widgets.add(
          MarkdownBody(
            data: content.text,
            selectable: true,
            styleSheet: _baseStyleSheet(context),
          ),
        );
      case SubSectionContent():
        break;
      default:
        break;
    }
  }

  MarkdownStyleSheet _baseStyleSheet(BuildContext context, {Color? textColor}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quoteTextColor = textColor ?? theme.colorScheme.onSurface;
    final quoteBackground = isDark
        ? theme.colorScheme.primary.withAlpha(24)
        : Colors.blue.shade50;
    final quoteBorderColor = isDark
        ? theme.colorScheme.primary.withAlpha(120)
        : Colors.blue.shade200;
    var sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      p: theme.textTheme.bodyMedium,
      listBullet: theme.textTheme.bodyMedium,
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: quoteTextColor,
        height: 1.6,
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      blockquoteDecoration: BoxDecoration(
        color: quoteBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: quoteBorderColor, width: 3)),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
    );
    if (textColor != null) {
      sheet = sheet.copyWith(
        p: sheet.p?.copyWith(color: textColor),
        h1: sheet.h1?.copyWith(color: textColor),
        h2: sheet.h2?.copyWith(color: textColor),
        h3: sheet.h3?.copyWith(color: textColor),
      );
    }
    return sheet;
  }

  Widget _buildSubSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCallout(BuildContext context, CalloutContent content) {
    final theme = Theme.of(context);
    final (icon, color, bgColor) = _calloutStyle(theme, content.type);

    final bodyText = content.body.join('\n');
    final hasBody = bodyText.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.title.isNotEmpty)
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: MarkdownBody(
                    data: content.title,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      blockSpacing: 0,
                      p: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      strong: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (hasBody) ...[
            if (content.title.isNotEmpty) const SizedBox(height: 4),
            MarkdownBody(
              data: bodyText,
              selectable: true,
              styleSheet: _baseStyleSheet(context, textColor: color),
            ),
          ],
        ],
      ),
    );
  }

  /// 小确幸专用渲染：单条纯文本，多条 bullet list，不用 Timeline。
  Widget _buildHappinessSection(
      BuildContext context, DiarySection section) {
    final theme = Theme.of(context);
    final entries = section.contents
        .whereType<TimelineContent>()
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    if (entries.length == 1) {
      // 单条：纯文本段落
      final content = entries.first;
      return SectionCard(
        title: section.title.isEmpty ? null : section.title,
        accentColor: AppColors.primary,
        children: [
          Text(
            content.text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          if (content.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                content.tags.join(' '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary.withAlpha(180),
                  fontSize: 11,
                ),
              ),
            ),
        ],
      );
    }

    // 多条：bullet list
    return SectionCard(
      title: section.title.isEmpty ? null : section.title,
      accentColor: AppColors.primary,
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Text(
                  '•',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.text,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                    if (entry.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          entry.tags.join(' '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary.withAlpha(180),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCollapsedCallout(BuildContext context, DiarySection section) {
    final content = section.contents.first as CalloutContent;
    final theme = Theme.of(context);
    final (icon, color, bgColor) = _calloutStyle(theme, content.type);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: MarkdownBody(
              data: content.title,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                blockSpacing: 0,
                p: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontStyle: FontStyle.italic,
                ),
                strong: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context, CheckboxContent content) {
    return _buildCheckRow(context, content.checked, content.text);
  }

  Widget _buildCheckRow(BuildContext context, bool checked, String text) {
    final theme = Theme.of(context);
    final icon = checked ? Icons.check_box : Icons.check_box_outline_blank;
    final color = checked ? AppColors.success : theme.disabledColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, Color) _calloutStyle(ThemeData theme, String type) {
    final isDark = theme.brightness == Brightness.dark;
    switch (type) {
      case 'quote':
        return (
          Icons.format_quote,
          isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          isDark ? Colors.grey.shade800.withAlpha(100) : Colors.grey.shade50,
        );
      case 'tip':
        return (
          Icons.lightbulb_outline,
          isDark ? Colors.teal.shade200 : Colors.teal.shade700,
          isDark ? Colors.teal.shade800.withAlpha(100) : Colors.teal.shade50,
        );
      case 'note':
      case 'info':
        return (
          Icons.info_outline,
          isDark ? Colors.blue.shade200 : Colors.blue.shade700,
          isDark ? Colors.blue.shade800.withAlpha(100) : Colors.blue.shade50,
        );
      case 'warning':
      case 'caution':
        return (
          Icons.warning_amber_rounded,
          isDark ? Colors.orange.shade200 : Colors.orange.shade700,
          isDark
              ? Colors.orange.shade800.withAlpha(100)
              : Colors.orange.shade50,
        );
      case 'danger':
      case 'error':
        return (
          Icons.error_outline,
          isDark ? Colors.red.shade200 : Colors.red.shade700,
          isDark ? Colors.red.shade800.withAlpha(100) : Colors.red.shade50,
        );
      case 'success':
      case 'done':
        return (
          Icons.check_circle_outline,
          isDark ? Colors.green.shade200 : Colors.green.shade700,
          isDark ? Colors.green.shade800.withAlpha(100) : Colors.green.shade50,
        );
      case 'example':
        return (
          Icons.code,
          isDark ? Colors.purple.shade200 : Colors.purple.shade700,
          isDark
              ? Colors.purple.shade800.withAlpha(100)
              : Colors.purple.shade50,
        );
      default:
        return (
          Icons.info_outline,
          isDark ? Colors.blue.shade200 : Colors.blue.shade700,
          isDark ? Colors.blue.shade800.withAlpha(100) : Colors.blue.shade50,
        );
    }
  }
}

class _TimelineDeleteRow extends StatefulWidget {
  final TimelineContent content;
  final Future<void> Function(String rawLine)? onDelete;
  final Future<void> Function(
      String rawLine, String content, List<String> tags)? onEdit;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;

  const _TimelineDeleteRow({
    required this.content,
    this.onDelete,
    this.onEdit,
    this.tagConfig,
    this.tagSettings,
  });

  @override
  State<_TimelineDeleteRow> createState() => _TimelineDeleteRowState();
}

class _TimelineDeleteRowState extends State<_TimelineDeleteRow> {
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
      await widget.onDelete!(widget.content.rawLine);
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
        initialContent: widget.content.text,
        initialTags: widget.content.tags,
        tagConfig: widget.tagConfig,
        tagSettings: widget.tagSettings,
        onSave: (content, tags) async {
          await widget.onEdit!(
              widget.content.rawLine, content, tags);
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
                widget.content.time,
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
                    widget.content.text,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (widget.content.tags.isNotEmpty ||
                      _showActions ||
                      _busy)
                    Row(
                      children: [
                        if (widget.content.tags.isNotEmpty)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.content.tags.join(' '),
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
                                _TimelineAction>(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              icon: const FloraIcon(FloraIcons.more, size: 16),
                              onSelected: (action) {
                              if (action ==
                                  _TimelineAction.delete) {
                                _confirmDelete();
                              } else if (action ==
                                  _TimelineAction.edit) {
                                _openEdit();
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: _TimelineAction.edit,
                                child: Text('编辑'),
                              ),
                              const PopupMenuItem(
                                value: _TimelineAction.delete,
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

enum _TimelineAction { edit, delete }
