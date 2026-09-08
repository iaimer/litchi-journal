import 'package:flutter/material.dart';

import '../widgets/flora_icon.dart';
import '../widgets/flora_page_scaffold.dart';

import '../services/api_config.dart';
import '../services/api_client.dart';
import '../services/tag_repository.dart';
import '../services/tag_settings_repository.dart';
import 'about_page.dart';
import 'appearance_settings_page.dart';
import 'ai_settings_screen.dart';
import 'habit_settings_screen.dart';
import 'tag_settings_page.dart';
import 'image_compress_page.dart';
import 'polish_prompt_page.dart';
import 'remote_api_page.dart';

/// 设置页主框架。
class SettingsPage extends StatelessWidget {
  final ApiConfig apiConfig;
  final ApiClient? apiClient;
  final bool tokenConfigured;
  final ValueChanged<ApiConfig>? onApiConfigChanged;

  const SettingsPage({
    super.key,
    required this.apiConfig,
    this.apiClient,
    this.tokenConfigured = true,
    this.onApiConfigChanged,
  });

  ApiClient get _apiClient => apiClient ?? ApiClient(apiConfig);

  Future<void> _openTagSettings(BuildContext context) async {
    try {
      final tagRepo = TagRepository(apiClient: _apiClient);
      final tagConfig = await tagRepo.loadTagConfig();
      final tagSettingsRepo = TagSettingsRepository();
      final tagSettings = await tagSettingsRepo.loadTagSettings(tagConfig);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TagSettingsPage(
            initialSettings: tagSettings,
            tagConfig: tagConfig,
          ),
        ),
      );
    } catch (_) {
      // 静默失败
    }
  }

  Future<void> _openHabitSettings(BuildContext context) =>
      _push(context, const HabitSettingsScreen());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FloraPageScaffold(
      title: '设置',
      leading: IconButton(
        icon: const FloraIcon(FloraIcons.back, size: 24),
        onPressed: () => Navigator.of(context).pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _buildSectionHeader(theme, '常用'),
          _buildMenuGroup(context, [
            _SettingsMenuItem(
              icon: const FloraIcon(FloraIcons.settingAppearance, size: 22),
              title: '外观',
              onTap: () => _push(context, const AppearanceSettingsPage()),
            ),
            _SettingsMenuItem(
              icon: const FloraIcon(FloraIcons.settingHabits, size: 22),
              title: '习惯设置',
              onTap: () => _openHabitSettings(context),
            ),
            _SettingsMenuItem(
              icon: const FloraIcon(FloraIcons.settingTags, size: 22),
              title: '标签设置',
              onTap: () => _openTagSettings(context),
            ),
          ]),
          _buildSectionHeader(theme, '连接与智能'),
          _buildMenuGroup(context, [
            _SettingsMenuItem(
              icon: const FloraIcon(FloraIcons.settingCloud, size: 22),
              title: '远程 API',
              onTap: () => _push(
                context,
                RemoteApiPage(
                  apiConfig: apiConfig,
                  apiClient: apiClient,
                  tokenConfigured: tokenConfigured,
                  onConfigChanged: onApiConfigChanged,
                ),
              ),
            ),
            _SettingsMenuItem(
              icon: const FloraIcon(FloraIcons.settingAi, size: 22),
              title: 'AI 服务配置',
              onTap: () =>
                  _push(context, AiSettingsScreen(apiConfig: apiConfig)),
            ),
            _SettingsMenuItem(
              icon: const FloraIcon(FloraIcons.settingPrompt, size: 22),
              title: '润色提示词',
              onTap: () => _push(context, const PolishPromptPage()),
            ),
          ]),
          _buildSectionHeader(theme, '媒体与应用'),
          _buildMenuGroup(context, [
            _SettingsMenuItem(
              icon: const FloraIcon(FloraIcons.settingImage, size: 22),
              title: '图片设置',
              onTap: () => _push(context, const ImageCompressPage()),
            ),
            _SettingsMenuItem(
              icon: const FloraIcon(FloraIcons.settingAbout, size: 22),
              title: '关于',
              onTap: () => _push(context, const AboutPage()),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _push(BuildContext context, Widget page) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMenuGroup(BuildContext context, List<_SettingsMenuItem> items) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _buildMenuItem(context, item: items[index]),
            if (index < items.length - 1)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 52,
                endIndent: 16,
                color: theme.colorScheme.onSurface.withAlpha(28),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required _SettingsMenuItem item,
  }) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: item.title,
      child: SizedBox(
        key: ValueKey('settings-item-${item.title}'),
        height: 56,
        child: InkWell(
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(width: 22, height: 22, child: item.icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsMenuItem {
  final Widget icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}
