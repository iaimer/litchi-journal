import 'package:flutter/material.dart';

import '../models/ai_config.dart';
import '../services/ai_config_repository.dart';
import '../services/api_config.dart';
import '../widgets/flora_page_scaffold.dart';

/// AI 服务配置页。
class AiSettingsScreen extends StatefulWidget {
  final ApiConfig apiConfig;

  const AiSettingsScreen({super.key, required this.apiConfig});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();

  bool _enabled = false;
  bool _obscureApiKey = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAIConfig();
  }

  Future<void> _loadAIConfig() async {
    final repo = AIConfigRepository();
    final config = await repo.loadAIConfig();
    if (!mounted) return;
    setState(() {
      _enabled = config.enabled;
      _nameController.text = config.name;
      _baseUrlController.text = config.baseUrl;
      _apiKeyController.text = config.apiKey;
      _modelController.text = config.model;
    });
  }

  void _applyPreset(AIPreset preset) {
    setState(() {
      _nameController.text = preset.name;
      _baseUrlController.text = preset.baseUrl;
      _modelController.text = preset.model;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = AIConfigRepository();
      // 保留现有提示词
      final existing = await repo.loadAIConfig();
      await repo.saveAIConfig(AIConfig(
        enabled: _enabled,
        name: _nameController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(),
        polishPrompt: existing.polishPrompt,
        coachPrompt: existing.coachPrompt,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('AI 配置已保存')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '保存失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FloraPageScaffold(
      title: 'AI 服务配置',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: const Text('启用 AI 润色'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Text(
              '快速选择预设',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: aiPresets.map((preset) {
                return ActionChip(
                  label: Text(preset.name,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: _enabled
                      ? () => _applyPreset(preset)
                      : null,
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '服务商名称',
                hintText: '例如：OpenAI API',
              ),
              enabled: _enabled,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://api.openai.com',
              ),
              keyboardType: TextInputType.url,
              enabled: _enabled,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'API Key',
                suffixIcon: IconButton(
                  icon: Icon(_obscureApiKey
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () => setState(
                      () => _obscureApiKey = !_obscureApiKey),
                ),
              ),
              obscureText: _obscureApiKey,
              enabled: _enabled,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Model',
                hintText: 'gpt-4o-mini',
              ),
              enabled: _enabled,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: theme.colorScheme.onPrimary),
                    )
                  : const Text('保存 AI 配置'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
