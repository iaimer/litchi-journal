import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 图片压缩设置页。
class ImageCompressPage extends StatelessWidget {
  const ImageCompressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('图片压缩')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '当前配置',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.compress),
            title: Text('图片压缩'),
            subtitle: Text('上传时自动压缩图片'),
            trailing: Icon(Icons.check_circle, color: AppColors.success),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          Text(
            '图片上传时使用 ImageCompressService 自动压缩。\n后续会增加质量与尺寸设置。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
