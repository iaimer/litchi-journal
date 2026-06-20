import 'package:flutter/material.dart';

import 'flora_icon.dart';

import '../models/diary_document.dart';
import '../models/habit_settings.dart';
import '../models/habit_visual_config.dart';
import '../theme/app_theme.dart';
import 'habit_icon.dart';
import 'section_card.dart';

class HabitCard extends StatefulWidget {
  final HabitSection section;
  final Future<bool> Function(HabitStatus) onUpdate;
  final bool readOnly;

  /// 活跃习惯 key 集合（null 表示不过滤，显示全部）
  final Set<String>? activeHabitKeys;

  /// 习惯设置（用于自定义显示名称和图标）
  final HabitSettings? habitSettings;

  /// 自定义 checkbox 习惯状态变化回调。
  /// key → checked。
  final Future<bool> Function(Map<String, bool> states)?
      onCustomCheckboxToggle;

  const HabitCard({
    super.key,
    required this.section,
    required this.onUpdate,
    this.readOnly = false,
    this.activeHabitKeys,
    this.habitSettings,
    this.onCustomCheckboxToggle,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  String? _updatingField;
  late Map<String, bool> _customCheckboxStates;

  HabitSettings get _settings => widget.habitSettings ?? HabitSettings.defaults;

  @override
  void initState() {
    super.initState();
    _customCheckboxStates = {};
    // 从已解析的 Markdown 中读取自定义习惯的 checked 状态
    for (final item in widget.section.habits) {
      if (item.habitKey != null) continue;
      final label = item.label;
      for (final entry in _settings.extraHabits.entries) {
        if (label.contains(entry.value)) {
          _customCheckboxStates[entry.key] = item.checked;
          break;
        }
      }
    }
  }

  Future<void> _update(HabitStatus next, String field) async {
    setState(() => _updatingField = field);
    try {
      final ok = await widget.onUpdate(next);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新失败')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('更新失败')));
    } finally {
      if (mounted) setState(() => _updatingField = null);
    }
  }

  void _handleCheckboxTap(HabitStatus next, String field) {
    _update(next, field);
  }

  void _handleWaterIncrement(HabitStatus next) {
    _update(next, 'water');
  }

  Future<void> _handleWaterCustom(HabitStatus currentStatus) async {
    final controller = TextEditingController();
    String? error;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('自定义饮水量'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '输入毫升数',
                border: const OutlineInputBorder(),
                errorText: error,
              ),
              onChanged: (_) => setDialogState(() => error = null),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    setDialogState(() => error = '请输入毫升数');
                    return;
                  }
                  final value = int.tryParse(text);
                  if (value == null || value <= 0) {
                    setDialogState(() => error = '请输入有效的正整数');
                    return;
                  }
                  Navigator.pop(ctx, value);
                },
                child: const Text('确认'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result > 0) {
      final next = currentStatus.copyWith(water: currentStatus.water + result);
      _update(next, 'water');
    }
  }

  Future<void> _handleStepsEdit() async {
    final currentStatus = HabitStatus.fromHabitSection(widget.section);
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入今日步数'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入步数',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, value);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result >= 0 && result != currentStatus.steps) {
      final freshStatus = HabitStatus.fromHabitSection(widget.section);
      final next = freshStatus.copyWith(steps: result);
      _update(next, 'steps');
    }
  }

  /// 获取自定义显示名称（优先 settings，否则用原始 label）
  String _displayName(HabitItem item) {
    final key = item.habitKey;
    if (key != null) {
      return _settings.displayNameFor(key);
    }
    return item.label;
  }

  /// 获取习惯图标（自定义优先，否则使用默认图标）。
  String? _icon(HabitItem item) {
    final key = item.habitKey;
    if (key != null) {
      return _settings.iconFor(key);
    }
    return null;
  }

  /// 获取自定义颜色
  Color? _color(HabitItem item) {
    final key = item.habitKey;
    if (key != null) {
      final defaultColor = HabitVisualConfig.of(key).color;
      final customArgb = _settings.colorFor(key);
      if (customArgb != defaultColor.toARGB32()) {
        return Color(customArgb);
      }
    }
    return null;
  }

  String? _checkboxField(HabitItem item) => item.habitKey;

  HabitStatus? _toggleCheckbox(HabitItem item, HabitStatus status) {
    switch (item.habitKey) {
      case 'reading':
        return status.copyWith(reading: !status.reading);
      case 'language':
        return status.copyWith(language: !status.language);
      case 'supplements':
        return status.copyWith(supplements: !status.supplements);
      default:
        return null;
    }
  }

  /// 获取自定义颜色（用于 SectionCard 强调色）
  Color get _accentColor {
    // 取第一个习惯的自定义颜色，没有则用默认
    for (final h in widget.section.habits) {
      final c = _color(h);
      if (c != null) return c;
    }
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final status = HabitStatus.fromHabitSection(widget.section);

    // 按活跃状态过滤 Markdown 习惯
    final activeHabits = widget.section.habits.where((h) {
      if (widget.activeHabitKeys == null) return true;
      final key = h.habitKey;
      // 自定义习惯行（habitKey == null）由 _CustomCheckboxRow 渲染
      if (key == null) return false;
      return widget.activeHabitKeys!.contains(key);
    }).toList();

    final children = <Widget>[
      ...activeHabits.map((habit) => _buildRow(habit, status)),
    ];

    // 追加启用的自定义 checkbox 习惯（来自 extraHabits，不在 Markdown 中）
    final settings = widget.habitSettings;
    if (settings != null) {
      for (final entry in settings.extraHabits.entries) {
        final key = entry.key;
        if (!settings.isActive(key)) continue;
        children.add(_CustomCheckboxRow(
          key: ValueKey('custom_habit_$key'),
          habitKey: key,
          settings: settings,
          checked: _customCheckboxStates[key] ?? false,
          onToggle: _handleCustomCheckboxToggle,
        ));
      }
    }

    if (children.isEmpty && widget.section.habits.isEmpty) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: widget.section.title,
      accentColor: _accentColor,
      children: children,
    );
  }

  Widget _buildRow(HabitItem habit, HabitStatus status) {
    if (widget.readOnly) {
      return _buildReadOnlyRow(habit, status);
    }
    switch (habit.kind) {
      case HabitKind.checkbox:
        return _CheckboxRow(
          habit: habit,
          status: status,
          loading: _updatingField != null,
          displayName: _displayName(habit),
          icon: _icon(habit),
          onTap: () {
            final next = _toggleCheckbox(habit, status);
            final field = _checkboxField(habit);
            if (next != null && field != null) {
              _handleCheckboxTap(next, field);
            }
          },
        );
      case HabitKind.counter:
        if (_isWaterHabit(habit)) {
          return _WaterCounterRow(
            habit: habit,
            status: status,
            loading: _updatingField != null,
            displayName: _displayName(habit),
            icon: _icon(habit),
            onIncrement: (next) => _handleWaterIncrement(next),
            onCustom: () => _handleWaterCustom(status),
          );
        }
        return _StepsCounterRow(
          habit: habit,
          status: status,
          loading: _updatingField != null,
          displayName: _displayName(habit),
          icon: _icon(habit),
          onEdit: _handleStepsEdit,
        );
    }
  }

  Future<void> _handleCustomCheckboxToggle(
    String key,
    bool newChecked,
  ) async {
    setState(() => _customCheckboxStates[key] = newChecked);
    if (widget.onCustomCheckboxToggle == null) return;
    try {
      final ok = await widget.onCustomCheckboxToggle!(
        Map.from(_customCheckboxStates),
      );
      if (!mounted) return;
      if (!ok) setState(() => _customCheckboxStates[key] = !newChecked);
    } catch (_) {
      if (!mounted) return;
      setState(() => _customCheckboxStates[key] = !newChecked);
    }
  }

  Widget _buildReadOnlyRow(HabitItem habit, HabitStatus status) {
    switch (habit.kind) {
      case HabitKind.checkbox:
        return _CheckboxRow(
          habit: habit,
          status: status,
          loading: false,
          displayName: _displayName(habit),
          icon: _icon(habit),
          onTap: () {},
        );
      case HabitKind.counter:
        if (_isWaterHabit(habit)) {
          return _WaterCounterRow(
            habit: habit,
            status: status,
            loading: false,
            displayName: _displayName(habit),
            icon: _icon(habit),
            onIncrement: (_) {},
          );
        }
        return _StepsCounterRow(
          habit: habit,
          status: status,
          loading: false,
          displayName: _displayName(habit),
          icon: _icon(habit),
          onEdit: () {},
        );
    }
  }

  bool _isWaterHabit(HabitItem item) => item.habitKey == 'water';
}

class _CheckboxRow extends StatelessWidget {
  final HabitItem habit;
  final HabitStatus status;
  final bool loading;
  final String displayName;
  final String? icon;
  final VoidCallback onTap;

  const _CheckboxRow({
    required this.habit,
    required this.status,
    required this.loading,
    required this.displayName,
    this.icon,
    required this.onTap,
  });

  bool get _checked {
    switch (habit.habitKey) {
      case 'reading':
        return status.reading;
      case 'language':
        return status.language;
      case 'supplements':
        return status.supplements;
      default:
        return habit.checked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: _checked ? AppColors.success : theme.disabledColor,
            ),
            const SizedBox(width: 8),
            if (icon != null) ...[
              HabitIcon(icon!, size: 16, color: theme.colorScheme.onSurface),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                displayName,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ),
            if (loading) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WaterCounterRow extends StatelessWidget {
  final HabitItem habit;
  final HabitStatus status;
  final bool loading;
  final String displayName;
  final String? icon;
  final void Function(HabitStatus next) onIncrement;
  final VoidCallback? onCustom;

  const _WaterCounterRow({
    required this.habit,
    required this.status,
    required this.loading,
    required this.displayName,
    this.icon,
    required this.onIncrement,
    this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                HabitIcon(icon!, size: 16, color: theme.colorScheme.onSurface),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  '$displayName ${status.water} ${habit.unit ?? ""}',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _QuickButton(
                label: '+250',
                onTap: loading ? null : () => onIncrement(_add(250)),
              ),
              _QuickButton(
                label: '+475',
                onTap: loading ? null : () => onIncrement(_add(475)),
              ),
              _QuickButton(
                label: '+500',
                onTap: loading ? null : () => onIncrement(_add(500)),
              ),
              if (onCustom != null)
                _QuickButton(
                  label: '自定义',
                  onTap: loading ? null : onCustom,
                ),
              _QuickButton(
                label: '清零',
                onTap: loading
                    ? null
                    : () => onIncrement(status.copyWith(water: 0)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  HabitStatus _add(int amount) {
    return status.copyWith(water: status.water + amount);
  }
}

class _StepsCounterRow extends StatelessWidget {
  final HabitItem habit;
  final HabitStatus status;
  final bool loading;
  final String displayName;
  final String? icon;
  final VoidCallback onEdit;

  const _StepsCounterRow({
    required this.habit,
    required this.status,
    required this.loading,
    required this.displayName,
    this.icon,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: loading ? null : onEdit,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              HabitIcon(icon!, size: 16, color: theme.colorScheme.onSurface),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                '$displayName ${status.steps} ${habit.unit ?? ""}',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ),
            Text(
              '编辑',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 2),
            const FloraIcon(
              FloraIcons.edit,
              size: 14,
              color: AppColors.primary,
            ),
            if (loading) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomCheckboxRow extends StatefulWidget {
  final String habitKey;
  final HabitSettings settings;
  final bool checked;
  final Future<void> Function(String key, bool checked) onToggle;

  const _CustomCheckboxRow({
    super.key,
    required this.habitKey,
    required this.settings,
    required this.checked,
    required this.onToggle,
  });

  @override
  State<_CustomCheckboxRow> createState() => _CustomCheckboxRowState();
}

class _CustomCheckboxRowState extends State<_CustomCheckboxRow> {
  late bool _checked;

  @override
  void initState() {
    super.initState();
    _checked = widget.checked;
  }

  @override
  void didUpdateWidget(covariant _CustomCheckboxRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked != oldWidget.checked) {
      _checked = widget.checked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = widget.settings.displayNameFor(widget.habitKey);
    final icon = widget.settings.iconFor(widget.habitKey);

    return InkWell(
      onTap: () {
        final next = !_checked;
        setState(() => _checked = next);
        widget.onToggle(widget.habitKey, next);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: _checked ? AppColors.success : theme.disabledColor,
            ),
            const SizedBox(width: 8),
            if (icon.isNotEmpty) ...[
              HabitIcon(icon, size: 16, color: theme.colorScheme.onSurface),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                displayName,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QuickButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: AppColors.primary, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.primary),
        ),
      ),
    );
  }
}
