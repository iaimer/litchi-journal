import 'package:flutter/material.dart';

import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../widgets/entry_type.dart';
import '../widgets/tag_picker.dart';

class QuickCaptureScreen extends StatefulWidget {
  final EntryType entryType;
  final DateTime openedAt;
  final TagConfig? tagConfig;
  final String? tagHint;
  final Future<TimeOfDay?> Function(
    BuildContext context,
    TimeOfDay initialTime,
  )?
  timePicker;
  final Future<PolishResult> Function(String content, EntryType entryType)?
  onPolish;
  final Future<void> Function(String content, List<String> tags, String time)
  onSave;

  const QuickCaptureScreen({
    super.key,
    required this.entryType,
    required this.openedAt,
    required this.onSave,
    this.tagConfig,
    this.tagHint,
    this.timePicker,
    this.onPolish,
  }) : assert(entryType != EntryType.anxiety);

  @override
  State<QuickCaptureScreen> createState() => _QuickCaptureScreenState();
}

class _QuickCaptureScreenState extends State<QuickCaptureScreen> {
  final _controller = TextEditingController();
  late TimeOfDay _selectedTime;
  List<String> _selectedTags = [];
  bool _saving = false;
  bool _polishing = false;
  String? _error;

  bool get _hasUnsavedChanges =>
      _controller.text.trim().isNotEmpty || _selectedTags.isNotEmpty;

  bool get _canSave => !_saving && _controller.text.trim().isNotEmpty;

  bool get _canPolish =>
      !_saving &&
      !_polishing &&
      _controller.text.trim().isNotEmpty &&
      widget.onPolish != null;

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.fromDateTime(widget.openedAt);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _timeText =>
      '${_selectedTime.hour.toString().padLeft(2, '0')}:'
      '${_selectedTime.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picker = widget.timePicker;
    final picked = picker != null
        ? await picker(context, _selectedTime)
        : await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked == null || !mounted) return;
    setState(() => _selectedTime = picked);
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃记录？'),
        content: const Text('当前内容还没有保存，确定要离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscard() && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _polish() async {
    if (!_canPolish) return;
    setState(() {
      _polishing = true;
      _error = null;
    });

    try {
      final result = await widget.onPolish!(
        _controller.text.trim(),
        widget.entryType,
      );
      if (!mounted) return;
      setState(() {
        _controller.text = result.content;
        _selectedTags = result.tags;
        _controller.selection = TextSelection.collapsed(
          offset: result.content.length,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '润色失败，请重试');
    } finally {
      if (mounted) setState(() => _polishing = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSave(_controller.text.trim(), _selectedTags, _timeText);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
        title: Text(widget.entryType.label),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _buildTimeTile(theme),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 8,
            maxLines: 14,
            enabled: !_saving && !_polishing,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(hintText: widget.entryType.placeholder),
          ),
          const SizedBox(height: 16),
          _buildTagArea(theme),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _canPolish ? _polish : null,
              icon: _polishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Text('✨', style: TextStyle(fontSize: 14)),
              label: const Text('AI 润色'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Text('保存'),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTile(ThemeData theme) {
    return Card(
      child: ListTile(
        key: const Key('quick_capture_time_tile'),
        title: const Text('记录时间'),
        subtitle: Text('今天 $_timeText'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _saving ? null : _pickTime,
      ),
    );
  }

  Widget _buildTagArea(ThemeData theme) {
    final tagConfig = widget.tagConfig;
    if (tagConfig != null) {
      return TagPicker(
        tagConfig: tagConfig,
        initialTags: _selectedTags,
        onChanged: (tags) => setState(() => _selectedTags = tags),
      );
    }
    if (widget.tagHint == null) return const SizedBox.shrink();
    return Text(
      widget.tagHint!,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
