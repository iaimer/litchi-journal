import 'package:flutter/material.dart';

import '../services/appearance_controller.dart';

/// 外观设置页面。
/// 支持跟随系统 / 浅色模式 / 深色模式。
class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  late ThemeMode _selected;

  @override
  void initState() {
    super.initState();
    _selected = AppearanceController.instance.themeMode;
  }

  Future<void> _select(ThemeMode mode) async {
    setState(() => _selected = mode);
    await AppearanceController.instance.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '选择你喜欢的显示方式',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _buildOption(
            icon: Icons.phone_android_outlined,
            title: '跟随系统',
            subtitle: '跟随手机系统的深色或浅色设置。',
            mode: ThemeMode.system,
          ),
          _buildOption(
            icon: Icons.light_mode_outlined,
            title: '浅色模式',
            subtitle: '始终使用浅色外观。',
            mode: ThemeMode.light,
          ),
          _buildOption(
            icon: Icons.dark_mode_outlined,
            title: '深色模式',
            subtitle: '始终使用深色外观。',
            mode: ThemeMode.dark,
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeMode mode,
  }) {
    final selected = _selected == mode;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        onTap: () => _select(mode),
      ),
    );
  }
}
