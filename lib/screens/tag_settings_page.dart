import 'package:flutter/material.dart';

import '../widgets/flora_icon.dart';
import '../widgets/flora_page_scaffold.dart';

import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../services/tag_settings_helper.dart';
import '../services/tag_settings_repository.dart';
import '../widgets/flora_empty.dart';

/// 标签设置页面。
/// 允许修改标签的显示名称、启用 / 隐藏、恢复默认。
class TagSettingsPage extends StatefulWidget {
  final TagSettings initialSettings;
  final TagConfig tagConfig;

  const TagSettingsPage({
    super.key,
    required this.initialSettings,
    required this.tagConfig,
  });

  @override
  State<TagSettingsPage> createState() => _TagSettingsPageState();
}

class _TagSettingsPageState extends State<TagSettingsPage> {
  late TagSettings _settings;
  late final TagSettingsRepository _repo;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _repo = TagSettingsRepository();
  }

  int get _enabledCount => TagSettingsHelper.countEnabled(_settings);

  Future<void> _save() async {
    await _repo.saveTagSettings(_settings);
  }

  void _editDomainName(DomainSetting setting) {
    _editNameDialog(
      title: '编辑领域标签',
      currentName: setting.displayName,
      onSave: (newName) {
        setState(() => setting.displayName = newName);
        _save();
      },
    );
  }

  void _editTopicName(TopicSetting setting) {
    _editNameDialog(
      title: '编辑主题标签',
      currentName: setting.displayName,
      onSave: (newName) {
        setState(() => setting.displayName = newName);
        _save();
      },
    );
  }

  void _editMethodName(MethodSetting setting) {
    _editNameDialog(
      title: '编辑方法标签',
      currentName: setting.displayName,
      onSave: (newName) {
        setState(() => setting.displayName = newName);
        _save();
      },
    );
  }

  void _editNameDialog({
    required String title,
    required String currentName,
    required ValueChanged<String> onSave,
  }) {
    final controller = TextEditingController(text: currentName);
    String? error;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '标签名称',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setDialogState(() => error = null);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    final name = controller.text;
                    final validationError =
                        TagSettingsHelper.validateDisplayName(name);
                    if (validationError != null) {
                      setDialogState(() => error = validationError);
                      return;
                    }
                    Navigator.pop(ctx);
                    onSave(name.trim());
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _restoreDomain(DomainSetting setting) {
    setState(() {
      setting.displayName = setting.defaultName;
      setting.enabled = true;
    });
    _save();
  }

  void _restoreTopic(TopicSetting setting) {
    setState(() {
      setting.displayName = setting.defaultName;
      setting.enabled = true;
    });
    _save();
  }

  void _restoreMethod(MethodSetting setting) {
    setState(() {
      setting.displayName = setting.defaultName;
      setting.enabled = true;
    });
    _save();
  }

  Future<void> _restoreAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复全部默认'),
        content: const Text('所有标签将恢复为默认名称并启用。\n已有日记中的标签不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() {
      _settings = TagSettings.fromTagConfig(widget.tagConfig);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FloraPageScaffold(
      title: '标签设置',
      body: _enabledCount == 0
          ? Center(child: const FloraEmpty(name: FloraIcons.emptyTags))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '已启用 $_enabledCount 个标签',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '修改后，新记录的标签选择会使用新名称。已有日记不受影响。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // ── 领域标签 ──
          _buildSectionHeader(theme, '领域标签'),
          ..._settings.domainSettings.map(
            (d) => _buildSettingTile(
              theme: theme,
              name: d.displayName,
              defaultName: d.defaultName,
              enabled: d.enabled,
              onEdit: () => _editDomainName(d),
              onToggle: (v) {
                setState(() => d.enabled = v);
                _save();
              },
              onRestore: () => _restoreDomain(d),
            ),
          ),

          const SizedBox(height: 16),

          // ── 主题标签 ──
          _buildSectionHeader(theme, '主题标签'),
          ..._settings.domainSettings.expand((d) {
            if (d.topics.isEmpty) return <Widget>[];
            return [
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8, bottom: 4),
                child: Text(
                  d.displayName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...d.topics.map(
                (t) => _buildSettingTile(
                  theme: theme,
                  name: t.displayName,
                  defaultName: t.defaultName,
                  enabled: t.enabled,
                  onEdit: () => _editTopicName(t),
                  onToggle: (v) {
                    setState(() => t.enabled = v);
                    _save();
                  },
                  onRestore: () => _restoreTopic(t),
                ),
              ),
            ];
          }),

          const SizedBox(height: 16),

          // ── 方法标签 ──
          _buildSectionHeader(theme, '方法标签'),
          ..._settings.methodSettings.map(
            (m) => _buildSettingTile(
              theme: theme,
              name: m.displayName,
              defaultName: m.defaultName,
              enabled: m.enabled,
              onEdit: () => _editMethodName(m),
              onToggle: (v) {
                setState(() => m.enabled = v);
                _save();
              },
              onRestore: () => _restoreMethod(m),
            ),
          ),

          const SizedBox(height: 24),

          // ── 恢复全部默认 ──
          Center(
            child: TextButton.icon(
              onPressed: _restoreAll,
              icon: const FloraIcon(FloraIcons.restore, size: 18),
              label: const Text('恢复全部默认'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required ThemeData theme,
    required String name,
    required String defaultName,
    required bool enabled,
    required VoidCallback onEdit,
    required ValueChanged<bool> onToggle,
    required VoidCallback onRestore,
  }) {
    final isDefault = name == defaultName;
    final textColor = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant.withAlpha(120);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            // 标签名（可点击编辑）
            Expanded(
              child: GestureDetector(
                onTap: onEdit,
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // 编辑按钮
            IconButton(
              icon: const FloraIcon(FloraIcons.edit, size: 16),
              onPressed: onEdit,
              tooltip: '编辑名称',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // 恢复默认（仅在非默认时显示）
            if (!isDefault)
              IconButton(
                icon: const FloraIcon(FloraIcons.restore, size: 16),
                onPressed: onRestore,
                tooltip: '恢复默认',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            // 启用 / 禁用 Switch
            Switch(
              value: enabled,
              onChanged: onToggle,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
