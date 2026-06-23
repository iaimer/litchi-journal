import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import 'generic_section_card.dart';

final _templateQuestionHint = RegExp(r'[？?]');
const _anxietyAccentColor = Color(0xFFFFD43B);

class AnxietyCard extends StatelessWidget {
  final AnxietySection section;
  final Color? accentColor;

  const AnxietyCard({super.key, required this.section, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? _anxietyAccentColor;
    final hasRealAnswers = section.contents.any((c) => c.hasRealContent);
    if (!hasRealAnswers) {
      return GenericSectionCard(
        section: section,
        accentColor: effectiveAccentColor,
      );
    }

    final filtered = <DiaryContent>[];
    for (final c in section.contents) {
      if (c is MarkdownContent) {
        final f = _filterEmptyQA(c.text);
        if (f.trim().isNotEmpty) {
          filtered.add(MarkdownContent(f));
        }
      } else {
        filtered.add(c);
      }
    }

    if (filtered.isEmpty) {
      return GenericSectionCard(
        section: section,
        accentColor: effectiveAccentColor,
      );
    }

    final filteredSection = GenericDiarySection(
      title: section.title,
      contents: filtered,
    );
    return GenericSectionCard(
      section: filteredSection,
      accentColor: effectiveAccentColor,
    );
  }

  static String _filterEmptyQA(String text) {
    final lines = text.split('\n');
    final buffer = StringBuffer();
    String? currentQuestion;

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;

      if (t.startsWith('- ') && _templateQuestionHint.hasMatch(t)) {
        currentQuestion = t;
        continue;
      }

      if (t.startsWith('>')) {
        final answer = t.substring(1).trim();
        if (answer.isNotEmpty && currentQuestion != null) {
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write(currentQuestion);
          buffer.write('\n> ');
          buffer.write(answer);
        }
        currentQuestion = null;
        continue;
      }
    }

    return buffer.toString();
  }
}
