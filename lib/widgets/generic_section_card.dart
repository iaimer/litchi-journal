import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/diary_document.dart';
import '../theme/app_theme.dart';
import 'section_card.dart';

final _questionHint = RegExp(r'[？?]$|吗[？?]?$');

class GenericSectionCard extends StatelessWidget {
  final DiarySection section;

  const GenericSectionCard({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) return const SizedBox.shrink();

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
        widgets.add(_buildTimeline(context, content));
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
    var sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      p: theme.textTheme.bodyMedium,
      listBullet: theme.textTheme.bodyMedium,
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
    final color = checked ? Colors.green : theme.disabledColor;

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

  Widget _buildTimeline(BuildContext context, TimelineContent content) {
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
                content.time,
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
                    content.text,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (content.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        content.tags.join(' '),
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
