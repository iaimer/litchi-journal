import 'package:flutter/material.dart';

import '../widgets/flora_icon.dart';
import '../widgets/flora_page_scaffold.dart';

import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../services/tag_settings_helper.dart';
import '../services/tag_settings_repository.dart';
import '../widgets/flora_empty.dart';

/// 标签管理页面。
///
/// 顶部 Tab：领域 / 方法。
/// 领域 Tab 中按 Web 端风格：领域为一级卡片，主题为二级列表。
/// 每个区域提供添加入口。
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

class _TagSettingsPageState extends State<TagSettingsPage>
    with SingleTickerProviderStateMixin {
  late TagSettings _settings;
  late final TagSettingsRepository _repo;
  late final TabController _tabController;

  /// 处于展开状态的领域 key 集合。
  final Set<String> _expandedDomains = {};

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _repo = TagSettingsRepository();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _domainCount => _settings.domainSettings.length;
  int get _topicCount =>
      _settings.domainSettings.fold(0, (s, d) => s + d.topics.length);
  int get _methodCount => _settings.methodSettings.length;

  Future<void> _save() async {
    await _repo.saveTagSettings(_settings);
  }

  // ── Key 生成 ──

  String _newKey(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}';

  // ── 编辑弹窗 ──

  void _editDialog({
    required String title,
    required String initialName,
    String? initialDescription,
    required void Function(String name, String? description) onSave,
  }) {
    final nameController = TextEditingController(text: initialName);
    final descController =
        TextEditingController(text: initialDescription ?? '');
    String? error;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '标签名称',
                      errorText: error,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() => error = null),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '可选说明',
                      hintText: '这个标签的用途说明',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final err = TagSettingsHelper.validateDisplayName(name);
                    if (err != null) {
                      setDialogState(() => error = err);
                      return;
                    }
                    final desc = descController.text.trim();
                    Navigator.pop(ctx);
                    onSave(name, desc.isNotEmpty ? desc : null);
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

  // ── 编辑领域/主题/方法 ──

  void _editDomain(DomainSetting d) {
    _editDialog(
      title: '编辑领域',
      initialName: d.displayName,
      initialDescription: d.description,
      onSave: (name, desc) {
        setState(() {
          d.displayName = name;
          d.description = desc;
        });
        _save();
      },
    );
  }

  void _editTopic(TopicSetting t) {
    _editDialog(
      title: '编辑主题',
      initialName: t.displayName,
      initialDescription: t.description,
      onSave: (name, desc) {
        setState(() {
          t.displayName = name;
          t.description = desc;
        });
        _save();
      },
    );
  }

  void _editMethod(MethodSetting m) {
    _editDialog(
      title: '编辑方法',
      initialName: m.displayName,
      initialDescription: m.description,
      onSave: (name, desc) {
        setState(() {
          m.displayName = name;
          m.description = desc;
        });
        _save();
      },
    );
  }

  // ── 恢复 ──

  void _restoreDomain(DomainSetting d) {
    setState(() {
      d.displayName = d.defaultName;
      d.enabled = true;
    });
    _save();
  }

  void _restoreTopic(TopicSetting t) {
    setState(() {
      t.displayName = t.defaultName;
      t.enabled = true;
    });
    _save();
  }

  void _restoreMethod(MethodSetting m) {
    setState(() {
      m.displayName = m.defaultName;
      m.enabled = true;
    });
    _save();
  }

  // ── 新增领域/主题/方法 ──

  void _addDomain() {
    _editDialog(
      title: '新增领域',
      initialName: '',
      initialDescription: '',
      onSave: (name, desc) {
        final key = _newKey('domain');
        setState(() {
          _settings.domainSettings.add(DomainSetting(
            key: key,
            defaultName: name,
            displayName: name,
            enabled: true,
            description: desc,
            topics: [],
          ));
        });
        _save();
      },
    );
  }

  void _addTopic(DomainSetting domain) {
    _editDialog(
      title: '新增主题',
      initialName: '',
      initialDescription: '',
      onSave: (name, desc) {
        final key = _newKey('topic');
        setState(() {
          domain.topics.add(TopicSetting(
            key: key,
            defaultName: name,
            displayName: name,
            enabled: true,
            description: desc,
          ));
        });
        _save();
      },
    );
  }

  void _addMethod() {
    _editDialog(
      title: '新增方法',
      initialName: '',
      initialDescription: '',
      onSave: (name, desc) {
        final key = _newKey('method');
        setState(() {
          _settings.methodSettings.add(MethodSetting(
            key: key,
            defaultName: name,
            displayName: name,
            enabled: true,
            description: desc,
          ));
        });
        _save();
      },
    );
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

  // ── 分段控件 ──

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: List.generate(2, (i) {
            final selected = _tabController.index == i;
            final labels = const ['领域', '方法'];
            return Expanded(
              child: GestureDetector(
                onTap: () => _tabController.animateTo(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: (selected
                            ? theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              )
                            : theme.textTheme.bodySmall)
                        ?.copyWith(
                      color: selected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FloraPageScaffold(
      title: '标签管理',
      body: _domainCount == 0 && _methodCount == 0
          ? Center(child: const FloraEmpty(name: FloraIcons.emptyTags))
          : Column(
              children: [
                _buildTabBar(theme),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDomainsTab(theme),
                      _buildMethodsTab(theme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── 领域 Tab ──

  Widget _buildDomainsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 4),
        // 统计摘要
        Text(
          '共 $_domainCount 个领域 / $_topicCount 个主题 / $_methodCount 个方法',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        // 添加领域
        _buildAddButton(
          theme: theme,
          label: '＋ 添加领域',
          onTap: _addDomain,
        ),
        const SizedBox(height: 12),
        // 领域列表
        ..._settings.domainSettings.map(
            (d) => _buildDomainCard(theme, d)),
        // 恢复默认
        const SizedBox(height: 20),
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
    );
  }

  /// 单个领域卡片：名称 + 说明 + 展开箭头 + 操作按钮。主题默认折叠。
  Widget _buildDomainCard(ThemeData theme, DomainSetting domain) {
    final expanded = _expandedDomains.contains(domain.key);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 可点击的头部区域
          InkWell(
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedDomains.remove(domain.key);
                } else {
                  _expandedDomains.add(domain.key);
                }
              });
            },
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(expanded ? 0 : 12),
              bottomRight: Radius.circular(expanded ? 0 : 12),
            ),
            child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 领域头部：名称 + 说明 + 操作按钮 ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                        expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                            '#${domain.displayName}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!domain.enabled)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                '已禁用',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (domain.description != null &&
                          domain.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            domain.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 编辑
                IconButton(
                  icon: const FloraIcon(FloraIcons.edit, size: 16),
                  onPressed: () => _editDomain(domain),
                  tooltip: '编辑',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                // 恢复默认
                if (domain.displayName != domain.defaultName)
                  IconButton(
                    icon: const FloraIcon(FloraIcons.restore, size: 16),
                    onPressed: () => _restoreDomain(domain),
                    tooltip: '恢复默认',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                // 启用/禁用
                Switch(
                  value: domain.enabled,
                  onChanged: (v) {
                    setState(() => domain.enabled = v);
                    _save();
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),

          ],
        ),
      ),
    ),
    // ── 展开后的主题区域 ──
    if (expanded) ...[
      Divider(height: 1, indent: 12, endIndent: 12, color: theme.dividerColor),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (domain.topics.isNotEmpty)
              ...domain.topics.map((t) => _buildTopicRow(theme, t))
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '暂无主题标签',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _buildAddButton(
              theme: theme,
              label: '＋ 添加主题',
              onTap: () => _addTopic(domain),
              compact: true,
            ),
          ],
        ),
      ),
    ],
    ],
  ),
);
  }

  /// 主题行：名称 + 说明 + 操作。
  Widget _buildTopicRow(ThemeData theme, TopicSetting topic) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 小圆点
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 7, right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
            ),
          ),
          // 名称 + 说明
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        topic.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: topic.enabled
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant
                                  .withAlpha(120),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (topic.description != null &&
                        topic.description!.isNotEmpty)
                      Flexible(
                        child: Text(
                          ' — ${topic.description}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // 编辑
          IconButton(
            icon: const FloraIcon(FloraIcons.edit, size: 14),
            onPressed: () => _editTopic(topic),
            tooltip: '编辑',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // 恢复
          if (topic.displayName != topic.defaultName)
            IconButton(
              icon: const FloraIcon(FloraIcons.restore, size: 14),
              onPressed: () => _restoreTopic(topic),
              tooltip: '恢复默认',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          // 启用/禁用
          Switch(
            value: topic.enabled,
            onChanged: (v) {
              setState(() => topic.enabled = v);
              _save();
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  // ── 方法 Tab ──

  Widget _buildMethodsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 4),
        Text(
          '共 $_domainCount 个领域 / $_topicCount 个主题 / $_methodCount 个方法',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        // 添加方法
        _buildAddButton(
          theme: theme,
          label: '＋ 添加方法',
          onTap: _addMethod,
        ),
        const SizedBox(height: 12),
        // 方法列表
        if (_settings.methodSettings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '暂无方法标签，点击上方按钮添加。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ..._settings.methodSettings
              .map((m) => _buildMethodCard(theme, m)),
        // 恢复默认
        const SizedBox(height: 20),
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
    );
  }

  Widget _buildMethodCard(ThemeData theme, MethodSetting method) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${method.displayName}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: method.enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant.withAlpha(120),
                    ),
                  ),
                  if (method.description != null &&
                      method.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        method.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const FloraIcon(FloraIcons.edit, size: 16),
              onPressed: () => _editMethod(method),
              tooltip: '编辑',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (method.displayName != method.defaultName)
              IconButton(
                icon: const FloraIcon(FloraIcons.restore, size: 16),
                onPressed: () => _restoreMethod(method),
                tooltip: '恢复默认',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            Switch(
              value: method.enabled,
              onChanged: (v) {
                setState(() => method.enabled = v);
                _save();
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  // ── 轻量添加按钮 ──

  Widget _buildAddButton({
    required ThemeData theme,
    required String label,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 0, vertical: 4)
              : const EdgeInsets.symmetric(vertical: 6),
          foregroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: theme.colorScheme.primary.withAlpha(60),
              width: 1,
            ),
          ),
          backgroundColor: theme.colorScheme.primary.withAlpha(10),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
