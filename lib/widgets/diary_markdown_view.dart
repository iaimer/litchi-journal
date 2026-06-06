import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

final _calloutStart = RegExp(r'^>\s*\[!(\w+)\]\s*(.*)$');
final _checkboxLine = RegExp(r'^-\s*\[([ xX])\]\s*(.*)$');
final _timelineLine = RegExp(r'^-\s*\*\*(\d{2}:\d{2})\*\*\s*(.*)$');
final _sectionHeader = RegExp(r'^#{2,3}\s+(.*)$');
final _mainTitle = RegExp(r'^#\s+.*$');
final _htmlComment = RegExp(r'^<!--.*-->$');
final _tagPattern = RegExp(r'#(\S+)');
final _questionHint = RegExp(r'[？?]|吗[？?]?$');
final _horizontalRule = RegExp(r'^[-*_]{3,}$');

const _templateTimelineText = '内容 #标签';

enum _Kind { section, callout, check, timeline, markdown }

class _Block {
  final _Kind kind;
  String? title;
  bool isSubHeader = false;
  String? calloutType;
  List<String>? calloutBody;
  bool? checked;
  String? time;
  String? text;
  List<String>? tags;

  _Block(this.kind);
}

class DiaryMarkdownView extends StatelessWidget {
  final String markdown;

  const DiaryMarkdownView({super.key, required this.markdown});

  List<String> _stripYaml(String raw) {
    final lines = raw.split('\n');
    final result = <String>[];
    var inYaml = false;
    var yamlCount = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '---' && yamlCount < 2) {
        inYaml = !inYaml;
        yamlCount++;
        continue;
      }
      if (!inYaml) {
        result.add(line);
      }
    }
    return result;
  }

  bool _isPlaceholder(String line) {
    final t = line.trim();
    if (t.isEmpty || _htmlComment.hasMatch(t)) return true;
    if (t == '-' || t == '>' || t == '> ** **' || _horizontalRule.hasMatch(t)) return true;

    final tm = _timelineLine.firstMatch(t);
    if (tm != null && tm.group(2)!.trim() == _templateTimelineText) {
      return true;
    }

    return false;
  }

  bool _isSpecialLine(String line) {
    final t = line.trim();
    return _sectionHeader.hasMatch(t) ||
        _mainTitle.hasMatch(t) ||
        _calloutStart.hasMatch(t) ||
        _checkboxLine.hasMatch(t) ||
        _timelineLine.hasMatch(t);
  }

  List<String> _extractTags(String text) {
    return _tagPattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
  }

  String _stripTags(String text) {
    return text.replaceAll(_tagPattern, '').trim();
  }

  List<_Block> _parseBlocks(List<String> lines) {
    final blocks = <_Block>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (_isPlaceholder(trimmed)) {
        i++;
        continue;
      }

      if (_sectionHeader.hasMatch(trimmed)) {
        final m = _sectionHeader.firstMatch(trimmed)!;
        final block = _Block(_Kind.section)
          ..title = m.group(1)!.trim()
          ..isSubHeader = trimmed.startsWith('###');
        blocks.add(block);
        i++;
        continue;
      }

      if (_mainTitle.hasMatch(trimmed)) {
        i++;
        continue;
      }

      if (_calloutStart.hasMatch(trimmed)) {
        final m = _calloutStart.firstMatch(trimmed)!;
        final block = _Block(_Kind.callout)
          ..calloutType = m.group(1)!.toLowerCase()
          ..title = (m.group(2) ?? '').trim();

        final body = <String>[];
        i++;
        while (i < lines.length) {
          final next = lines[i].trim();
          if (next.startsWith('>')) {
            final bodyLine = next.substring(1).trim();
            if (bodyLine.isNotEmpty && bodyLine != '** **') {
              body.add(bodyLine);
            }
            i++;
          } else {
            break;
          }
        }
        block.calloutBody = body;
        blocks.add(block);
        continue;
      }

      if (_checkboxLine.hasMatch(trimmed)) {
        final m = _checkboxLine.firstMatch(trimmed)!;
        final text = (m.group(2) ?? '').trim();
        if (text.isNotEmpty) {
          blocks.add(_Block(_Kind.check)
            ..checked = m.group(1)!.toLowerCase() == 'x'
            ..text = text);
        }
        i++;
        continue;
      }

      if (_timelineLine.hasMatch(trimmed)) {
        final m = _timelineLine.firstMatch(trimmed)!;
        final rawContent = (m.group(2) ?? '').trim();
        if (rawContent.isNotEmpty && rawContent != _templateTimelineText) {
          blocks.add(_Block(_Kind.timeline)
            ..time = m.group(1)!
            ..text = _stripTags(rawContent)
            ..tags = _extractTags(rawContent));
        }
        i++;
        continue;
      }

      final mdLines = <String>[lines[i]];
      i++;
      while (i < lines.length) {
        final nextTrimmed = lines[i].trim();
        if (nextTrimmed.isEmpty || _isPlaceholder(nextTrimmed)) {
          i++;
          continue;
        }
        if (_isSpecialLine(lines[i])) break;
        mdLines.add(lines[i]);
        i++;
      }
      final md = mdLines.join('\n').trim();
      if (md.isNotEmpty) {
        blocks.add(_Block(_Kind.markdown)..text = md);
      }
    }

    return blocks;
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

  @override
  Widget build(BuildContext context) {
    final lines = _stripYaml(markdown);
    final blocks = _parseBlocks(lines);
    if (blocks.isEmpty) return const SizedBox.shrink();

    final preamble = <_Block>[];
    final sections = <_Section>[];
    _Section? current;

    for (final block in blocks) {
      if (block.kind == _Kind.section && !block.isSubHeader) {
        current = _Section(block.title!);
        sections.add(current);
      } else if (block.kind == _Kind.section && block.isSubHeader) {
        if (current != null) {
          current.blocks.add(block);
        }
      } else if (current != null) {
        current.blocks.add(block);
      } else {
        preamble.add(block);
      }
    }

    final widgets = <Widget>[];

    for (final block in preamble) {
      _buildBlock(context, block, widgets);
    }

    for (final section in sections) {
      if (section.hasCollapsibleCallout) {
        widgets.add(_buildSectionHeader(context, section.title));
        widgets.add(_buildCollapsedCallout(context, section));
        continue;
      }
      if (section.isEffectivelyEmpty) continue;

      widgets.add(_buildSectionHeader(context, section.title));

      for (int i = 0; i < section.blocks.length; i++) {
        final block = section.blocks[i];
        if (block.kind == _Kind.section) {
          if (_subSectionHasContent(section.blocks, i)) {
            widgets.add(_buildSubSectionHeader(context, block.title!));
          }
        } else {
          _buildBlock(context, block, widgets);
        }
      }
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static bool _subSectionHasContent(List<_Block> blocks, int from) {
    for (int j = from + 1; j < blocks.length; j++) {
      final next = blocks[j];
      if (next.kind == _Kind.section && next.isSubHeader) break;
      if (_blockHasRealContent(next)) return true;
    }
    return false;
  }

  static bool _blockHasRealContent(_Block b) {
    switch (b.kind) {
      case _Kind.markdown:
        if (b.text == null || b.text!.trim().isEmpty) return false;
        return !_allLinesAreTemplateQuestions(b.text!);
      case _Kind.callout:
        return b.calloutBody != null && b.calloutBody!.isNotEmpty;
      case _Kind.check:
      case _Kind.timeline:
        return true;
      default:
        return false;
    }
  }

  void _buildBlock(BuildContext context, _Block block, List<Widget> widgets) {
    switch (block.kind) {
      case _Kind.callout:
        widgets.add(_buildCallout(context, block));
      case _Kind.check:
        widgets.add(_buildCheckbox(context, block));
      case _Kind.timeline:
        widgets.add(_buildTimeline(context, block));
      case _Kind.markdown:
        widgets.add(
          MarkdownBody(
            data: block.text!,
            selectable: true,
            styleSheet: _baseStyleSheet(context),
          ),
        );
      default:
        break;
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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

  Widget _buildCallout(BuildContext context, _Block block) {
    final theme = Theme.of(context);
    final (icon, color, bgColor) = _calloutStyle(theme, block.calloutType!);

    final bodyText = (block.calloutBody ?? []).join('\n');
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
          if (block.title!.isNotEmpty)
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: MarkdownBody(
                    data: block.title!,
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
            if (block.title!.isNotEmpty) const SizedBox(height: 4),
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

  Widget _buildCollapsedCallout(BuildContext context, _Section section) {
    final block = section.blocks.first;
    final theme = Theme.of(context);
    final (icon, color, bgColor) = _calloutStyle(theme, block.calloutType!);

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
              data: block.title ?? section.title,
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

  Widget _buildCheckbox(BuildContext context, _Block block) {
    final theme = Theme.of(context);
    final icon = block.checked! ? Icons.check_box : Icons.check_box_outline_blank;
    final color = block.checked! ? Colors.green : theme.disabledColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              block.text!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, _Block block) {
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
                block.time!,
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
                    block.text!,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (block.tags != null && block.tags!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        block.tags!.join(' '),
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
    switch (type) {
      case 'quote':
        return (Icons.format_quote, Colors.grey.shade700, Colors.grey.shade50);
      case 'tip':
        return (Icons.lightbulb_outline, Colors.teal.shade700, Colors.teal.shade50);
      case 'note':
      case 'info':
        return (Icons.info_outline, Colors.blue.shade700, Colors.blue.shade50);
      case 'warning':
      case 'caution':
        return (Icons.warning_amber_rounded, Colors.orange.shade700, Colors.orange.shade50);
      case 'danger':
      case 'error':
        return (Icons.error_outline, Colors.red.shade700, Colors.red.shade50);
      case 'success':
      case 'done':
        return (Icons.check_circle_outline, Colors.green.shade700, Colors.green.shade50);
      case 'example':
        return (Icons.code, Colors.purple.shade700, Colors.purple.shade50);
      default:
        return (Icons.info_outline, Colors.blue.shade700, Colors.blue.shade50);
    }
  }
}

bool _isTemplateQuestionLine(String line) {
  return line.trimLeft().startsWith('- ') && RegExp(r'[？?]').hasMatch(line);
}

bool _allLinesAreTemplateQuestions(String text) {
  final lines = text.split('\n');
  if (lines.isEmpty) return true;
  return lines.every((line) {
    final t = line.trim();
    return t.isEmpty || _isTemplateQuestionLine(t);
  });
}

class _Section {
  final String title;
  final List<_Block> blocks = [];

  _Section(this.title);

  bool get isEffectivelyEmpty {
    if (blocks.isEmpty) return true;
    return blocks.every((b) {
      switch (b.kind) {
        case _Kind.markdown:
          return b.text == null ||
              b.text!.trim().isEmpty ||
              _allLinesAreTemplateQuestions(b.text!);
        case _Kind.section:
          return true;
        case _Kind.callout:
          return b.calloutBody == null || b.calloutBody!.isEmpty;
        default:
          return false;
      }
    });
  }

  bool get hasCollapsibleCallout {
    if (blocks.length != 1) return false;
    final b = blocks.first;
    if (b.kind != _Kind.callout) return false;
    if (b.calloutBody != null && b.calloutBody!.isNotEmpty) return false;
    return _questionHint.hasMatch(b.title ?? '');
  }
}
