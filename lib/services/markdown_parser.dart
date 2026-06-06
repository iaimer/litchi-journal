import '../models/diary_document.dart';

final _calloutStart = RegExp(r'^>\s*\[!(\w+)\]\s*(.*)$');
final _checkboxLine = RegExp(r'^-\s*\[([ xX])\]\s*(.*)$');
final _timelineLine = RegExp(r'^-\s*\*\*(\d{2}:\d{2})\*\*\s*(.*)$');
final _sectionHeader = RegExp(r'^#{2,3}\s+(.*)$');
final _mainTitle = RegExp(r'^#\s+(.*)$');
final _htmlComment = RegExp(r'^<!--.*-->$');
final _tagPattern = RegExp(r'#(\S+)');
final _horizontalRule = RegExp(r'^[-*_]{3,}$');

const _templateTimelineText = '内容 #标签';

class MarkdownParser {
  const MarkdownParser();

  DiaryDocument parse(String raw) {
    final lines = _stripYaml(raw);
    final title = _extractTitle(lines);
    final contents = _parseContents(lines);

    final preamble = <DiaryContent>[];
    final sections = <DiarySection>[];
    _DraftSection? current;

    for (final content in contents) {
      if (content is _SectionMarker && !content.isSubHeader) {
        if (current != null) sections.add(current.toSection());
        current = _DraftSection(content.title);
      } else if (content is _SectionMarker && content.isSubHeader) {
        current?.contents.add(SubSectionContent(content.title));
      } else if (current != null) {
        current.contents.add(content);
      } else {
        preamble.add(content);
      }
    }

    if (current != null) sections.add(current.toSection());

    return DiaryDocument(
      title: title,
      preamble: preamble,
      sections: sections,
    );
  }

  List<String> _stripYaml(String raw) {
    final lines = raw.split('\n');
    final firstContent = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (firstContent == -1 || lines[firstContent].trim() != '---') {
      return lines;
    }

    final result = <String>[];
    var inYaml = true;
    for (int i = firstContent + 1; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (inYaml && trimmed == '---') {
        inYaml = false;
        continue;
      }
      if (!inYaml) result.add(lines[i]);
    }
    return result;
  }

  String _extractTitle(List<String> lines) {
    for (final line in lines) {
      final match = _mainTitle.firstMatch(line.trim());
      if (match != null) return match.group(1)!.trim();
    }
    return '';
  }

  List<DiaryContent> _parseContents(List<String> lines) {
    final contents = <DiaryContent>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (_isPlaceholder(trimmed)) {
        i++;
        continue;
      }

      final sectionMatch = _sectionHeader.firstMatch(trimmed);
      if (sectionMatch != null) {
        contents.add(_SectionMarker(
          sectionMatch.group(1)!.trim(),
          isSubHeader: trimmed.startsWith('###'),
        ));
        i++;
        continue;
      }

      if (_mainTitle.hasMatch(trimmed)) {
        i++;
        continue;
      }

      final calloutMatch = _calloutStart.firstMatch(trimmed);
      if (calloutMatch != null) {
        final body = <String>[];
        i++;
        while (i < lines.length) {
          final next = lines[i].trim();
          if (!next.startsWith('>')) break;
          final bodyLine = next.substring(1).trim();
          if (bodyLine.isNotEmpty && bodyLine != '** **') {
            body.add(bodyLine);
          }
          i++;
        }
        contents.add(CalloutContent(
          type: calloutMatch.group(1)!.toLowerCase(),
          title: (calloutMatch.group(2) ?? '').trim(),
          body: body,
        ));
        continue;
      }

      final checkboxMatch = _checkboxLine.firstMatch(trimmed);
      if (checkboxMatch != null) {
        final text = (checkboxMatch.group(2) ?? '').trim();
        if (text.isNotEmpty) {
          contents.add(CheckboxContent(
            checked: checkboxMatch.group(1)!.toLowerCase() == 'x',
            text: text,
            rawLine: line,
          ));
        }
        i++;
        continue;
      }

      final timelineMatch = _timelineLine.firstMatch(trimmed);
      if (timelineMatch != null) {
        final rawContent = (timelineMatch.group(2) ?? '').trim();
        if (rawContent.isNotEmpty && rawContent != _templateTimelineText) {
          contents.add(TimelineContent(
            time: timelineMatch.group(1)!,
            text: _stripTags(rawContent),
            tags: _extractTags(rawContent),
            rawLine: line,
          ));
        }
        i++;
        continue;
      }

      final markdownLines = <String>[lines[i]];
      i++;
      while (i < lines.length) {
        final nextTrimmed = lines[i].trim();
        if (nextTrimmed.isEmpty || _isPlaceholder(nextTrimmed)) {
          if (nextTrimmed.isEmpty) markdownLines.add(lines[i]);
          i++;
          continue;
        }
        if (_isSpecialLine(lines[i])) break;
        markdownLines.add(lines[i]);
        i++;
      }

      final markdown = markdownLines.join('\n').trim();
      if (markdown.isNotEmpty) contents.add(MarkdownContent(markdown));
    }

    return contents;
  }

  bool _isPlaceholder(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || _htmlComment.hasMatch(trimmed)) return true;
    if (trimmed == '-' ||
        trimmed == '>' ||
        trimmed == '> ** **' ||
        _horizontalRule.hasMatch(trimmed)) {
      return true;
    }

    final timelineMatch = _timelineLine.firstMatch(trimmed);
    return timelineMatch != null &&
        timelineMatch.group(2)!.trim() == _templateTimelineText;
  }

  bool _isSpecialLine(String line) {
    final trimmed = line.trim();
    return _sectionHeader.hasMatch(trimmed) ||
        _mainTitle.hasMatch(trimmed) ||
        _calloutStart.hasMatch(trimmed) ||
        _checkboxLine.hasMatch(trimmed) ||
        _timelineLine.hasMatch(trimmed);
  }

  List<String> _extractTags(String text) {
    return _tagPattern.allMatches(text).map((match) => match.group(0)!).toList();
  }

  String _stripTags(String text) {
    return text.replaceAll(_tagPattern, '').trim();
  }
}

class _DraftSection {
  final String title;
  final List<DiaryContent> contents = [];

  _DraftSection(this.title);

  DiarySection toSection() {
    if (title.contains('习惯打卡')) {
      return HabitSection(
        title: title,
        contents: contents,
        habits: _buildHabitItems(),
      );
    }
    if (title.contains('随手记')) {
      return QuickNoteSection(
        title: title,
        contents: contents,
        notes: _buildQuickNoteItems(),
      );
    }
    if (title.contains('焦虑')) {
      return AnxietySection(title: title, contents: contents);
    }
    if (title.contains('每日复盘')) {
      return ReviewSection(title: title, contents: contents);
    }
    if (title.contains('人生教练') || title.contains('荔枝喵说')) {
      return CoachSection(title: title, contents: contents);
    }
    if (title.contains('明日寄语')) {
      return TomorrowSection(title: title, contents: contents);
    }
    if (title.contains('影像')) {
      return MediaSection(title: title, contents: contents);
    }
    return GenericDiarySection(title: title, contents: contents);
  }

  List<HabitItem> _buildHabitItems() {
    final habits = <HabitItem>[];
    for (final content in contents) {
      if (content is CheckboxContent) {
        habits.add(HabitItem(
          label: content.text,
          checked: content.checked,
          checkable: true,
          rawLine: content.rawLine,
        ));
      } else if (content is MarkdownContent) {
        for (final line in content.text.split('\n')) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('- ')) continue;
          final label = trimmed.substring(2).trim();
          if (label.isEmpty) continue;
          habits.add(HabitItem(
            label: label,
            checked: false,
            checkable: false,
            rawLine: line,
          ));
        }
      }
    }
    return habits;
  }

  List<QuickNoteItem> _buildQuickNoteItems() {
    final notes = <QuickNoteItem>[];
    for (final content in contents) {
      if (content is TimelineContent) {
        notes.add(QuickNoteItem(
          time: content.time,
          content: content.text,
          tags: content.tags,
          rawLine: content.rawLine,
        ));
      }
    }
    return notes;
  }
}

class _SectionMarker extends DiaryContent {
  final String title;
  final bool isSubHeader;

  const _SectionMarker(this.title, {required this.isSubHeader});

  @override
  bool get hasRealContent => false;
}
