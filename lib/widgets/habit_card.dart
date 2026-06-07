import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../theme/app_theme.dart';
import 'section_card.dart';

class HabitCard extends StatefulWidget {
  final HabitSection section;
  final Future<bool> Function(HabitStatus) onUpdate;

  const HabitCard({
    super.key,
    required this.section,
    required this.onUpdate,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  String? _updatingField;

  Future<void> _update(HabitStatus next, String field) async {
    setState(() => _updatingField = field);
    try {
      final ok = await widget.onUpdate(next);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('更新失败')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('更新失败')));
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
    final controller =
        TextEditingController(text: currentStatus.steps.toString());
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

  @override
  Widget build(BuildContext context) {
    if (widget.section.habits.isEmpty) return const SizedBox.shrink();

    final status = HabitStatus.fromHabitSection(widget.section);

    return SectionCard(
      title: widget.section.title,
      accentColor: AppColors.primary,
      children: widget.section.habits
          .map((habit) => _buildRow(habit, status))
          .toList(growable: false),
    );
  }

  Widget _buildRow(HabitItem habit, HabitStatus status) {
    switch (habit.kind) {
      case HabitKind.checkbox:
        return _CheckboxRow(
          habit: habit,
          status: status,
          loading: _updatingField != null,
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
            onIncrement: (next) => _handleWaterIncrement(next),
          );
        }
        return _StepsCounterRow(
          habit: habit,
          status: status,
          loading: _updatingField != null,
          onEdit: _handleStepsEdit,
        );
    }
  }

  bool _isWaterHabit(HabitItem item) => item.label.contains('饮');

  static String? _fieldForLabel(String label) {
    if (label.contains('阅读')) return 'reading';
    if (label.contains('语言')) return 'language';
    if (label.contains('鱼油') || label.contains('植物甾醇')) return 'supplements';
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
}

class _CheckboxRow extends StatelessWidget {
  final HabitItem habit;
  final HabitStatus status;
  final bool loading;
  final VoidCallback onTap;

  const _CheckboxRow({
    required this.habit,
    required this.status,
    required this.loading,
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
            Expanded(
              child: Text(
                habit.label,
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
  final void Function(HabitStatus next) onIncrement;

  const _WaterCounterRow({
    required this.habit,
    required this.status,
    required this.loading,
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
              Expanded(
                child: Text(
                  '${habit.label} ${status.water} ${habit.unit ?? ""}',
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
                onTap:
                    loading ? null : () => onIncrement(_add(250)),
              ),
              _QuickButton(
                label: '+475',
                onTap:
                    loading ? null : () => onIncrement(_add(475)),
              ),
              _QuickButton(
                label: '+500',
                onTap:
                    loading ? null : () => onIncrement(_add(500)),
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
  final VoidCallback onEdit;

  const _StepsCounterRow({
    required this.habit,
    required this.status,
    required this.loading,
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
            Expanded(
              child: Text(
                '${habit.label} ${status.steps} ${habit.unit ?? ""}',
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.primary),
        ),
      ),
    );
  }
}
