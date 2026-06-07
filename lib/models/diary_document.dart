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

class HabitStatus {
  final int water;
  final int steps;
  final bool reading;
  final bool language;
  final bool supplements;

  const HabitStatus({
    required this.water,
    required this.steps,
    required this.reading,
    required this.language,
    required this.supplements,
  });

  factory HabitStatus.fromHabitSection(HabitSection section) {
    int water = 0;
    int steps = 0;
    bool reading = false;
    bool language = false;
    bool supplements = false;

    for (final item in section.habits) {
      final label = item.label;
      if (_containsAny(label, ['饮'])) {
        water = item.value ?? 0;
      } else if (_containsAny(label, ['运动'])) {
        steps = item.value ?? 0;
      } else if (_containsAny(label, ['阅读'])) {
        reading = item.checked;
      } else if (_containsAny(label, ['语言'])) {
        language = item.checked;
      } else if (_containsAny(label, ['鱼油', '植物甾醇'])) {
        supplements = item.checked;
      }
    }

    return HabitStatus(
      water: water,
      steps: steps,
      reading: reading,
      language: language,
      supplements: supplements,
    );
  }

  HabitStatus copyWith({
    int? water,
    int? steps,
    bool? reading,
    bool? language,
    bool? supplements,
  }) {
    return HabitStatus(
      water: water ?? this.water,
      steps: steps ?? this.steps,
      reading: reading ?? this.reading,
      language: language ?? this.language,
      supplements: supplements ?? this.supplements,
    );
  }

  static bool _containsAny(String text, List<String> substrings) {
    for (final s in substrings) {
      if (text.contains(s)) return true;
    }
    return false;
  }
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
