import 'package:flutter/material.dart';

import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../services/tag_settings_helper.dart';
import 'tag_picker.dart';

class EntryEditSheet extends StatefulWidget {
  final String initialContent;
  final List<String> initialTags;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;
  final Future<void> Function(String content, List<String> tags) onSave;

  const EntryEditSheet({
    super.key,
    required this.initialContent,
    required this.initialTags,
    this.tagConfig,
    this.tagSettings,
    required this.onSave,
  });

  @override
  State<EntryEditSheet> createState() => _EntryEditSheetState();
}

class _EntryEditSheetState extends State<EntryEditSheet> {
  late final TextEditingController _controller;
  late List<String> _selectedTags;
  late List<String> _hiddenInitialTags;
  bool _saving = false;

  bool get _canSave => _controller.text.trim().isNotEmpty && !_saving;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _selectedTags =
        widget.initialTags.map((t) => t.startsWith('#') ? t.substring(1) : t).toList();

    // 计算隐藏标签
    _hiddenInitialTags = (widget.tagConfig != null && widget.tagSettings != null)
        ? TagSettingsHelper.hiddenInitialTags(
            _selectedTags, widget.tagSettings!)
        : [];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_controller.text.trim(), _selectedTags);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('更新失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTagConfig = (widget.tagConfig != null && widget.tagSettings != null)
        ? TagSettingsHelper.effectiveTagConfig(widget.tagConfig!, widget.tagSettings!)
        : widget.tagConfig;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '编辑记录',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 4,
              minLines: 2,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            if (effectiveTagConfig != null) ...[
              const SizedBox(height: 12),
              TagPicker(
                tagConfig: effectiveTagConfig,
                initialTags: _selectedTags,
                hiddenInitialTags: _hiddenInitialTags,
                onChanged: (tags) => _selectedTags = tags,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canSave ? _save : null,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
