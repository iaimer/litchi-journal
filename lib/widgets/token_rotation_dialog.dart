import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';

class TokenRotationDialog extends StatefulWidget {
  final String baseUrl;
  final ApiClient Function(ApiConfig)? createApiClient;
  const TokenRotationDialog({
    super.key,
    required this.baseUrl,
    this.createApiClient,
  });
  @override
  State<TokenRotationDialog> createState() => _TokenRotationDialogState();
}

class _TokenRotationDialogState extends State<TokenRotationDialog> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = _controller.text.trim();
    if (token.length < 32 || RegExp(r'\s').hasMatch(token)) {
      setState(() => _error = '请输入至少32个字符且不含空白的新 Token');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final config = ApiConfig(baseUrl: widget.baseUrl, token: token);
    ApiClient? client;
    try {
      client = widget.createApiClient?.call(config) ?? ApiClient(config);
      final result = await client.testConnection(DateTime.now());
      if (!mounted) return;
      if (!result.success) {
        setState(() => _error = result.message);
        return;
      }
      await config.save();
      if (mounted) Navigator.of(context).pop(config);
    } catch (_) {
      if (mounted) setState(() => _error = '验证或保存失败，请检查连接后重试');
    } finally {
      client?.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('更换 Token'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('先在服务端启用新 Token，再验证并保存。其他配置保持不变。'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_saving,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              decoration: const InputDecoration(
                labelText: '新 Token',
                hintText: '至少32个字符',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '正在验证…' : '验证并保存'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
