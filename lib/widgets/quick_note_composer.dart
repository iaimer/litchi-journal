import 'package:flutter/material.dart';

import '../models/tag_config.dart';
import '../services/draft_repository.dart';
import 'entry_type.dart';
import 'tag_picker.dart';

class QuickNoteComposer extends StatefulWidget {
  final Future<void> Function(String content, List<String> tags) onSubmit;
  final TagConfig? tagConfig;
  final String? tagHint;
  final String? placeholder;
  final DateTime? date;
  final EntryType? entryType;
  final DraftRepository? draftRepository;

  const QuickNoteComposer({
    super.key,
    required this.onSubmit,
    this.tagConfig,
    this.tagHint,
    this.placeholder,
    this.date,
    this.entryType,
    this.draftRepository,
  });

  @override
  State<QuickNoteComposer> createState() => _QuickNoteComposerState();
}

class _QuickNoteComposerState extends State<QuickNoteComposer> {
  final _controller = TextEditingController();
  List<String> _selectedTags = [];
  bool _saving = false;
  String? _error;

  bool get _canSubmit => !_saving && _controller.text.trim().isNotEmpty;

  void _saveDraft() {
    final dr = widget.draftRepository;
    final d = widget.date;
    final et = widget.entryType;
    if (dr == null || d == null || et == null) return;

    final content = _controller.text;
    if (content.trim().isEmpty && _selectedTags.isEmpty) {
      dr.clearDraft(date: d, entryType: et);
      return;
    }
    dr.saveQuickDraft(
      date: d,
      entryType: et,
      content: content,
      tags: List.unmodifiable(_selectedTags),
    );
  }

  Future<void> _clearDraft() async {
    final dr = widget.draftRepository;
    final d = widget.date;
    final et = widget.entryType;
    if (dr == null || d == null || et == null) return;
    await dr.clearDraft(date: d, entryType: et);
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _restoreDraft();
  }

  void _restoreDraft() {
    final dr = widget.draftRepository;
    final d = widget.date;
    final et = widget.entryType;
    if (dr == null || d == null || et == null) return;

    dr.loadQuickDraft(date: d, entryType: et).then((draft) {
      if (draft == null) return;
      if (!mounted) return;
      setState(() {
        _controller.text = draft.content;
        _selectedTags = List.unmodifiable(draft.tags);
      });
    });
  }

  void _onTextChanged() {
    setState(() {});
    _saveDraft();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (!_canSubmit) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(content, _selectedTags);
      if (!mounted) return;
      await _clearDraft();
      _controller.clear();
      setState(() => _selectedTags = []);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '保存失败，请重试';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagConfig = widget.tagConfig;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.placeholder ?? '写点什么...',
          ),
          maxLines: 3,
          enabled: !_saving,
        ),
        if (tagConfig != null) ...[
          const SizedBox(height: 10),
          TagPicker(
            tagConfig: tagConfig,
            initialTags: _selectedTags,
            onChanged: (tags) {
              setState(() => _selectedTags = tags);
              _saveDraft();
            },
          ),
        ] else if (widget.tagHint != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.tagHint!,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha(100),
              fontSize: 12,
              fontStyle: FontStyle.italic,
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
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('保存'),
          ),
        ),
      ],
    );
  }
}
