import 'package:flutter/material.dart';

/// 本地内容的更新时间独立于网络进度，失败时不遮挡阅读。
class ReadingCacheStatus extends StatelessWidget {
  final DateTime? updatedAt;
  final bool refreshing;
  final VoidCallback onRetry;
  final String? message;

  const ReadingCacheStatus({
    super.key,
    this.updatedAt,
    this.refreshing = false,
    required this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = updatedAt;
    final time = date == null
        ? null
        : '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message ??
                      (refreshing ? '正在显示本地内容，检查更新中' : '暂时无法连接，正在显示本地内容'),
                  style: theme.textTheme.bodySmall,
                ),
                if (time != null)
                  Text(
                    '上次更新 $time',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: refreshing ? null : onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
