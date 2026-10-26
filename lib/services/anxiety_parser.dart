import '../models/diary_document.dart';

final _questionLine = RegExp(r'^-\s+(.+[？?].*)$');

/// 旧四问的只读兼容入口，统一产出按原文顺序排列的领域内容。
AnxietySection parseAnxietySection(String title, List<DiaryContent> contents) {
  final parsed = <DiaryContent>[];
  for (final content in contents) {
    if (content is MarkdownContent) {
      parsed.addAll(_AnxietyBlockReader().parse(content.text));
    } else if (content.hasRealContent) {
      parsed.add(AnxietyLegacyBody(content));
    }
  }
  return AnxietySection(title: title, contents: parsed);
}

class _AnxietyBlockReader {
  final _parsed = <DiaryContent>[];
  final _bodyLines = <String>[];
  final _answerLines = <String>[];
  String? _question;
  bool _answerStarted = false;

  List<DiaryContent> parse(String markdown) {
    final lines = markdown.split('\n');
    for (var index = 0; index < lines.length; index++) {
      _consumeLine(
        lines[index],
        followingLine: index + 1 < lines.length ? lines[index + 1] : null,
      );
    }
    _finishQuestion();
    _flushBody();
    return _parsed;
  }

  void _consumeLine(String line, {String? followingLine}) {
    final trimmed = line.trim();
    final nextQuestion = _questionLine.firstMatch(trimmed)?.group(1);
    if (_startsQuestion(nextQuestion, followingLine)) {
      _finishQuestion();
      _flushBody();
      _question = nextQuestion!.trim();
      return;
    }

    if (_question == null) {
      _bodyLines.add(line);
      return;
    }
    if (trimmed.isEmpty) {
      if (_answerStarted) _answerLines.add('');
      return;
    }
    if (trimmed.startsWith('>')) {
      _answerStarted = true;
      _answerLines.add(trimmed.substring(1).trimLeft());
      return;
    }
    if (_answerStarted) {
      _answerLines.add(line);
      return;
    }

    _finishQuestion();
    _bodyLines.add(line);
  }

  bool _startsQuestion(String? question, String? followingLine) {
    if (question == null) return false;
    return _question == null ||
        !_answerStarted ||
        LegacyAnxietyQuestion.fromPrompt(question) != null ||
        (followingLine?.trimLeft().startsWith('>') ?? false);
  }

  void _finishQuestion() {
    final question = _question;
    if (question == null) return;
    final answer = _answerLines.join('\n').trim();
    if (_answerStarted && answer.isNotEmpty) {
      _parsed.add(AnxietyAnswer(question: question, answer: answer));
    } else if (LegacyAnxietyQuestion.fromPrompt(question) == null) {
      _parsed.add(AnxietyLegacyBody(MarkdownContent('- $question')));
    }
    _question = null;
    _answerStarted = false;
    _answerLines.clear();
  }

  void _flushBody() {
    final body = _bodyLines.join('\n').trim();
    if (body.isNotEmpty) {
      _parsed.add(AnxietyLegacyBody(MarkdownContent(body)));
    }
    _bodyLines.clear();
  }
}
