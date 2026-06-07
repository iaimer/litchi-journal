import 'package:flutter/material.dart';

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
  final VoidCallback? onClose;

  const AnxietyComposer({
    super.key,
    required this.onSubmit,
    this.onClose,
  });

  @override
  State<AnxietyComposer> createState() => _AnxietyComposerState();
}

class _AnxietyComposerState extends State<AnxietyComposer> {
  int _step = 0;
  final _answers = List<String>.filled(4, '');
  final _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  bool _saving = false;
  String? _error;

  bool get _isLastStep => _step == 3;

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

  void _next() {
    _saveCurrentAnswer();
    if (_isLastStep) {
      _submit();
    } else {
      setState(() => _step++);
    }
  }

  void _skip() {
    if (_isLastStep) {
      widget.onClose?.call();
      return;
    }
    _answers[_step] = '';
    setState(() => _step++);
  }

  void _saveCurrentAnswer() {
    _answers[_step] = _controllers[_step].text;
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
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
          enabled: !_saving,
        ),
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
            if (widget.onClose != null)
              TextButton(
                onPressed: _saving ? null : () => widget.onClose?.call(),
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
