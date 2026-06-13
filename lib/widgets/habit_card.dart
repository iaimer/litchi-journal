import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../models/habit_settings.dart';
import '../models/habit_visual_config.dart';
import '../theme/app_theme.dart';
import 'section_card.dart';

class HabitCard extends StatefulWidget {
  final HabitSection section;
  final Future<bool> Function(HabitStatus) onUpdate;
  final bool readOnly;
  /// 活跃习惯 key 集合（null 表示不过滤，显示全部）
  final Set<String>? activeHabitKeys;
  /// 习惯设置（用于自定义显示名称和图标）
  final HabitSettings? habitSettings;

  const HabitCard({
    super.key,
    required this.section,
    required this.onUpdate,
    this.readOnly = false,
    this.activeHabitKeys,
    this.habitSettings,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  String? _updatingField;

  HabitSettings get _settings =>
      widget.habitSettings ?? HabitSettings.defaults;

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

  Future<void> _handleStepsEdit() async {
    final currentStatus = HabitStatus.fromHabitSection(widget.section);
    final controller = TextEditingController(
      text: currentStatus.steps.toString(),
    );
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

  /// 从 HabitItem 反推习惯 key（与 HabitStatus.fromHabitSection 一致）。
  /// 基于原始 Markdown 标签，不依赖用户自定义 displayName。
  static String? keyForHabit(HabitItem item) {
    final label = item.label;
    if (label.contains('饮')) return 'water';
    if (label.contains('运动')) return 'steps';
    if (label.contains('阅读')) return 'reading';
    if (label.contains('语言')) return 'language';
    if (label.contains('鱼油') || label.contains('植物甾醇')) return 'supplements';
    return null;
  }

  static String? _fieldForLabel(String label) {
    if (label.contains('阅读')) return 'reading';
    if (label.contains('语言')) return 'language';
    if (label.contains('鱼油') || label.contains('植物甾醇')) return 'supplements';
    return null;
  }

  /// 获取自定义显示名称（优先 settings，否则用原始 label）
  String _displayName(HabitItem item) {
    final key = keyForHabit(item);
    if (key != null) {
      return _settings.displayNameFor(key);
    }
    return item.label;
  }

  /// 获取自定义图标（优先 settings，否则返回空字符串表示不覆盖）
  String? _icon(HabitItem item) {
    final key = keyForHabit(item);
    if (key != null) {
      final icon = _settings.iconFor(key);
      // 只在有自定义时返回图标
      if (icon != HabitVisualConfig.of(key).icon) return icon;
    }
    return null;
  }

  /// 获取自定义颜色
  Color? _color(HabitItem item) {
    final key = keyForHabit(item);
    if (key != null) {
      final defaultColor = HabitVisualConfig.of(key).color;
      final customArgb = _settings.colorFor(key);
      if (customArgb != defaultColor.toARGB32()) {
        return Color(customArgb);
      }
    }
    return null;
  }

  String? _checkboxField(HabitItem item) => _fieldForLabel(item.label);

  HabitStatus? _toggleCheckbox(HabitItem item, HabitStatus status) {
    final field = _fieldForLabel(item.label);
    if (field == null) return null;
    switch (field) {
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
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.section.habits.isEmpty) return const SizedBox.shrink();

    // 按活跃状态过滤
    final activeHabits = widget.section.habits.where((h) {
      if (widget.activeHabitKeys == null) return true;
      final key = keyForHabit(h);
      return key == null || widget.activeHabitKeys!.contains(key);
    }).toList();

    if (activeHabits.isEmpty) return const SizedBox.shrink();

    final status = HabitStatus.fromHabitSection(widget.section);

    return SectionCard(
      title: widget.section.title,
      accentColor: _accentColor,
      children: activeHabits
          .map((habit) => _buildRow(habit, status))
          .toList(growable: false),
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

  bool _isWaterHabit(HabitItem item) => item.label.contains('饮');
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
    final field = _HabitCardState._fieldForLabel(habit.label);
    if (field == null) return habit.checked;
    switch (field) {
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
              color: _checked ? Colors.green : theme.disabledColor,
            ),
            const SizedBox(width: 8),
            if (icon != null) ...[
              Text(icon!, style: const TextStyle(fontSize: 16)),
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

  const _WaterCounterRow({
    required this.habit,
    required this.status,
    required this.loading,
    required this.displayName,
    this.icon,
    required this.onIncrement,
  });

  static const _goal = 1500;

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
                Text(icon!, style: const TextStyle(fontSize: 16)),
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
              _QuickButton(
                label: '目标',
                onTap: loading
                    ? null
                    : () => onIncrement(status.copyWith(water: _goal)),
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
              Text(icon!, style: const TextStyle(fontSize: 16)),
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
            const Icon(Icons.edit, size: 14, color: AppColors.primary),
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
