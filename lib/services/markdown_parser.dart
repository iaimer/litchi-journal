import '../models/diary_document.dart';

final _calloutStart = RegExp(r'^>\s*\[!(\w+)\]\s*(.*)$');
final _checkboxLine = RegExp(r'^-\s*\[([ xX])\]\s*(.*)$');
final _timelineLine = RegExp(r'^(?:>\s*|-\s*)\*\*(\d{2}:\d{2})\*\*\s*(.*)$');
final _sectionHeader = RegExp(r'^#{2,3}\s+(.*)$');
final _mainTitle = RegExp(r'^#\s+(.*)$');
final _htmlComment = RegExp(r'^<!--.*-->$');
final _tagPattern = RegExp(r'#(\S+)');
final _horizontalRule = RegExp(r'^[-*_]{3,}$');
final _entryIdMarker = RegExp(
  r'^<!-- litchi-entry-id:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}) -->$',
  caseSensitive: false,
);
final _photoAssociationMarker = RegExp(
  r'^<!-- litchi-photo-of:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})(?:;op:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})? -->$',
  caseSensitive: false,
);
final _wikiImageLine = RegExp(
  r'^!\[\[([^/\\\]]+\.(?:jpg|jpeg|png|gif|webp|heic|heif))\]\]$',
  caseSensitive: false,
);
final _wikiImageInText = RegExp(
  r'!\[\[([^/\\\]]+\.(?:jpg|jpeg|png|gif|webp|heic|heif))\]\]',
  caseSensitive: false,
);
final _photoAssociationLike = RegExp(r'^<!-- litchi-photo-of:.* -->$');

bool _isStandaloneSubSection(String title) {
  return title.contains('习惯打卡') ||
      title.contains('习惯追踪') ||
      title.contains('觉察') ||
      title.contains('人生教练') ||
      title.contains('荔枝喵说') ||
      title.contains('明日寄语') ||
      title.contains('影像');
}

const _templateTimelineText = '内容 #标签';

class MarkdownParser {
  const MarkdownParser();

  DiaryDocument parse(String raw) {
    final lines = _stripYaml(raw);
    final title = _extractTitle(lines);
    final photosByEntryId = _extractPhotosByEntryId(lines);
    final attachedPhotoRawLines = photosByEntryId.values
        .expand((photos) => photos)
        .map((photo) => photo.rawLine)
        .toSet();
    final contents = _parseContents(
      lines,
      photosByEntryId,
      attachedPhotoRawLines,
    );

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

    return DiaryDocument(title: title, preamble: preamble, sections: sections);
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

  Map<String, List<DiaryPhoto>> _extractPhotosByEntryId(List<String> lines) {
    final validEntryIds = <String>{};
    var supportedEntrySection = false;
    for (var index = 0; index < lines.length; index++) {
      final header = _sectionHeader.firstMatch(lines[index].trim());
      if (header != null) {
        final title = header.group(1)!.trim();
        supportedEntrySection = title.contains('随手记') || title.contains('小确幸');
        continue;
      }
      if (!supportedEntrySection ||
          !_timelineLine.hasMatch(lines[index].trim())) {
        continue;
      }
      final end = _timelineBlockEnd(lines, index);
      final entryId = _entryIdFromBlock(lines.sublist(index, end));
      if (entryId != null) validEntryIds.add(entryId);
      index = end - 1;
    }

    final grouped = <String, List<DiaryPhoto>>{};
    var inMediaSection = false;
    for (var index = 0; index < lines.length; index++) {
      final header = _sectionHeader.firstMatch(lines[index].trim());
      if (header != null) {
        inMediaSection = header.group(1)!.contains('影像');
        continue;
      }
      if (!inMediaSection) continue;

      final image = _wikiImageLine.firstMatch(lines[index].trim());
      if (image == null) continue;
      final block = <String>[lines[index]];
      String? entryId;
      if (index + 1 < lines.length) {
        final marker = _photoAssociationMarker.firstMatch(
          lines[index + 1].trim(),
        );
        if (marker != null) {
          entryId = marker.group(1)!.toLowerCase();
          block.add(lines[++index]);
        }
      }
      if (entryId == null || !validEntryIds.contains(entryId)) continue;
      grouped
          .putIfAbsent(entryId, () => <DiaryPhoto>[])
          .add(
            DiaryPhoto(
              filename: image.group(1)!,
              entryId: entryId,
              rawLine: block.join('\n'),
            ),
          );
    }
    return grouped;
  }

  String? _entryIdFromBlock(List<String> lines) {
    if (lines.isEmpty) return null;
    return _entryIdMarker
        .firstMatch(lines.last.trim())
        ?.group(1)
        ?.toLowerCase();
  }

  List<DiaryContent> _parseContents(
    List<String> lines,
    Map<String, List<DiaryPhoto>> photosByEntryId,
    Set<String> attachedPhotoRawLines,
  ) {
    final contents = <DiaryContent>[];
    var i = 0;
    var inMediaSection = false;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (_isPlaceholder(trimmed)) {
        i++;
        continue;
      }

      final sectionMatch = _sectionHeader.firstMatch(trimmed);
      if (sectionMatch != null) {
        final title = sectionMatch.group(1)!.trim();
        inMediaSection = title.contains('影像');
        final isH3 = trimmed.startsWith('###');
        contents.add(
          _SectionMarker(
            title,
            isSubHeader: isH3 && !_isStandaloneSubSection(title),
          ),
        );
        i++;
        continue;
      }

      if (_mainTitle.hasMatch(trimmed)) {
        i++;
        continue;
      }

      if (inMediaSection) {
        final image = _wikiImageLine.firstMatch(trimmed);
        if (image != null) {
          final block = <String>[line];
          if (i + 1 < lines.length &&
              _photoAssociationLike.hasMatch(lines[i + 1].trim())) {
            block.add(lines[++i]);
          }
          final rawLine = block.join('\n');
          final marker = block.length == 2
              ? _photoAssociationMarker.firstMatch(block.last.trim())
              : null;
          contents.add(
            MediaPhotoContent(
              DiaryPhoto(
                filename: image.group(1)!,
                rawLine: rawLine,
                entryId: attachedPhotoRawLines.contains(rawLine)
                    ? marker?.group(1)?.toLowerCase()
                    : null,
              ),
            ),
          );
          i++;
          continue;
        }
        final inlineImages = _wikiImageInText.allMatches(line).toList();
        if (inlineImages.isNotEmpty) {
          for (final match in inlineImages) {
            contents.add(
              MediaPhotoContent(
                DiaryPhoto(filename: match.group(1)!, rawLine: match.group(0)!),
              ),
            );
          }
          i++;
          continue;
        }
      }

      final calloutMatch = _calloutStart.firstMatch(trimmed);
      if (calloutMatch != null) {
        final body = <String>[];
        i++;
        while (i < lines.length) {
          final next = lines[i].trim();
          if (!next.startsWith('>')) break;
          if (_timelineLine.hasMatch(next)) break;
          final bodyLine = next.substring(1).trim();
          if (bodyLine.isNotEmpty && bodyLine != '** **') {
            body.add(bodyLine);
          }
          i++;
        }
        contents.add(
          CalloutContent(
            type: calloutMatch.group(1)!.toLowerCase(),
            title: (calloutMatch.group(2) ?? '').trim(),
            body: body,
          ),
        );
        continue;
      }

      final checkboxMatch = _checkboxLine.firstMatch(trimmed);
      if (checkboxMatch != null) {
        final text = (checkboxMatch.group(2) ?? '').trim();
        if (text.isNotEmpty) {
          contents.add(
            CheckboxContent(
              checked: checkboxMatch.group(1)!.toLowerCase() == 'x',
              text: text,
              rawLine: line,
            ),
          );
        }
        i++;
        continue;
      }

      final timelineMatch = _timelineLine.firstMatch(trimmed);
      if (timelineMatch != null) {
        final blockEnd = _timelineBlockEnd(lines, i);
        final blockLines = lines.sublist(i, blockEnd);
        final rawContent = _timelineContent(blockLines, timelineMatch);
        if (rawContent.isNotEmpty && rawContent != _templateTimelineText) {
          final entryId = _entryIdFromBlock(blockLines);
          contents.add(
            TimelineContent(
              time: timelineMatch.group(1)!,
              text: _stripTags(rawContent),
              tags: _extractTags(rawContent),
              rawLine: blockLines.join('\n'),
              entryId: entryId,
              photos: entryId == null
                  ? const []
                  : photosByEntryId[entryId] ?? const [],
            ),
          );
        }
        i = blockEnd;
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
        if (inMediaSection && _wikiImageInText.hasMatch(lines[i])) break;
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

  int _timelineBlockEnd(List<String> lines, int start) {
    var end = start + 1;
    while (end < lines.length) {
      final line = lines[end];
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && _isSpecialLine(line)) break;
      if (trimmed.isNotEmpty && _horizontalRule.hasMatch(trimmed)) break;
      if (trimmed.isNotEmpty &&
          _htmlComment.hasMatch(trimmed) &&
          !_entryIdMarker.hasMatch(trimmed)) {
        break;
      }
      end++;
    }

    while (end > start + 1 && lines[end - 1].trim().isEmpty) {
      end--;
    }
    return end;
  }

  String _timelineContent(List<String> blockLines, RegExpMatch timelineMatch) {
    final isQuote = blockLines.first.trimLeft().startsWith('>');
    final contentLines = <String>[(timelineMatch.group(2) ?? '').trim()];

    for (var index = 1; index < blockLines.length; index++) {
      var continuation = blockLines[index].trim();
      if (index == blockLines.length - 1 &&
          _entryIdMarker.hasMatch(continuation)) {
        continue;
      }
      if (isQuote && continuation.startsWith('>')) {
        continuation = continuation.substring(1).trimLeft();
      }
      contentLines.add(continuation);
    }

    return contentLines.join('\n').trim();
  }

  List<String> _extractTags(String text) {
    return _tagPattern
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();
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
    if (title.contains('习惯打卡') || title.contains('习惯追踪')) {
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
    if (title.contains('小确幸')) {
      return HappinessSection(title: title, contents: contents);
    }
    if (title.contains('每日复盘') || title.contains('觉察')) {
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
    final counterPattern = RegExp(r'(\d+)\s*(\S+)$');
    final durationPattern = RegExp(r'^(.*?)\s+(\d+)\s*(?:分钟|min)$');
    final cleanLabel = RegExp(r'^[^\w\u4e00-\u9fff]+');

    for (final content in contents) {
      if (content is CheckboxContent) {
        final durationMatch = durationPattern.firstMatch(content.text);
        if (durationMatch != null) {
          habits.add(
            HabitItem(
              kind: HabitKind.duration,
              label: durationMatch.group(1)!.trim(),
              checked: content.checked,
              checkable: true,
              rawLine: content.rawLine,
              value: int.tryParse(durationMatch.group(2)!),
              unit: '分钟',
            ),
          );
          continue;
        }
        habits.add(
          HabitItem(
            kind: HabitKind.checkbox,
            label: content.text,
            checked: content.checked,
            checkable: true,
            rawLine: content.rawLine,
          ),
        );
      } else if (content is MarkdownContent) {
        for (final line in content.text.split('\n')) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('- ')) continue;
          final body = trimmed.substring(2).trim();
          if (body.isEmpty) continue;

          final counterMatch = counterPattern.firstMatch(body);
          if (counterMatch != null) {
            final value = int.tryParse(counterMatch.group(1)!);
            final unit = counterMatch.group(2)!;
            final rawLabel = body.substring(0, counterMatch.start).trim();
            final label = rawLabel.replaceFirst(cleanLabel, '').trim();

            habits.add(
              HabitItem(
                kind: HabitKind.counter,
                label: label,
                checked: false,
                checkable: false,
                rawLine: line,
                value: value,
                unit: unit,
              ),
            );
          } else {
            habits.add(
              HabitItem(
                kind: HabitKind.checkbox,
                label: body,
                checked: false,
                checkable: false,
                rawLine: line,
              ),
            );
          }
        }
      }
    }
    return habits;
  }

  List<QuickNoteItem> _buildQuickNoteItems() {
    final notes = <QuickNoteItem>[];
    for (final content in contents) {
      if (content is TimelineContent) {
        notes.add(
          QuickNoteItem(
            time: content.time,
            content: content.text,
            tags: content.tags,
            rawLine: content.rawLine,
            entryId: content.entryId,
            photos: content.photos,
          ),
        );
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
