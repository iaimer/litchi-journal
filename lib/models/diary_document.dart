class DiaryDocument {
  final String title;
  final List<DiaryContent> preamble;
  final List<DiarySection> sections;

  const DiaryDocument({
    required this.title,
    required this.preamble,
    required this.sections,
  });

  bool get isEmpty =>
      preamble.every((content) => !content.hasRealContent) &&
      sections.every((section) => section.isEmpty);
}

abstract class DiarySection {
  final String title;
  final List<DiaryContent> contents;

  const DiarySection({
    required this.title,
    required this.contents,
  });

  bool get isEmpty => contents.every((content) => !content.hasRealContent);
}

class HabitSection extends DiarySection {
  final List<HabitItem> habits;

  const HabitSection({
    required super.title,
    required super.contents,
    required this.habits,
  });
}

class QuickNoteSection extends DiarySection {
  final List<QuickNoteItem> notes;

  const QuickNoteSection({
    required super.title,
    required super.contents,
    required this.notes,
  });
}

class AnxietySection extends DiarySection {
  const AnxietySection({required super.title, required super.contents});
}

class HappinessSection extends DiarySection {
  const HappinessSection({required super.title, required super.contents});
}

class ReviewSection extends DiarySection {
  const ReviewSection({required super.title, required super.contents});
}

class CoachSection extends DiarySection {
  const CoachSection({required super.title, required super.contents});
}

class TomorrowSection extends DiarySection {
  const TomorrowSection({required super.title, required super.contents});
}

class MediaSection extends DiarySection {
  const MediaSection({required super.title, required super.contents});
}

class GenericDiarySection extends DiarySection {
  const GenericDiarySection({required super.title, required super.contents});
}

abstract class DiaryContent {
  const DiaryContent();

  bool get hasRealContent;
}

class CalloutContent extends DiaryContent {
  final String type;
  final String title;
  final List<String> body;

  const CalloutContent({
    required this.type,
    required this.title,
    required this.body,
  });

  @override
  bool get hasRealContent => body.isNotEmpty;
}

class CheckboxContent extends DiaryContent {
  final bool checked;
  final String text;
  final String rawLine;

  const CheckboxContent({
    required this.checked,
    required this.text,
    required this.rawLine,
  });

  @override
  bool get hasRealContent => text.trim().isNotEmpty;
}

class TimelineContent extends DiaryContent {
  final String time;
  final String text;
  final List<String> tags;
  final String rawLine;

  const TimelineContent({
    required this.time,
    required this.text,
    required this.tags,
    required this.rawLine,
  });

  @override
  bool get hasRealContent => text.trim().isNotEmpty;
}

class MarkdownContent extends DiaryContent {
  final String text;

  const MarkdownContent(this.text);

  @override
  bool get hasRealContent =>
      text.trim().isNotEmpty && !_allLinesAreTemplateQuestions(text);
}

class SubSectionContent extends DiaryContent {
  final String title;

  const SubSectionContent(this.title);

  @override
  bool get hasRealContent => false;
}

enum HabitKind {
  checkbox,
  counter,
}

class HabitItem {
  final HabitKind kind;
  final String label;
  final bool checked;
  final bool checkable;
  final String rawLine;
  final int? value;
  final String? unit;

  const HabitItem({
    required this.kind,
    required this.label,
    required this.checked,
    required this.checkable,
    required this.rawLine,
    this.value,
    this.unit,
  });
}

class QuickNoteItem {
  final String time;
  final String content;
  final List<String> tags;
  final String rawLine;

  const QuickNoteItem({
    required this.time,
    required this.content,
    required this.tags,
    required this.rawLine,
  });
}

bool _allLinesAreTemplateQuestions(String text) {
  final lines = text.split('\n');
  if (lines.isEmpty) return true;
  return lines.every((line) {
    final trimmed = line.trim();
    return trimmed.isEmpty ||
        (trimmed.startsWith('- ') && RegExp(r'[？?]').hasMatch(trimmed));
  });
}
