import '../models/diary_document.dart';
import '../services/markdown_parser.dart';

/// 阅读与生成入口共享同一份领域解析结果，不根据界面占位推断内容。
class DiaryDisplayState {
  final DiaryDocument document;
  final bool hasOnlyHabits;
  final bool hasCoach;
  DiaryDisplayState._(this.document, this.hasOnlyHabits, this.hasCoach);
  factory DiaryDisplayState(String markdown, {bool habitFallback = false}) {
    final doc = const MarkdownParser().parse(markdown);
    return DiaryDisplayState._(
      doc,
      _onlyHabits(doc, habitFallback),
      doc.sections.whereType<CoachSection>().any((s) => !s.isEmpty),
    );
  }

  static bool _onlyHabits(DiaryDocument doc, bool fallback) =>
      (fallback || doc.sections.any((s) => s is HabitSection)) &&
      doc.preamble.every((c) => !c.hasRealContent) &&
      doc.sections.every((s) => s is HabitSection || s.isEmpty);
}
