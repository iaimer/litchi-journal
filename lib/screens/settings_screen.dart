import 'package:flutter/material.dart';

import '../models/ai_config.dart';
import '../services/ai_config_repository.dart';
import '../services/api_config.dart';
import '../services/polisher_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final ApiConfig apiConfig;

  const SettingsScreen({super.key, required this.apiConfig});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _promptController = TextEditingController();
  final _coachPromptController = TextEditingController();

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
      _promptController.text = _effectivePrompt(config.polishPrompt);
      _coachPromptController.text =
          _effectiveCoachPrompt(config.coachPrompt);
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
      await repo.saveAIConfig(AIConfig(
        enabled: _enabled,
        name: _nameController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(),
        polishPrompt: _promptController.text.trim().isEmpty
            ? null
            : _promptController.text.trim(),
        coachPrompt: _coachPromptController.text.trim().isEmpty
            ? null
            : _coachPromptController.text.trim(),
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
    _promptController.dispose();
    _coachPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(title: '连接信息'),
              _ReadOnlyField(
                label: '服务器地址',
                value: widget.apiConfig.baseUrl,
              ),
              const SizedBox(height: 8),
              const _ReadOnlyField(
                label: 'Token',
                value: '已配置',
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              _SectionHeader(title: 'AI 润色设置'),
              const SizedBox(height: 4),
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
              const SizedBox(height: 16),
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
                key: const Key('polishPromptField'),
                maxLines: 5,
                minLines: 3,
                enabled: _enabled,
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
                  onPressed: _enabled
                      ? () => setState(() => _promptController.text =
                          PolisherService.defaultPolishPrompt)
                      : null,
                  child: const Text('恢复默认润色提示词'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '人生教练提示词',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '默认使用系统推荐提示词。你可以直接修改；修改后将使用你的版本。',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _coachPromptController,
                key: const Key('coachPromptField'),
                maxLines: 5,
                minLines: 3,
                enabled: _enabled,
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
                  onPressed: _enabled
                      ? () => setState(() => _coachPromptController.text =
                          PolisherService.defaultCoachPrompt)
                      : null,
                  child: const Text('恢复默认人生教练提示词'),
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style:
                        TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('保存 AI 配置'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          '$label：',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
