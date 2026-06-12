import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../theme/app_theme.dart';
import 'about_page.dart';
import 'ai_settings_screen.dart';
import 'image_compress_page.dart';
import 'placeholder_page.dart';
import 'polish_prompt_page.dart';
import 'remote_api_page.dart';

/// 设置页主框架，底部导航第 4 个 Tab。
class SettingsPage extends StatelessWidget {
  final ApiConfig apiConfig;

  const SettingsPage({super.key, required this.apiConfig});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // ── 常用 ──
                  _buildSectionHeader(theme, '常用'),
                  _buildMenuItem(
                    context,
                    icon: '🎨',
                    title: '外观',
                    subtitle: '跟随系统',
                    onTap: () => _push(context, PlaceholderPage(title: '外观')),
                  ),
                  _buildMenuItem(
                    context,
                    icon: '🌱',
                    title: '习惯设置',
                    subtitle: '已启用 5 项',
                    onTap: () => _push(context, PlaceholderPage(title: '习惯设置')),
                  ),
                  _buildMenuItem(
                    context,
                    icon: '🏷️',
                    title: '标签设置',
                    subtitle: '标签管理',
                    onTap: () => _push(context, PlaceholderPage(title: '标签设置')),
                  ),
                  const SizedBox(height: 8),

                  // ── 连接与智能 ──
                  _buildSectionHeader(theme, '连接与智能'),
                  _buildMenuItem(
                    context,
                    icon: '☁️',
                    title: '远程 API',
                    subtitle: apiConfig.baseUrl,
                    onTap: () => _push(
                        context, RemoteApiPage(apiConfig: apiConfig)),
                  ),
                  _buildMenuItem(
                    context,
                    icon: '✨',
                    title: 'AI 服务配置',
                    subtitle: 'deepseek-v4-flash',
                    onTap: () => _push(
                        context, AiSettingsScreen(apiConfig: apiConfig)),
                  ),
                  _buildMenuItem(
                    context,
                    icon: '💬',
                    title: '润色提示词',
                    subtitle: '编辑润色与人生教练提示词',
                    onTap: () => _push(context, const PolishPromptPage()),
                  ),
                  const SizedBox(height: 8),

                  // ── 媒体与应用 ──
                  _buildSectionHeader(theme, '媒体与应用'),
                  _buildMenuItem(
                    context,
                    icon: '🖼️',
                    title: '图片压缩',
                    subtitle: '上传时自动压缩',
                    onTap: () => _push(context, const ImageCompressPage()),
                  ),
                  _buildMenuItem(
                    context,
                    icon: 'ℹ️',
                    title: '关于',
                    subtitle: '荔枝日记 Flutter 客户端',
                    onTap: () => _push(context, const AboutPage()),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('设置', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 4),
          Text(
            '管理你的日记应用',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Text(icon, style: const TextStyle(fontSize: 22)),
        title: Text(title, style: theme.textTheme.bodyMedium),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
