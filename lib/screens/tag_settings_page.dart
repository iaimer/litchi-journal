import 'package:flutter/material.dart';

import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../services/tag_settings_helper.dart';
import '../services/tag_settings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/flora_icon.dart';
import '../widgets/flora_page_scaffold.dart';

/// 标签管理页面。
///
/// 顶部 Tab：领域 / 方法。领域下的主题保持层级展示，标签名称负责打开
/// 底部操作菜单，箭头只负责展开和收起。
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

enum _TagEntryAction { toggle, edit, restore, delete }

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
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (mounted) setState(() {});
  }

  List<DomainSetting> get _visibleDomains =>
      _settings.domainSettings.where((domain) => !domain.deleted).toList();

  List<MethodSetting> get _visibleMethods =>
      _settings.methodSettings.where((method) => !method.deleted).toList();

  int get _domainCount => _visibleDomains.length;

  int get _topicCount => _visibleDomains.fold(
    0,
    (count, domain) =>
        count + domain.topics.where((topic) => !topic.deleted).length,
  );

  int get _methodCount => _visibleMethods.length;

  Future<void> _save() async {
    try {
      await _repo.saveTagSettings(_settings);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标签设置保存失败，请重试')));
    }
  }

  String _newKey(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}';

  Iterable<String> _existingNames({String? exceptKey}) sync* {
    for (final domain in _settings.domainSettings) {
      if (!domain.deleted && domain.key != exceptKey) {
        yield domain.displayName;
      }
      for (final topic in domain.topics) {
        if (!topic.deleted && topic.key != exceptKey) {
          yield topic.displayName;
        }
      }
    }
    for (final method in _settings.methodSettings) {
      if (!method.deleted && method.key != exceptKey) {
        yield method.displayName;
      }
    }
  }

  // ── 底部编辑面板 ──

  Future<String?> _showEditSheet({
    required String title,
    required String initialName,
    required String? editingKey,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FloraRadius.lg),
        ),
      ),
      builder: (_) => _TagNameSheet(
        title: title,
        initialName: initialName,
        validate: (name) {
          return TagSettingsHelper.validateDisplayName(name) ??
              TagSettingsHelper.validateUniqueDisplayName(
                name,
                _existingNames(exceptKey: editingKey),
              );
        },
      ),
    );
  }

  Future<void> _editDomain(DomainSetting domain) async {
    final name = await _showEditSheet(
      title: '编辑领域',
      initialName: domain.displayName,
      editingKey: domain.key,
    );
    if (!mounted || name == null) return;
    setState(() => domain.displayName = name);
    await _save();
  }

  Future<void> _editTopic(TopicSetting topic) async {
    final name = await _showEditSheet(
      title: '编辑主题',
      initialName: topic.displayName,
      editingKey: topic.key,
    );
    if (!mounted || name == null) return;
    setState(() => topic.displayName = name);
    await _save();
  }

  Future<void> _editMethod(MethodSetting method) async {
    final name = await _showEditSheet(
      title: '编辑方法',
      initialName: method.displayName,
      editingKey: method.key,
    );
    if (!mounted || name == null) return;
    setState(() => method.displayName = name);
    await _save();
  }

  // ── 新增 ──

  Future<void> _addDomain() async {
    final name = await _showEditSheet(
      title: '新增领域',
      initialName: '',
      editingKey: null,
    );
    if (!mounted || name == null) return;
    final key = _newKey('domain');
    setState(() {
      _settings.domainSettings.add(
        DomainSetting(
          key: key,
          defaultName: name,
          displayName: name,
          topics: [],
        ),
      );
      _expandedDomains.add(key);
    });
    await _save();
  }

  Future<void> _addTopic(DomainSetting domain) async {
    final name = await _showEditSheet(
      title: '新增主题',
      initialName: '',
      editingKey: null,
    );
    if (!mounted || name == null) return;
    setState(() {
      domain.topics.add(
        TopicSetting(
          key: _newKey('topic'),
          defaultName: name,
          displayName: name,
        ),
      );
    });
    await _save();
  }

  Future<void> _addMethod() async {
    final name = await _showEditSheet(
      title: '新增方法',
      initialName: '',
      editingKey: null,
    );
    if (!mounted || name == null) return;
    setState(() {
      _settings.methodSettings.add(
        MethodSetting(
          key: _newKey('method'),
          defaultName: name,
          displayName: name,
        ),
      );
    });
    await _save();
  }

  // ── 标签操作菜单 ──

  Future<_TagEntryAction?> _showActionsSheet({
    required String name,
    required bool enabled,
    required bool canRestore,
  }) {
    final theme = Theme.of(context);
    final actions =
        <({String label, _TagEntryAction action, bool destructive})>[
          (
            label: enabled ? '停用' : '启用',
            action: _TagEntryAction.toggle,
            destructive: false,
          ),
          (label: '编辑', action: _TagEntryAction.edit, destructive: false),
          if (canRestore)
            (
              label: '恢复默认',
              action: _TagEntryAction.restore,
              destructive: false,
            ),
          (label: '永久删除', action: _TagEntryAction.delete, destructive: true),
        ];

    return showModalBottomSheet<_TagEntryAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FloraRadius.lg),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FloraSpacing.lg,
              FloraSpacing.xs,
              FloraSpacing.lg,
              FloraSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: FloraSpacing.sm),
                  child: Text(
                    '#$name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      80,
                    ),
                    borderRadius: BorderRadius.circular(FloraRadius.md),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < actions.length; index++) ...[
                        if (index > 0)
                          Divider(
                            height: 1,
                            color: theme.dividerColor.withAlpha(120),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: TextButton(
                            onPressed: () => Navigator.of(
                              sheetContext,
                            ).pop(actions[index].action),
                            style: TextButton.styleFrom(
                              foregroundColor: actions[index].destructive
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface,
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: Text(actions[index].label),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: FloraSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(80),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FloraRadius.md),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete({
    required String name,
    required bool isDomain,
    required int topicCount,
  }) async {
    final theme = Theme.of(context);
    final detail = isDomain && topicCount > 0
        ? '它下面的 $topicCount 个主题也会从本机标签中移除。'
        : '已有日记中的标签不会被修改。';
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FloraRadius.lg),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FloraSpacing.lg,
            FloraSpacing.xs,
            FloraSpacing.lg,
            FloraSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('永久删除「#$name」？', style: theme.textTheme.titleLarge),
              const SizedBox(height: FloraSpacing.sm),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: FloraSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  child: const Text('永久删除'),
                ),
              ),
              const SizedBox(height: FloraSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text('取消'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  Future<void> _handleDomainAction(DomainSetting domain) async {
    final action = await _showActionsSheet(
      name: domain.displayName,
      enabled: domain.enabled,
      canRestore: domain.displayName != domain.defaultName,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _TagEntryAction.toggle:
        setState(() => domain.enabled = !domain.enabled);
        await _save();
      case _TagEntryAction.edit:
        await _editDomain(domain);
      case _TagEntryAction.restore:
        setState(() {
          domain.displayName = domain.defaultName;
          domain.enabled = true;
        });
        await _save();
      case _TagEntryAction.delete:
        final confirmed = await _confirmDelete(
          name: domain.displayName,
          isDomain: true,
          topicCount: domain.topics.where((topic) => !topic.deleted).length,
        );
        if (!mounted || !confirmed) return;
        setState(() {
          domain.deleted = true;
          domain.enabled = false;
          for (final topic in domain.topics) {
            topic.deleted = true;
            topic.enabled = false;
          }
          _expandedDomains.remove(domain.key);
        });
        await _save();
    }
  }

  Future<void> _handleTopicAction(TopicSetting topic) async {
    final action = await _showActionsSheet(
      name: topic.displayName,
      enabled: topic.enabled,
      canRestore: topic.displayName != topic.defaultName,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _TagEntryAction.toggle:
        setState(() => topic.enabled = !topic.enabled);
        await _save();
      case _TagEntryAction.edit:
        await _editTopic(topic);
      case _TagEntryAction.restore:
        setState(() {
          topic.displayName = topic.defaultName;
          topic.enabled = true;
        });
        await _save();
      case _TagEntryAction.delete:
        final confirmed = await _confirmDelete(
          name: topic.displayName,
          isDomain: false,
          topicCount: 0,
        );
        if (!mounted || !confirmed) return;
        setState(() {
          topic.deleted = true;
          topic.enabled = false;
        });
        await _save();
    }
  }

  Future<void> _handleMethodAction(MethodSetting method) async {
    final action = await _showActionsSheet(
      name: method.displayName,
      enabled: method.enabled,
      canRestore: method.displayName != method.defaultName,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _TagEntryAction.toggle:
        setState(() => method.enabled = !method.enabled);
        await _save();
      case _TagEntryAction.edit:
        await _editMethod(method);
      case _TagEntryAction.restore:
        setState(() {
          method.displayName = method.defaultName;
          method.enabled = true;
        });
        await _save();
      case _TagEntryAction.delete:
        final confirmed = await _confirmDelete(
          name: method.displayName,
          isDomain: false,
          topicCount: 0,
        );
        if (!mounted || !confirmed) return;
        setState(() {
          method.deleted = true;
          method.enabled = false;
        });
        await _save();
    }
  }

  Future<void> _restoreAll() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FloraRadius.lg),
        ),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FloraSpacing.lg,
              FloraSpacing.xs,
              FloraSpacing.lg,
              FloraSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('恢复全部默认？', style: theme.textTheme.titleLarge),
                const SizedBox(height: FloraSpacing.sm),
                Text(
                  '内置标签将恢复默认名称并启用，本机新增标签将被移除。已有日记不受影响。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: FloraSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('恢复默认'),
                  ),
                ),
                const SizedBox(height: FloraSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: const Text('取消'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _settings = TagSettings.fromTagConfig(widget.tagConfig);
      _expandedDomains.clear();
    });
    await _save();
  }

  // ── 分段控件 ──

  Widget _buildTabBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FloraSpacing.lg,
        FloraSpacing.md,
        FloraSpacing.lg,
        FloraSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(FloraRadius.md),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: List.generate(2, (index) {
            final selected = _tabController.index == index;
            final label = index == 0 ? '领域' : '方法';
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: label,
                child: GestureDetector(
                  onTap: () => _tabController.animateTo(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(FloraRadius.sm),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style:
                          (selected
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
      body: Column(
        children: [
          _buildTabBar(theme),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildDomainsTab(theme), _buildMethodsTab(theme)],
            ),
          ),
        ],
      ),
    );
  }

  // ── 领域 Tab ──

  Widget _buildDomainsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: FloraSpacing.lg),
      children: [
        const SizedBox(height: FloraSpacing.xs),
        _buildSummary(theme),
        const SizedBox(height: FloraSpacing.md),
        _buildAddButton(theme: theme, label: '＋ 添加领域', onTap: _addDomain),
        const SizedBox(height: FloraSpacing.md),
        ..._visibleDomains.map((domain) => _buildDomainCard(theme, domain)),
        const SizedBox(height: FloraSpacing.md),
        _buildRestoreButton(theme),
        const SizedBox(height: FloraSpacing.xxl),
      ],
    );
  }

  Widget _buildSummary(ThemeData theme) {
    return Text(
      '共 $_domainCount 个领域 / $_topicCount 个主题 / $_methodCount 个方法',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildDomainCard(ThemeData theme, DomainSetting domain) {
    final expanded = _expandedDomains.contains(domain.key);
    final topics = domain.topics.where((topic) => !topic.deleted).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: FloraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FloraSpacing.sm,
              FloraSpacing.xs,
              FloraSpacing.md,
              FloraSpacing.xs,
            ),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: expanded
                      ? '收起 ${domain.displayName}'
                      : '展开 ${domain.displayName}',
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        if (expanded) {
                          _expandedDomains.remove(domain.key);
                        } else {
                          _expandedDomains.add(domain.key);
                        }
                      });
                    },
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: expanded ? '收起' : '展开',
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _handleDomainAction(domain),
                    borderRadius: BorderRadius.circular(FloraRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: FloraSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '#${domain.displayName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: domain.enabled
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (!domain.enabled)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: FloraSpacing.sm,
                              ),
                              child: Text(
                                '已停用',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            Divider(
              height: 1,
              indent: FloraSpacing.lg,
              endIndent: FloraSpacing.lg,
              color: theme.dividerColor,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FloraSpacing.lg,
                FloraSpacing.sm,
                FloraSpacing.md,
                FloraSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (topics.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FloraSpacing.sm),
                      child: Text(
                        '暂无主题标签',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ...topics.map((topic) => _buildTopicRow(theme, topic)),
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

  Widget _buildTopicRow(ThemeData theme, TopicSetting topic) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FloraSpacing.xs),
      child: InkWell(
        onTap: () => _handleTopicAction(topic),
        borderRadius: BorderRadius.circular(FloraRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FloraSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(right: FloraSpacing.sm),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
                ),
              ),
              Expanded(
                child: Text(
                  topic.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: topic.enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (!topic.enabled)
                Text(
                  '已停用',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 方法 Tab ──

  Widget _buildMethodsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: FloraSpacing.lg),
      children: [
        const SizedBox(height: FloraSpacing.xs),
        _buildSummary(theme),
        const SizedBox(height: FloraSpacing.md),
        _buildAddButton(theme: theme, label: '＋ 添加方法', onTap: _addMethod),
        const SizedBox(height: FloraSpacing.md),
        if (_visibleMethods.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: FloraSpacing.xl),
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
          ..._visibleMethods.map((method) => _buildMethodCard(theme, method)),
        const SizedBox(height: FloraSpacing.md),
        _buildRestoreButton(theme),
        const SizedBox(height: FloraSpacing.xxl),
      ],
    );
  }

  Widget _buildMethodCard(ThemeData theme, MethodSetting method) {
    return Card(
      margin: const EdgeInsets.only(bottom: FloraSpacing.sm),
      child: InkWell(
        onTap: () => _handleMethodAction(method),
        borderRadius: BorderRadius.circular(FloraRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FloraSpacing.md,
            vertical: FloraSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '#${method.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: method.enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (!method.enabled)
                Text(
                  '已停用',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton(ThemeData theme) {
    return Center(
      child: TextButton.icon(
        onPressed: _restoreAll,
        icon: const FloraIcon(FloraIcons.restore, size: 18),
        label: const Text('恢复全部默认'),
        style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
      ),
    );
  }

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
              ? const EdgeInsets.symmetric(vertical: FloraSpacing.xs)
              : const EdgeInsets.symmetric(vertical: FloraSpacing.sm),
          foregroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FloraRadius.md),
            side: BorderSide(
              color: theme.colorScheme.primary.withAlpha(60),
              width: 1,
            ),
          ),
          backgroundColor: theme.colorScheme.primary.withAlpha(10),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TagNameSheet extends StatefulWidget {
  final String title;
  final String initialName;
  final String? Function(String name) validate;

  const _TagNameSheet({
    required this.title,
    required this.initialName,
    required this.validate,
  });

  @override
  State<_TagNameSheet> createState() => _TagNameSheetState();
}

class _TagNameSheetState extends State<_TagNameSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    final error = widget.validate(name);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FloraSpacing.lg,
        FloraSpacing.xs,
        FloraSpacing.lg,
        FloraSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: FloraSpacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 24,
            decoration: InputDecoration(
              labelText: '标签名称',
              errorText: _error,
              counterText: '',
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: FloraSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(onPressed: _submit, child: const Text('确定')),
          ),
        ],
      ),
    );
  }
}
