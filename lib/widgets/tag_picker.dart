import 'package:flutter/material.dart';

import '../models/tag_config.dart';

class TagPicker extends StatefulWidget {
  final TagConfig tagConfig;
  final List<String> initialTags;

  /// 旧记录中已有、但现已被隐藏的标签。
  /// 显示为灰色"已隐藏"，由用户决定是否保留。
  final List<String> hiddenInitialTags;

  final ValueChanged<List<String>> onChanged;

  const TagPicker({
    super.key,
    required this.tagConfig,
    this.initialTags = const [],
    this.hiddenInitialTags = const [],
    required this.onChanged,
  });

  @override
  State<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPicker> {
  TagDomain? _selectedDomain;
  TagTopic? _selectedTopic;
  TagMethod? _selectedMethod;
  bool _expanded = false;

  /// 用户尚未取消的隐藏标签（保留在输出中）。
  late Set<String> _retainedHiddenTags;

  @override
  void initState() {
    super.initState();
    _retainedHiddenTags = Set.from(widget.hiddenInitialTags);
    _restoreInitialTags();
  }

  @override
  void didUpdateWidget(covariant TagPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTags != widget.initialTags ||
        oldWidget.hiddenInitialTags != widget.hiddenInitialTags) {
      _retainedHiddenTags = Set.from(widget.hiddenInitialTags);
      _restoreInitialTags();
    }
  }

  void _restoreInitialTags() {
    final tags = widget.initialTags;
    if (tags.isEmpty) {
      _selectedDomain = null;
      _selectedTopic = null;
      _selectedMethod = null;
      _expanded = false;
      return;
    }

    final domainName = tags.first;
    final domain = widget.tagConfig.domains
        .where((d) => d.name == domainName)
        .firstOrNull;
    if (domain == null) return;

    _selectedDomain = domain;

    if (tags.length > 1) {
      final topicName = tags[1];
      final topic =
          domain.topics.where((t) => t.name == topicName).firstOrNull;
      _selectedTopic = topic;
    }

    if (tags.length > 2) {
      final methodName = tags[2];
      final method = widget.tagConfig.methods
          .where((m) => m.name == methodName)
          .firstOrNull;
      _selectedMethod = method;
    }
  }

  List<String> _buildTags() {
    final result = <String>[];
    if (_selectedDomain != null) result.add(_selectedDomain!.name);
    if (_selectedTopic != null) result.add(_selectedTopic!.name);
    if (_selectedMethod != null) result.add(_selectedMethod!.name);
    // 追加用户未取消的隐藏标签
    result.addAll(_retainedHiddenTags);
    return result;
  }

  void _emit() {
    widget.onChanged(_buildTags());
  }

  void _selectDomain(TagDomain domain) {
    if (_selectedDomain?.id == domain.id) return;
    setState(() {
      _selectedDomain = domain;
      _selectedTopic = null;
    });
    _emit();
  }

  void _selectTopic(TagTopic topic) {
    if (_selectedTopic?.id == topic.id) return;
    setState(() => _selectedTopic = topic);
    _emit();
  }

  void _toggleMethod(TagMethod method) {
    setState(() {
      if (_selectedMethod?.id == method.id) {
        _selectedMethod = null;
      } else {
        _selectedMethod = method;
      }
    });
    _emit();
  }

  void _removeHiddenTag(String tag) {
    setState(() => _retainedHiddenTags.remove(tag));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = _buildTags();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCollapsedBar(theme, tags),
        if (_expanded) ...[
          const SizedBox(height: 4),
          _buildDomainRow(theme),
          if (_selectedDomain != null) ...[
            const SizedBox(height: 4),
            _buildTopicRow(theme),
          ],
          const SizedBox(height: 4),
          _buildMethodRow(theme),
          // 隐藏标签行
          if (_retainedHiddenTags.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildHiddenTagRow(theme),
          ],
        ],
      ],
    );
  }

  Widget _buildCollapsedBar(ThemeData theme, List<String> tags) {
    final hidden = _retainedHiddenTags;
    return Row(
      children: [
        if (tags.isNotEmpty)
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.map((name) {
                final isHidden = hidden.contains(name);
                return Chip(
                  label: Text(
                    isHidden ? '$name (已隐藏)' : name,
                    style: const TextStyle(fontSize: 12),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isHidden
                      ? Colors.grey.shade200
                      : theme.colorScheme.primary.withAlpha(25),
                  side: BorderSide.none,
                );
              }).toList(growable: false),
            ),
          )
        else
          const Spacer(),
        TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(
            _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 16,
          ),
          label: Text(
            _expanded ? '收起' : '🏷️ 标签',
            style: const TextStyle(fontSize: 12),
          ),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: theme.colorScheme.onSurface.withAlpha(150),
          ),
        ),
      ],
    );
  }

  Widget _buildDomainRow(ThemeData theme) {
    final domains = widget.tagConfig.domains;

    return _buildChipRow(
      theme: theme,
      label: '领域',
      items: domains.map((d) => _ChipItem(id: d.id, name: d.name)).toList(),
      selectedId: _selectedDomain?.id,
      onSelected: (id) {
        final domain = domains.firstWhere((d) => d.id == id);
        _selectDomain(domain);
      },
    );
  }

  Widget _buildTopicRow(ThemeData theme) {
    final domain = _selectedDomain!;
    final topics = domain.topics;

    return _buildChipRow(
      theme: theme,
      label: '主题',
      items: topics.map((t) => _ChipItem(id: t.id, name: t.name)).toList(),
      selectedId: _selectedTopic?.id,
      onSelected: (id) {
        final topic = topics.firstWhere((t) => t.id == id);
        _selectTopic(topic);
      },
    );
  }

  Widget _buildMethodRow(ThemeData theme) {
    final methods = widget.tagConfig.methods;

    return _buildChipRow(
      theme: theme,
      label: '方法',
      hint: '可选',
      items: methods.map((m) => _ChipItem(id: m.id, name: m.name)).toList(),
      selectedId: _selectedMethod?.id,
      onSelected: (id) {
        final method = methods.firstWhere((m) => m.id == id);
        _toggleMethod(method);
      },
    );
  }

  Widget _buildHiddenTagRow(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 36),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _retainedHiddenTags.map((tag) {
              return Chip(
                label: Text(
                  '$tag (已隐藏)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                onDeleted: () => _removeHiddenTag(tag),
                deleteIcon: Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.grey.shade200,
                side: BorderSide.none,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildChipRow({
    required ThemeData theme,
    required String label,
    String? hint,
    required List<_ChipItem> items,
    required String? selectedId,
    required ValueChanged<String> onSelected,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (hint != null && selectedId == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: DefaultTextStyle(
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                      fontStyle: FontStyle.italic,
                    ),
                    child: Text(hint),
                  ),
                ),
              ...items.map((item) {
                final selected = selectedId == item.id;
                return ChoiceChip(
                  label: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => onSelected(item.id),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  side: const BorderSide(color: Colors.transparent),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChipItem {
  final String id;
  final String name;
  const _ChipItem({required this.id, required this.name});
}
