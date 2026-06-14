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

  /// 区域类型标识，用于隐藏逻辑等条件判断。
  String get sectionType;

  bool get isEmpty => contents.every((content) => !content.hasRealContent);
}

class HabitSection extends DiarySection {
  final List<HabitItem> habits;

  const HabitSection({
    required super.title,
    required super.contents,
    required this.habits,
  });

  @override
  String get sectionType => 'habit';
}

class QuickNoteSection extends DiarySection {
  final List<QuickNoteItem> notes;

  const QuickNoteSection({
    required super.title,
    required super.contents,
    required this.notes,
  });

  @override
  String get sectionType => 'quickNote';
}

class AnxietySection extends DiarySection {
  const AnxietySection({required super.title, required super.contents});

  @override
  String get sectionType => 'anxiety';
}

class HappinessSection extends DiarySection {
  const HappinessSection({required super.title, required super.contents});

  @override
  String get sectionType => 'happiness';
}

class ReviewSection extends DiarySection {
  const ReviewSection({required super.title, required super.contents});

  @override
  String get sectionType => 'review';
}

class CoachSection extends DiarySection {
  const CoachSection({required super.title, required super.contents});

  @override
  String get sectionType => 'coach';
}

class TomorrowSection extends DiarySection {
  const TomorrowSection({required super.title, required super.contents});

  @override
  String get sectionType => 'tomorrow';
}

class MediaSection extends DiarySection {
  const MediaSection({required super.title, required super.contents});

  @override
  String get sectionType => 'media';
}

class GenericDiarySection extends DiarySection {
  const GenericDiarySection({required super.title, required super.contents});

  @override
  String get sectionType => 'generic';
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

  /// 从 label 推断习惯 key，用于数据映射和 UI 过滤。
  /// 包含关系匹配：'饮' 匹配 '饮水'、'运动' 匹配 '运动步数' 等。
  static String? keyForLabel(String label) {
    if (label.contains('饮')) return 'water';
    if (label.contains('运动')) return 'steps';
    if (label.contains('阅读')) return 'reading';
    if (label.contains('语言')) return 'language';
    if (label.contains('鱼油') || label.contains('植物甾醇')) return 'supplements';
    return null;
  }

  /// 当前习惯的 key，可能为 null（未知/自定义习惯）。
  String? get habitKey => keyForLabel(label);
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
      switch (item.habitKey) {
        case 'water':
          water = item.value ?? 0;
        case 'steps':
          steps = item.value ?? 0;
        case 'reading':
          reading = item.checked;
        case 'language':
          language = item.checked;
        case 'supplements':
          supplements = item.checked;
        default:
          break;
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
