import 'package:flutter/material.dart';

import '../widgets/flora_icon.dart';

import '../models/habit_settings.dart';
import '../models/habit_visual_config.dart';
import '../services/habit_settings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/habit_icon.dart';
import 'habit_edit_screen.dart';

/// 习惯设置页面。
///
/// 控制哪些习惯在「今天页」和「习惯统计页」中显示。
/// 每个习惯可点击进入编辑页修改名称/图标/颜色/状态。
/// 归档后数据保留在历史中，可随时恢复。
class HabitSettingsScreen extends StatefulWidget {
  const HabitSettingsScreen({super.key});

  @override
  State<HabitSettingsScreen> createState() => HabitSettingsScreenState();
}

class HabitSettingsScreenState extends State<HabitSettingsScreen> {
  final _repo = HabitSettingsRepository();
  late HabitSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = HabitSettings.defaults;
    _load();
  }

  Future<void> _load() async {
    final settings = await _repo.load();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  /// 公开方法：外部刷新（SettingsPage 使用）
  Future<void> refresh() => _load();

  Future<void> _openEdit(String key) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => HabitEditScreen(habitKey: key)),
    );
    if (result == true) {
      // 编辑页保存成功，重载设置
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('习惯设置')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明文案
            _buildDescription(theme),
            const SizedBox(height: 16),
            // 习惯列表
            ...HabitVisualConfig.defaults.entries.map((entry) {
              final config = entry.value;
              final isActive = _settings.isActive(config.key);
              final displayName = _settings.displayNameFor(config.key);
              final icon = _settings.iconFor(config.key);
              final color = Color(_settings.colorFor(config.key));
              return _buildHabitRow(
                theme,
                config: config,
                displayName: displayName,
                icon: icon,
                color: color,
                isActive: isActive,
                onTap: () => _openEdit(config.key),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 8),
            child: FloraIcon(FloraIcons.settingHabits, size: 16),
          ),
          Expanded(
            child: Text(
              '点击习惯编辑名称、图标、颜色和状态。\n'
              '归档后将在今天页和统计页中隐藏。',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitRow(
    ThemeData theme, {
    required HabitVisualConfig config,
    required String displayName,
    required String icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // 颜色小圆点
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 10),
              // 图标
              HabitIcon(icon, size: 22, color: theme.colorScheme.onSurface),
              const SizedBox(width: 12),
              // 名称 + 状态
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isActive
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive ? '启用中' : '已归档',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isActive
                            ? AppColors.success
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // 右箭头
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
