import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/diary_document.dart';
import 'journal_section.dart';

final _templateQuestionHint = RegExp(r'[？?]');
const _anxietyAccentColor = Color(0xFFFFD43B);

class AnxietyCard extends StatelessWidget {
  final AnxietySection section;
  final Color? accentColor;

  const AnxietyCard({super.key, required this.section, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? _anxietyAccentColor;
    final parsed = _parseContent();
    final hasRealAnswers = parsed.any((item) => item.answer != null);
    final visibleItems = hasRealAnswers
        ? parsed.where((item) => item.answer != null).toList()
        : parsed;

    final children = <Widget>[];
    if (visibleItems.isNotEmpty) {
      children.add(
        Padding(
          padding: EdgeInsets.only(right: journalFabSafetyInset(context)),
          child: _AnxietyOpenGroup(
            accentColor: effectiveAccentColor,
            items: visibleItems,
          ),
        ),
      );
    }
    if (children.isEmpty) {
      children.addAll(_fallbackContent(context));
    }
    if (children.isEmpty) return const SizedBox.shrink();

    return JournalSection(
      title: '焦虑时刻',
      accentColor: effectiveAccentColor,
      children: children,
    );
  }

  List<_AnxietyItem> _parseContent() {
    final items = <_AnxietyItem>[];
    for (final content in section.contents) {
      if (content is MarkdownContent) {
        items.addAll(_parseQuestionAnswers(content.text));
      }
    }
    return items;
  }

  List<Widget> _fallbackContent(BuildContext context) {
    final markdown = section.contents
        .whereType<MarkdownContent>()
        .map((content) => content.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');
    if (markdown.isEmpty) return const [];

    final theme = Theme.of(context);
    return [
      MarkdownBody(
        data: markdown,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(
          theme,
        ).copyWith(p: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
      ),
    ];
  }

  static List<_AnxietyItem> _parseQuestionAnswers(String text) {
    final lines = text.split('\n');
    String? currentQuestion;
    final items = <_AnxietyItem>[];

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;

      if (t.startsWith('- ') && _templateQuestionHint.hasMatch(t)) {
        if (currentQuestion != null) {
          items.add(_AnxietyItem(question: currentQuestion));
        }
        currentQuestion = t.substring(2).trim();
        continue;
      }

      if (t.startsWith('>')) {
        final answer = t.substring(1).trim();
        if (currentQuestion != null) {
          items.add(
            _AnxietyItem(
              question: currentQuestion,
              answer: answer.isEmpty ? null : answer,
            ),
          );
          currentQuestion = null;
        }
        continue;
      }
    }

    if (currentQuestion != null) {
      items.add(_AnxietyItem(question: currentQuestion));
    }
    return items;
  }
}

class _AnxietyItem {
  final String question;
  final String? answer;

  const _AnxietyItem({required this.question, this.answer});
}

class _AnxietyOpenGroup extends StatelessWidget {
  final Color accentColor;
  final List<_AnxietyItem> items;

  const _AnxietyOpenGroup({required this.accentColor, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _buildItem(context, items[index], index),
          if (index < items.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildItem(BuildContext context, _AnxietyItem item, int index) {
    final theme = Theme.of(context);
    final questionStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.45,
    );
    final answer = item.answer;
    return Column(
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
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 6, height: 6),
              ),
            ),
            Expanded(child: Text(item.question, style: questionStyle)),
          ],
        ),
        if (answer != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              answer,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
      ],
    );
  }
}
