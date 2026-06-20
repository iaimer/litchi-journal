import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../widgets/flora_page_scaffold.dart';

/// 远程 API 信息页，只读展示当前连接配置。
class RemoteApiPage extends StatelessWidget {
  final ApiConfig apiConfig;
  final bool tokenConfigured;

  const RemoteApiPage({
    super.key,
    required this.apiConfig,
    this.tokenConfigured = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FloraPageScaffold(
      title: '远程 API',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoRow(theme, '服务器地址', apiConfig.baseUrl),
          const SizedBox(height: 16),
          _buildInfoRow(theme, 'Token 状态', tokenConfigured ? '已配置' : '未配置'),
          const SizedBox(height: 24),
        ],
      ),
    );
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
