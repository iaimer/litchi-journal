import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_config.dart';
import '../widgets/flora_page_scaffold.dart';

/// 远程 API 信息页。
class RemoteApiPage extends StatefulWidget {
  final ApiConfig apiConfig;
  final ApiClient? apiClient;
  final bool tokenConfigured;
  final ValueChanged<ApiConfig>? onConfigChanged;
  final ApiClient Function(ApiConfig config)? createApiClient;

  const RemoteApiPage({
    super.key,
    required this.apiConfig,
    this.apiClient,
    this.tokenConfigured = true,
    this.onConfigChanged,
    this.createApiClient,
  });

  @override
  State<RemoteApiPage> createState() => _RemoteApiPageState();
}

class _RemoteApiPageState extends State<RemoteApiPage> {
  late String _baseUrl;
  TextEditingController? _baseUrlEditController;

  @override
  void initState() {
    super.initState();
    _baseUrl = widget.apiConfig.baseUrl;
  }

  @override
  void dispose() {
    _baseUrlEditController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FloraPageScaffold(
      title: '远程 API',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoRow(theme, '服务器地址', _baseUrl),
          const SizedBox(height: 16),
          _buildInfoRow(
            theme,
            'Token 状态',
            widget.tokenConfigured ? '已配置' : '未配置',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.apiClient == null ? null : _editBaseUrl,
            child: const Text('修改服务器地址'),
          ),
          const SizedBox(height: 8),
          Text(
            '保存后立即生效。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBaseUrl() async {
    _baseUrlEditController?.dispose();
    final controller = TextEditingController(text: _baseUrl);
    _baseUrlEditController = controller;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('修改服务器地址'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'http://<TAILSCALE_IP>:4001',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    final newUrl = controller.text.trim();
                    if (newUrl.isEmpty) {
                      setDialogState(() => error = '请输入服务器地址');
                      return;
                    }

                    final config = widget.apiClient!.configWithBaseUrl(newUrl);
                    final client =
                        widget.createApiClient?.call(config) ??
                        ApiClient(config);
                    final result = await client.testConnection(DateTime.now());
                    client.dispose();

                    if (!context.mounted) return;
                    if (!result.success) {
                      setDialogState(() => error = result.message);
                      return;
                    }

                    await config.save();
                    if (!context.mounted) return;
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    final newBaseUrl = controller.text.trim();
    if (!mounted || saved != true) return;

    final config = widget.apiClient!.configWithBaseUrl(newBaseUrl);
    widget.onConfigChanged?.call(config);
    setState(() => _baseUrl = newBaseUrl);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('服务器地址已保存并生效')));
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
