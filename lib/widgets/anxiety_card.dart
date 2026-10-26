import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/diary_document.dart';
import '../theme/app_theme.dart';
import '../theme/diary_reading_style.dart';
import 'journal_section.dart';

class AnxietyCard extends StatelessWidget {
  final AnxietySection section;
  final Color? accentColor;

  const AnxietyCard({super.key, required this.section, this.accentColor});

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    var answerIndex = 0;
    var previousWasAnswer = false;
    for (final content in section.contents) {
      final child = switch (content) {
        AnxietyAnswer() => _buildAnswer(context, content, answerIndex++),
        AnxietyLegacyBody() => _buildLegacyBody(context, content),
        _ => _buildLegacyBody(context, AnxietyLegacyBody(content)),
      };
      if (child == null) continue;
      if (children.isNotEmpty) {
        children.add(
          SizedBox(
            height: content is AnxietyAnswer && previousWasAnswer ? 20 : 12,
          ),
        );
      }
      children.add(child);
      previousWasAnswer = content is AnxietyAnswer;
    }
    if (children.isEmpty) return const SizedBox.shrink();

    return JournalSection(
      title: '焦虑时刻',
      accentColor: accentColor ?? TodayRainbow.anxiety,
      children: children,
    );
  }

  Widget _buildAnswer(BuildContext context, AnxietyAnswer item, int index) {
    final theme = Theme.of(context);
    final questionStyle = DiaryReadingStyle.of(
      context,
    ).metadata(theme).copyWith(fontWeight: FontWeight.w600, height: 1.45);
    return Padding(
      padding: EdgeInsets.only(right: journalFabSafetyInset(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 10),
                child: DecoratedBox(
                  key: ValueKey<String>('anxiety_question_marker_$index'),
                  decoration: BoxDecoration(
                    color: accentColor ?? TodayRainbow.anxiety,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 6, height: 6),
                ),
              ),
              Expanded(child: Text(item.question, style: questionStyle)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              item.answer,
              style: DiaryReadingStyle.of(context).body(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildLegacyBody(BuildContext context, AnxietyLegacyBody legacyBody) {
    if (!legacyBody.hasRealContent) return null;
    final content = legacyBody.content;
    final markdown = switch (content) {
      MarkdownContent() => content.text,
      CalloutContent() => [
        '> [!${content.type}]${content.title.isEmpty ? '' : ' ${content.title}'}',
        ...content.body.map((line) => '> $line'),
      ].join('\n'),
      CheckboxContent() => content.rawLine,
      TimelineContent() => content.rawLine,
      SubSectionContent() => '### ${content.title}',
      MediaPhotoContent() => content.photo.rawLine,
      _ => '',
    };
    if (markdown.isEmpty) return null;
    return MarkdownBody(
      data: markdown,
      selectable: true,
      styleSheet: DiaryReadingStyle.of(context).markdown(Theme.of(context)),
    );
  }
}
