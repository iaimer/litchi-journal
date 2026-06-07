import 'package:flutter/material.dart';

import '../services/draft_repository.dart';
import '../theme/app_theme.dart';
import 'entry_type.dart';

const _questions = [
  '今天什么时候我感到焦虑/紧张？',
  '当时我在担心什么？（具体到一句话）',
  '我做了什么？',
  '这个应对是帮我面对了，还是帮我躲开了？',
];

const _placeholders = [
  '描述当时的场景...',
  '我担心的是...',
  '我采取了什么行动...',
  '反思一下这个应对方式...',
];

class AnxietyComposer extends StatefulWidget {
  final Future<void> Function(String content, List<String> tags) onSubmit;
  final Future<String> Function(String content)? onPolish;
  final VoidCallback? onClose;
  final DateTime? date;
  final DraftRepository? draftRepository;
  final List<String>? initialAnswers;
  final bool isEdit;

  const AnxietyComposer({
    super.key,
    required this.onSubmit,
    this.onPolish,
    this.onClose,
    this.date,
    this.draftRepository,
    this.initialAnswers,
    this.isEdit = false,
  });

  static List<String> parseAnswers(String markdown) {
    final answers = List<String>.filled(4, '');
    final lines = markdown.split('\n');

    for (int i = 0; i < _questions.length; i++) {
      final questionText = _questions[i];
      var foundQuestion = false;

      for (int j = 0; j < lines.length; j++) {
        final line = lines[j].trim();
        if (line == '- $questionText' || line.startsWith('- ') && line.contains(questionText)) {
          foundQuestion = true;
          // Collect all blockquote lines following this question
          final buffer = StringBuffer();
          for (int k = j + 1; k < lines.length && lines[k].trim().startsWith('> '); k++) {
            if (buffer.isNotEmpty) buffer.write('\n');
            buffer.write(lines[k].trim().substring(2));
          }
          answers[i] = buffer.toString();
          break;
        }
      }

      if (!foundQuestion) break;
    }

    return answers;
  }

  @override
  State<AnxietyComposer> createState() => _AnxietyComposerState();
}

class _AnxietyComposerState extends State<AnxietyComposer> {
  int _step = 0;
  final _answers = List<String>.filled(4, '');
  final _controllers = List.generate(4, (_) => TextEditingController());
  bool _saving = false;
  bool _polishing = false;
  String? _error;

  bool get _isLastStep => _step == 3;

  bool get _canPolish =>
      !_polishing &&
      !_saving &&
      _controllers[_step].text.trim().isNotEmpty &&
      widget.onPolish != null;

  String _buildContent() {
    final buffer = StringBuffer();
    for (int i = 0; i < _questions.length; i++) {
      final answer = _answers[i].trim();
      if (i > 0) buffer.write('\n');
      buffer.write('- ');
      buffer.write(_questions[i]);
      buffer.write('\n> ');
      buffer.write(answer);
    }
    return buffer.toString();
  }

  void _saveDraft() {
    final dr = widget.draftRepository;
    final d = widget.date;
    if (dr == null || d == null) return;
    if (_answers.every((a) => a.isEmpty)) return;
    dr.saveAnxietyDraft(
      date: d,
      step: _step,
      answers: List.unmodifiable(_answers),
    );
  }

  Future<void> _clearDraft() async {
    final dr = widget.draftRepository;
    final d = widget.date;
    if (dr == null || d == null) return;
    await dr.clearDraft(date: d, entryType: EntryType.anxiety);
  }

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_onTextChanged);
    }
    _restoreDraft();
  }

  void _onTextChanged() {
    setState(() {}); // trigger rebuild for _canPolish
  }

  void _restoreDraft() {
    final dr = widget.draftRepository;
    final d = widget.date;

    if (dr != null && d != null) {
      dr.loadAnxietyDraft(date: d).then((draft) {
        if (!mounted) return;

        if (draft != null) {
          for (int i = 0; i < draft.answers.length && i < 4; i++) {
            _answers[i] = draft.answers[i];
            _controllers[i].text = draft.answers[i];
          }
          setState(() => _step = draft.step.clamp(0, 3));
          return;
        }

        _restoreInitialAnswers();
      });
      return;
    }

    _restoreInitialAnswers();
  }

  void _restoreInitialAnswers() {
    final initial = widget.initialAnswers;
    if (initial == null || initial.length != 4) return;
    for (int i = 0; i < 4; i++) {
      _answers[i] = initial[i];
      _controllers[i].text = initial[i];
    }
  }

  void _previous() {
    _saveCurrentAnswer();
    setState(() => _step--);
  }

  void _next() {
    _saveCurrentAnswer();
    if (_isLastStep) {
      _submit();
    } else {
      setState(() => _step++);
      _saveDraft();
    }
  }

  void _skip() {
    if (_isLastStep) {
      widget.onClose?.call();
      return;
    }
    _answers[_step] = '';
    setState(() => _step++);
    _saveDraft();
  }

  void _saveCurrentAnswer() {
    _answers[_step] = _controllers[_step].text;
    _saveDraft();
  }

  Future<void> _polish() async {
    if (!_canPolish) return;

    final onPolish = widget.onPolish!;
    final currentAnswer = _controllers[_step].text.trim();

    setState(() {
      _polishing = true;
      _error = null;
    });

    try {
      final result = await onPolish(currentAnswer);
      if (!mounted) return;
      _answers[_step] = result;
      _controllers[_step].text = result;
      _controllers[_step].selection = TextSelection.collapsed(
        offset: result.length,
      );
      _saveDraft();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().contains('请先在设置中启用')
          ? e.toString().replaceFirst('Exception: ', '')
          : '润色失败，请重试');
    } finally {
      if (mounted) setState(() => _polishing = false);
    }
  }

  Future<void> _submit() async {
    final content = _buildContent();
    if (content.trim().isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(content, []);
      if (!mounted) return;
      await _clearDraft();
      _reset();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _reset() {
    for (final c in _controllers) {
      c.clear();
    }
    for (int i = 0; i < _answers.length; i++) {
      _answers[i] = '';
    }
    setState(() => _step = 0);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(_onTextChanged);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_step + 1) / _questions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_step + 1}/${_questions.length}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.isEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '编辑今日焦虑记录',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Text(
          _questions[_step],
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controllers[_step],
          decoration: InputDecoration(
            hintText: _placeholders[_step],
          ),
          maxLines: 3,
          enabled: !_saving && !_polishing,
        ),
        if (widget.onPolish != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _canPolish ? _polish : null,
              icon: _polishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5),
                    )
                  : const Text('✨',
                      style: TextStyle(fontSize: 14)),
              label: const Text('润色当前回答'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(
                    color: AppColors.primary, width: 0.5),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 13,
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_step > 0)
              TextButton(
                onPressed: _saving ? null : _previous,
                child: const Text('上一步'),
              ),
            if (widget.onClose != null)
              TextButton(
                onPressed: _saving
                    ? null
                    : () => widget.onClose?.call(),
                child: const Text('关闭'),
              ),
            const Spacer(),
            TextButton(
              onPressed: _saving
                  ? null
                  : () {
                      _saveCurrentAnswer();
                      _skip();
                    },
              child: Text(_isLastStep ? '跳过' : '跳过'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _saving ? null : _next,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isLastStep ? '保存' : '下一步'),
            ),
          ],
        ),
      ],
    );
  }
}
