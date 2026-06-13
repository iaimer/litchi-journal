import 'package:flutter/material.dart';

import '../models/ai_config.dart';
import '../services/ai_config_repository.dart';
import '../services/polisher_service.dart';
import '../theme/app_theme.dart';

/// 润色提示词编辑页。
class PolishPromptPage extends StatefulWidget {
  const PolishPromptPage({super.key});

  @override
  State<PolishPromptPage> createState() => _PolishPromptPageState();
}

class _PolishPromptPageState extends State<PolishPromptPage> {
  final _promptController = TextEditingController();
  final _coachPromptController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = AIConfigRepository();
    final config = await repo.loadAIConfig();
    if (!mounted) return;
    setState(() {
      _promptController.text = _effectivePrompt(config.polishPrompt);
      _coachPromptController.text = _effectiveCoachPrompt(config.coachPrompt);
    });
  }

  String _effectivePrompt(String? saved) {
    final trimmed = saved?.trim();
    return (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : PolisherService.defaultPolishPrompt;
  }

  String _effectiveCoachPrompt(String? saved) {
    final trimmed = saved?.trim();
    return (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : PolisherService.defaultCoachPrompt;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = AIConfigRepository();
      final config = await repo.loadAIConfig();
      final updated = AIConfig(
        enabled: config.enabled,
        name: config.name,
        baseUrl: config.baseUrl,
        apiKey: config.apiKey,
        model: config.model,
        polishPrompt: _promptController.text,
        coachPrompt: _coachPromptController.text,
      );
      await repo.saveAIConfig(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetPolishPrompt() {
    setState(() {
      _promptController.text = PolisherService.defaultPolishPrompt;
    });
  }

  void _resetCoachPrompt() {
    setState(() {
      _coachPromptController.text = PolisherService.defaultCoachPrompt;
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _coachPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('润色提示词'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '润色提示词',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '默认使用系统推荐提示词。你可以直接修改；修改后将使用你的版本。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetPolishPrompt,
              child: const Text('恢复默认润色提示词'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '人生教练提示词',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '用于生成「人生教练」模块的每日总结和建议。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _coachPromptController,
            maxLines: 8,
            minLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetCoachPrompt,
              child: const Text('恢复默认人生教练提示词'),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('保存'),
          ),
        ],
      ),
    );
  }
}
