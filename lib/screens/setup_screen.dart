import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../services/api_client.dart';

class SetupScreen extends StatefulWidget {
  final void Function(ApiConfig config) onConfigured;

  const SetupScreen({super.key, required this.onConfigured});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlController =
      TextEditingController(text: 'https://obsidian.femkits.org');
  final _tokenController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscureToken = true;

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
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

    if (result.success) {
      await config.save();
      widget.onConfigured(config);
    } else {
      setState(() {
        _loading = false;
        _error = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('初始设置')),
      body: Padding(
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
            if (_error != null) ...[
              Text(
                _error!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _loading ? null : _testConnection,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('测试连接'),
            ),
          ],
        ),
      ),
    );
  }
}
