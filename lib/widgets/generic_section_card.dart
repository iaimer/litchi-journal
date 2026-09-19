import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/diary_document.dart';
import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../screens/quick_capture_screen.dart';
import '../theme/app_theme.dart';
import 'entry_type.dart';
import 'diary_section_title.dart';
import 'flora_icon.dart';
import 'journal_section.dart';
import 'section_card.dart';
import 'tag_color_helper.dart';
import 'timeline_action_sheet.dart';

final _questionHint = RegExp(r'[？?]$|吗[？?]?$');

class GenericSectionCard extends StatelessWidget {
  final DiarySection section;
  final Color? accentColor;
  final Future<void> Function(String rawLine)? onTimelineDelete;
  final Future<void> Function(
    String rawLine,
    String content,
    List<String> tags,
    String time,
  )?
  onTimelineEdit;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;
  final DateTime? recordDate;
  final Future<PolishResult> Function(String content, EntryType entryType)?
  onPolish;

  const GenericSectionCard({
    super.key,
    required this.section,
    this.accentColor,
    this.onTimelineDelete,
    this.onTimelineEdit,
    this.tagConfig,
    this.tagSettings,
    this.recordDate,
    this.onPolish,
  });

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) return const SizedBox.shrink();

    // 小确幸：全部走专用渲染（单条纯文本，多条 bullet list，不用 Timeline）
    if (section is HappinessSection) {
      return _buildHappinessSection(context, section);
    }

    final journalLayout = section is ReviewSection;
    final timelineCount = section.contents.whereType<TimelineContent>().length;
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
          _buildContent(
            context,
            content,
            children,
            journalLayout: journalLayout,
            timelineCount: timelineCount,
          );
        }
      }
    }

    final effectiveAccent =
        accentColor ?? Theme.of(context).colorScheme.primary;
    final displayTitle = diarySectionDisplayTitle(section);
    if (journalLayout) {
      return JournalSection(
        title: displayTitle,
        accentColor: effectiveAccent,
        children: children,
      );
    }
    return SectionCard(
      title: displayTitle.isEmpty ? null : displayTitle,
      accentColor: effectiveAccent,
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
    List<Widget> widgets, {
    required bool journalLayout,
    required int timelineCount,
  }) {
    switch (content) {
      case CalloutContent():
        widgets.add(_buildCallout(context, content));
      case CheckboxContent():
        widgets.add(_buildCheckbox(context, content));
      case TimelineContent():
        widgets.add(
          _EditableEntryRow(
            content: content,
            onDelete: onTimelineDelete,
            onEdit: onTimelineEdit,
            tagConfig: tagConfig,
            tagSettings: tagSettings,
            accentColor: accentColor,
            recordDate: recordDate,
            entryType: _entryTypeForSection(section),
            onPolish: onPolish,
            journalLayout: journalLayout,
            showBullet: journalLayout && timelineCount > 1,
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

  EntryType? _entryTypeForSection(DiarySection section) {
    if (section is ReviewSection) return EntryType.reflection;
    if (section is HappinessSection) return EntryType.happiness;
    return null;
  }

  MarkdownStyleSheet _baseStyleSheet(BuildContext context, {Color? textColor}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quoteAccentColor = accentColor ?? theme.colorScheme.primary;
    final quoteTextColor =
        textColor ?? _readableAccentText(quoteAccentColor, isDark);
    final quoteBackground = quoteAccentColor.withAlpha(isDark ? 26 : 18);
    final quoteBorderColor = quoteAccentColor.withAlpha(isDark ? 120 : 92);
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
        borderRadius: BorderRadius.circular(FloraRadius.sm),
        border: Border(left: BorderSide(color: quoteBorderColor, width: 1)),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
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

  Color _readableAccentText(Color color, bool isDark) {
    final hsl = HSLColor.fromColor(color);
    final lightness = isDark
        ? hsl.lightness.clamp(0.72, 0.86).toDouble()
        : hsl.lightness.clamp(0.26, 0.36).toDouble();
    return hsl.withLightness(lightness).toColor();
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
        borderRadius: BorderRadius.circular(FloraRadius.sm),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.title.isNotEmpty)
            Row(
              children: [
                FloraIcon(icon, size: 16, color: color),
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

  /// 小确幸专用渲染：单条无圆点，多条使用 bullet，并复用可编辑条目行。
  Widget _buildHappinessSection(BuildContext context, DiarySection section) {
    final theme = Theme.of(context);
    final entries = section.contents.whereType<TimelineContent>().toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    final effectiveAccent = accentColor ?? theme.colorScheme.primary;
    return JournalSection(
      title: '小确幸',
      accentColor: effectiveAccent,
      children: [
        for (final entry in entries)
          _EditableEntryRow(
            content: entry,
            onDelete: onTimelineDelete,
            onEdit: onTimelineEdit,
            tagConfig: tagConfig,
            tagSettings: tagSettings,
            accentColor: effectiveAccent,
            recordDate: recordDate,
            entryType: EntryType.happiness,
            onPolish: onPolish,
            journalLayout: true,
            showBullet: entries.length > 1,
          ),
      ],
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
        borderRadius: BorderRadius.circular(FloraRadius.sm),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          FloraIcon(icon, size: 16, color: color),
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
    final icon = checked
        ? FloraIcons.checkboxChecked
        : FloraIcons.checkboxUnchecked;
    final color = checked ? AppColors.success : theme.disabledColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FloraIcon(icon, size: 20, color: color),
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

  (String, Color, Color) _calloutStyle(ThemeData theme, String type) {
    final isDark = theme.brightness == Brightness.dark;
    Color softBackground(Color color) {
      return Color.alphaBlend(
        color.withAlpha(isDark ? 42 : 24),
        theme.colorScheme.surfaceContainerHighest,
      );
    }

    final calloutColors =
        theme.extension<AppCalloutColors>() ??
        (isDark ? AppCalloutColors.dark : AppCalloutColors.light);

    switch (type) {
      case 'quote':
        final color = theme.colorScheme.onSurfaceVariant;
        return (FloraIcons.calloutQuote, color, softBackground(color));
      case 'tip':
        final color = theme.colorScheme.primary;
        return (FloraIcons.calloutTip, color, softBackground(color));
      case 'note':
      case 'info':
        return (
          FloraIcons.calloutInfo,
          calloutColors.info,
          softBackground(calloutColors.info),
        );
      case 'warning':
      case 'caution':
        return (
          FloraIcons.calloutWarning,
          calloutColors.warning,
          softBackground(calloutColors.warning),
        );
      case 'danger':
      case 'error':
        return (
          FloraIcons.calloutError,
          theme.colorScheme.error,
          softBackground(theme.colorScheme.error),
        );
      case 'success':
      case 'done':
        return (
          FloraIcons.calloutSuccess,
          calloutColors.success,
          softBackground(calloutColors.success),
        );
      case 'example':
        return (
          FloraIcons.calloutCode,
          calloutColors.example,
          softBackground(calloutColors.example),
        );
      default:
        return (
          FloraIcons.calloutInfo,
          calloutColors.info,
          softBackground(calloutColors.info),
        );
    }
  }
}

class _EditableEntryRow extends StatefulWidget {
  final TimelineContent content;
  final Future<void> Function(String rawLine)? onDelete;
  final Future<void> Function(
    String rawLine,
    String content,
    List<String> tags,
    String time,
  )?
  onEdit;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;
  final Color? accentColor;
  final DateTime? recordDate;
  final EntryType? entryType;
  final Future<PolishResult> Function(String content, EntryType entryType)?
  onPolish;
  final bool journalLayout;
  final bool showBullet;

  const _EditableEntryRow({
    required this.content,
    this.onDelete,
    this.onEdit,
    this.tagConfig,
    this.tagSettings,
    this.accentColor,
    this.recordDate,
    this.entryType,
    this.onPolish,
    this.journalLayout = false,
    this.showBullet = false,
  });

  @override
  State<_EditableEntryRow> createState() => _EditableEntryRowState();
}

class _EditableEntryRowState extends State<_EditableEntryRow> {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openEdit() {
    final entryType = widget.entryType;
    if (widget.onEdit == null || entryType == null) return;
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickCaptureScreen(
          entryType: entryType,
          openedAt: DateTime.now(),
          recordDate: widget.recordDate,
          initialContent: widget.content.text,
          initialTime: widget.content.time,
          initialTags: widget.content.tags,
          tagConfig: widget.tagConfig,
          tagSettings: widget.tagSettings,
          onPolish: widget.onPolish,
          onSave: (content, tags, time) =>
              widget.onEdit!(widget.content.rawLine, content, tags, time),
        ),
      ),
    );
  }

  Future<void> _openActions() async {
    if (!_showActions) return;
    final action = await showTimelineActionSheet(
      context,
      showEdit: widget.onEdit != null,
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

    if (widget.journalLayout) {
      return JournalListEntryRow(
        content: widget.content.text,
        tags: widget.content.tags,
        accentColor: accentColor,
        tagConfig: widget.tagConfig,
        showBullet: widget.showBullet,
        trailing: _buildJournalTrailing(),
      );
    }

    final trailing = _buildJournalTrailing();
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
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _TimelineMarker(color: accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.content.text, style: theme.textTheme.bodyMedium),
                  if (widget.content.tags.isNotEmpty || trailing != null)
                    Row(
                      children: [
                        if (widget.content.tags.isNotEmpty)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: TagChipList(
                                tags: widget.content.tags,
                                tagConfig: widget.tagConfig,
                                moduleAccentColor: widget.accentColor,
                              ),
                            ),
                          ),
                        ?trailing,
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

  Widget? _buildJournalTrailing() {
    if (!_showActions && !_busy) return null;
    return JournalEntryActionSlot(
      alignToTags: widget.content.tags.isNotEmpty,
      busy: _busy,
      onPressed: _showActions ? _openActions : null,
    );
  }
}

class _TimelineMarker extends StatelessWidget {
  final Color color;

  const _TimelineMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withAlpha(88),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Positioned(
            top: 3,
            left: -3,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox(width: 8, height: 8),
            ),
          ),
        ],
      ),
    );
  }
}
