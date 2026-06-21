import 'package:flutter/material.dart';

import '../models/habit_settings.dart';
import '../models/habit_visual_config.dart';

import '../services/habit_settings_repository.dart';
import '../widgets/flora_page_scaffold.dart';

import '../widgets/flora_empty.dart';
import '../widgets/flora_icon.dart';
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

    return FloraPageScaffold(
      title: '习惯设置',
      body: HabitVisualConfig.defaults.isEmpty
          ? Center(child: const FloraEmpty(name: FloraIcons.emptyHabits))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明文案
            _buildDescription(theme),
            const SizedBox(height: 16),
            // 启用中的习惯
            ..._buildActiveSection(theme),
            // 已归档
            ..._buildArchivedSection(theme),
            const SizedBox(height: 16),
            // 新增习惯入口
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addNewHabit,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增习惯'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _addNewHabit() async {
    final key = 'custom_${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HabitEditScreen(habitKey: key, isCreateMode: true),
      ),
    );
    if (result == true) await _load();
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

  /// 按 key 构建习惯行，不再显示内联「启用中/已归档」标签
  /// （状态已由分区标题表达）。
  Widget _buildHabitRow(
    ThemeData theme, {
    required String key,
    required VoidCallback onTap,
  }) {
    final displayName = _settings.displayNameFor(key);
    final icon = _settings.iconFor(key);
    final color = Color(_settings.colorFor(key));
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
              // 名称
              Expanded(
                child: Text(
                  displayName,
                  style: theme.textTheme.bodyMedium,
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

  List<Widget> _buildActiveSection(ThemeData theme) {
    final keys = _settings.manageableKeys
        .where((k) => _settings.isActive(k))
        .toList();
    return [
      _buildSectionHeader(theme, '启用中的习惯', keys.length),
      const SizedBox(height: 8),
      ...keys.map((key) => _buildHabitRow(
            theme,
            key: key,
            onTap: () => _openEdit(key),
          )),
    ];
  }

  List<Widget> _buildArchivedSection(ThemeData theme) {
    final keys = _settings.manageableKeys
        .where((k) => !_settings.isActive(k))
        .toList();
    if (keys.isEmpty) return [];
    return [
      const SizedBox(height: 20),
      _buildSectionHeader(theme, '已归档', keys.length),
      const SizedBox(height: 8),
      ...keys.map((key) => _buildHabitRow(
            theme,
            key: key,
            onTap: () => _openEdit(key),
          )),
    ];
  }

  Widget _buildSectionHeader(ThemeData theme, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

}
