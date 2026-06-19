import 'package:flutter/material.dart';

import '../widgets/flora_icon.dart';

import '../services/ai_config_repository.dart';
import '../services/api_config.dart';
import '../services/habit_settings_repository.dart';
import '../services/api_client.dart';
import '../services/tag_repository.dart';
import '../services/tag_settings_helper.dart';
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
class SettingsPage extends StatefulWidget {
  final ApiConfig apiConfig;
  final ApiClient? apiClient;
  final bool tokenConfigured;

  const SettingsPage({
    super.key,
    required this.apiConfig,
    this.apiClient,
    this.tokenConfigured = true,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _habitSettingsRepo = HabitSettingsRepository();
  final _aiConfigRepo = AIConfigRepository();
  int _activeHabitCount = 5;
  int _tagCount = 0;
  String _aiModelName = '';

  ApiClient get _apiClient => widget.apiClient ?? ApiClient(widget.apiConfig);

  @override
  void initState() {
    super.initState();
    _loadHabitCount();
    _loadTagCount();
    _loadAIModelName();
  }

  Future<void> _loadHabitCount() async {
    try {
      final settings = await _habitSettingsRepo.load();
      if (!mounted) return;
      setState(() => _activeHabitCount = settings.activeCount);
    } catch (_) {
      // 静默失败，保持默认
    }
  }

  Future<void> _loadTagCount() async {
    try {
      final tagRepo = TagRepository(apiClient: _apiClient);
      final tagConfig = await tagRepo.loadTagConfig();
      final tagSettingsRepo = TagSettingsRepository();
      final tagSettings = await tagSettingsRepo.loadTagSettings(tagConfig);
      if (!mounted) return;
      setState(() => _tagCount = TagSettingsHelper.countEnabled(tagSettings));
    } catch (_) {
      // 静默失败，subtitle 保持"标签管理"
    }
  }

  Future<void> _openTagSettings() async {
    try {
      final tagRepo = TagRepository(apiClient: _apiClient);
      final tagConfig = await tagRepo.loadTagConfig();
      final tagSettingsRepo = TagSettingsRepository();
      final tagSettings = await tagSettingsRepo.loadTagSettings(tagConfig);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TagSettingsPage(
            initialSettings: tagSettings,
            tagConfig: tagConfig,
          ),
        ),
      );
      await _loadTagCount();
    } catch (_) {
      // 静默失败
    }
  }

  Future<void> _loadAIModelName() async {
    try {
      final config = await _aiConfigRepo.loadAIConfig();
      if (!mounted) return;
      setState(() => _aiModelName = config.resolvedModel);
    } catch (_) {
      // 静默失败，保持默认空
    }
  }

  Future<void> _openHabitSettings() async {
    final screen = HabitSettingsScreen();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    // 返回后刷新习惯数量
    await _loadHabitCount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const FloraIcon(FloraIcons.back, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildSectionHeader(theme, '常用'),
          _buildMenuItem(
            context,
            icon: const FloraIcon(FloraIcons.settingAppearance, size: 22),
            title: '外观',
            subtitle: '跟随系统',
            onTap: () => _push(context, const AppearanceSettingsPage()),
          ),
          _buildMenuItem(
            context,
            icon: const FloraIcon(FloraIcons.settingHabits, size: 22),
            title: '习惯设置',
            subtitle: '已启用 $_activeHabitCount 项',
            onTap: _openHabitSettings,
          ),
          _buildMenuItem(
            context,
            icon: const FloraIcon(FloraIcons.settingTags, size: 22),
            title: '标签设置',
            subtitle: _tagCount > 0 ? '已启用 $_tagCount 个标签' : '标签管理',
            onTap: _openTagSettings,
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(theme, '连接与智能'),
          _buildMenuItem(
            context,
            icon: const FloraIcon(FloraIcons.settingCloud, size: 22),
            title: '远程 API',
            subtitle: widget.apiConfig.baseUrl,
            onTap: () => _push(
              context,
              RemoteApiPage(
                apiConfig: widget.apiConfig,
                tokenConfigured: widget.tokenConfigured,
              ),
            ),
          ),
          _buildMenuItem(
            context,
            icon: const FloraIcon(FloraIcons.settingAi, size: 22),
            title: 'AI 服务配置',
            subtitle: _aiModelName.isNotEmpty ? _aiModelName : '未配置',
            onTap: () async {
              await _push(
                context,
                AiSettingsScreen(apiConfig: widget.apiConfig),
              );
              await _loadAIModelName();
            },
          ),
          _buildMenuItem(
            context,
            icon: const FloraIcon(FloraIcons.settingPrompt, size: 22),
            title: '润色提示词',
            subtitle: '编辑润色与人生教练提示词',
            onTap: () => _push(context, const PolishPromptPage()),
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(theme, '媒体与应用'),
          _buildMenuItem(
            context,
            icon: const FloraIcon(FloraIcons.settingImage, size: 22),
            title: '图片设置',
            subtitle: '压缩与文件命名',
            onTap: () => _push(context, const ImageCompressPage()),
          ),
          _buildMenuItem(
            context,
            icon: const FloraIcon(FloraIcons.settingAbout, size: 22),
            title: '关于',
            subtitle: '荔枝日记 Flutter 客户端',
            onTap: () => _push(context, const AboutPage()),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _push(BuildContext context, Widget page) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required Widget icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: SizedBox(width: 22, height: 22, child: icon),
        title: Text(title, style: theme.textTheme.bodyMedium),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
