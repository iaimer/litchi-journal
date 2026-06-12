import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../theme/app_theme.dart';

/// 远程 API 信息页，只读展示当前连接配置。
class RemoteApiPage extends StatelessWidget {
  final ApiConfig apiConfig;

  const RemoteApiPage({super.key, required this.apiConfig});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('远程 API')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoRow(theme, '服务器地址', apiConfig.baseUrl),
          const SizedBox(height: 16),
          _buildInfoRow(theme, 'Token 状态', '已配置'),
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
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
