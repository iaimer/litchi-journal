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

  const DiarySection({required this.title, required this.contents});

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

  factory HabitSection.empty({String title = '🏃 习惯打卡'}) {
    return HabitSection(
      title: title,
      contents: const [],
      habits: const [
        HabitItem(
          kind: HabitKind.counter,
          label: '饮水',
          checked: false,
          checkable: false,
          rawLine: '',
          value: 0,
          unit: 'mL',
        ),
        HabitItem(
          kind: HabitKind.counter,
          label: '运动/拉伸/快走',
          checked: false,
          checkable: false,
          rawLine: '',
          value: 0,
          unit: '步',
        ),
        HabitItem(
          kind: HabitKind.checkbox,
          label: '📖 阅读/亲子共读',
          checked: false,
          checkable: true,
          rawLine: '',
        ),
        HabitItem(
          kind: HabitKind.checkbox,
          label: '💡 学语言',
          checked: false,
          checkable: true,
          rawLine: '',
        ),
        HabitItem(
          kind: HabitKind.checkbox,
          label: '💊 鱼油/植物甾醇',
          checked: false,
          checkable: true,
          rawLine: '',
        ),
      ],
    );
  }

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

enum HabitKind { checkbox, counter, duration }

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

  /// 从内置习惯的完整 label 推断 key，用于数据映射和 UI 过滤。
  static String? keyForLabel(String label) {
    final normalized = label
        .trim()
        .replaceFirst(RegExp(r'\s+\d+\s*(?:分钟|min)\s*$'), '')
        .replaceAll(RegExp(r'\s*/\s*'), '/');
    if ({'饮水', '🥛饮水', '🥛🥤饮水'}.contains(normalized)) return 'water';
    if ({'运动', '运动/拉伸/快走', '🧘 运动/拉伸/快走'}.contains(normalized)) {
      return 'steps';
    }
    if ({
      '阅读',
      '亲子共读',
      '亲子阅读',
      '阅读/亲子共读',
      '📖 阅读',
      '📖 亲子共读',
      '📖 阅读/亲子共读',
    }.contains(normalized)) {
      return 'reading';
    }
    if ({'学语言', '🇬🇧 学语言', '💡 学语言'}.contains(normalized)) {
      return 'language';
    }
    if ({
      '鱼油',
      '植物甾醇',
      '鱼油/植物甾醇',
      '补充剂',
      '💊 鱼油',
      '💊 植物甾醇',
      '💊 鱼油/植物甾醇',
      '💊 补充剂',
    }.contains(normalized)) {
      return 'supplements';
    }
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
  final int readingMinutes;
  final int languageMinutes;

  const HabitStatus({
    required this.water,
    required this.steps,
    required this.reading,
    required this.language,
    required this.supplements,
    this.readingMinutes = 0,
    this.languageMinutes = 0,
  });

  factory HabitStatus.fromHabitSection(HabitSection section) {
    int water = 0;
    int steps = 0;
    bool reading = false;
    bool language = false;
    bool supplements = false;
    int readingMinutes = 0;
    int languageMinutes = 0;

    for (final item in section.habits) {
      switch (item.habitKey) {
        case 'water':
          water = item.value ?? 0;
        case 'steps':
          steps = item.value ?? 0;
        case 'reading':
          reading = item.checked;
          readingMinutes = item.value ?? 0;
        case 'language':
          language = item.checked;
          languageMinutes = item.value ?? 0;
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
      readingMinutes: readingMinutes,
      languageMinutes: languageMinutes,
    );
  }

  HabitStatus copyWith({
    int? water,
    int? steps,
    bool? reading,
    bool? language,
    bool? supplements,
    int? readingMinutes,
    int? languageMinutes,
  }) {
    return HabitStatus(
      water: water ?? this.water,
      steps: steps ?? this.steps,
      reading: reading ?? this.reading,
      language: language ?? this.language,
      supplements: supplements ?? this.supplements,
      readingMinutes: readingMinutes ?? this.readingMinutes,
      languageMinutes: languageMinutes ?? this.languageMinutes,
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
