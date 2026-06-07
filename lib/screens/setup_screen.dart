import 'package:flutter/material.dart';

import '../models/ai_config.dart';
import '../services/ai_config_repository.dart';
import '../services/api_config.dart';
import '../services/api_client.dart';

class SetupScreen extends StatefulWidget {
  final void Function(ApiConfig config) onConfigured;
  final AIConfigRepository? aiConfigRepository;

  const SetupScreen({
    super.key,
    required this.onConfigured,
    this.aiConfigRepository,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlController =
      TextEditingController(text: 'https://obsidian.femkits.org');
  final _tokenController = TextEditingController();
  final _aiBaseUrlController = TextEditingController();
  final _aiApiKeyController = TextEditingController();
  final _aiModelController = TextEditingController();
  final _aiPromptController = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _obscureToken = true;
  bool _obscureApiKey = true;
  bool _aiEnabled = false;

  AIConfigRepository get _aiRepo =>
      widget.aiConfigRepository ?? AIConfigRepository();

  @override
  void initState() {
    super.initState();
    _loadAIConfig();
  }

  Future<void> _loadAIConfig() async {
    final config = await _aiRepo.loadAIConfig();
    if (!mounted) return;
    setState(() {
      _aiEnabled = config.enabled;
      _aiBaseUrlController.text = config.baseUrl;
      _aiApiKeyController.text = config.apiKey;
      _aiModelController.text = config.model;
      _aiPromptController.text = config.polishPrompt ?? '';
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _aiBaseUrlController.dispose();
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();

    if (url.isEmpty) {
      setState(() => _error = '请输入服务器地址');
      return;
    }
    if (token.isEmpty) {
      setState(() => _error = '请输入 Token');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final config = ApiConfig(baseUrl: url, token: token);
    final client = ApiClient(config);
    final result = await client.testConnection(DateTime.now());
    client.dispose();

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }

    await config.save();

    try {
      await _aiRepo.saveAIConfig(AIConfig(
        enabled: _aiEnabled,
        baseUrl: _aiBaseUrlController.text.trim(),
        apiKey: _aiApiKeyController.text.trim(),
        model: _aiModelController.text.trim(),
        polishPrompt: _aiPromptController.text.trim().isEmpty
            ? null
            : _aiPromptController.text.trim(),
      ));
    } catch (_) {
      // AI config save failure should not block main setup flow.
    }

    widget.onConfigured(config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('初始设置')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: 'https://obsidian.femkits.org',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: 'Token',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureToken
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscureToken = !_obscureToken),
                  ),
                ),
                obscureText: _obscureToken,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'AI 润色设置（可选）',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                title: const Text('启用 AI 润色'),
                value: _aiEnabled,
                onChanged: (value) =>
                    setState(() => _aiEnabled = value),
                contentPadding: EdgeInsets.zero,
              ),
              TextField(
                controller: _aiBaseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.openai.com',
                ),
                keyboardType: TextInputType.url,
                enabled: _aiEnabled,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _aiApiKeyController,
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
                enabled: _aiEnabled,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _aiModelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'gpt-4',
                ),
                enabled: _aiEnabled,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _aiPromptController,
                decoration: const InputDecoration(
                  labelText: '润色补充要求',
                  hintText: '可对 AI 润色风格做补充说明',
                ),
                maxLines: 3,
                minLines: 2,
                enabled: _aiEnabled,
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _loading ? null : _testConnection,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('测试连接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
