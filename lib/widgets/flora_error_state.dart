import 'package:flutter/material.dart';

import 'flora_icon.dart';

/// 页面级错误状态，保持内容区域轻量并提供明确的重试入口。
class FloraErrorState extends StatelessWidget {
  const FloraErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.padding = const EdgeInsets.only(top: 64),
  });

  final String message;
  final VoidCallback onRetry;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloraIcon(
              FloraIcons.error,
              size: 32,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRetry,
              icon: const FloraIcon(FloraIcons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
