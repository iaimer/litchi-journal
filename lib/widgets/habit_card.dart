import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../models/habit_settings.dart';
import '../models/habit_visual_config.dart';
import '../theme/app_theme.dart';
import 'habit_icon.dart';
import 'habit_water_sheet.dart';
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
  /// 传入当前内置习惯状态和自定义习惯状态。
  final Future<bool> Function(HabitStatus status, Map<String, bool> states)?
  onCustomCheckboxToggle;

  /// 正向习惯操作保存成功后的完成反馈。
  final VoidCallback? onPositiveFeedback;

  /// 保存全局饮水快捷量。
  final Future<bool> Function(List<int> amounts)? onWaterQuickAmountsChanged;

  const HabitCard({
    super.key,
    required this.section,
    required this.onUpdate,
    this.readOnly = false,
    this.activeHabitKeys,
    this.habitSettings,
    this.onCustomCheckboxToggle,
    this.onPositiveFeedback,
    this.onWaterQuickAmountsChanged,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  String? _updatingField;
  late HabitStatus _status;
  late Map<String, bool> _customCheckboxStates;

  HabitSettings get _settings => widget.habitSettings ?? HabitSettings.defaults;

  @override
  void initState() {
    super.initState();
    _status = HabitStatus.fromHabitSection(widget.section);
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

  @override
  void didUpdateWidget(covariant HabitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_updatingField != null) return;

    final oldStatus = HabitStatus.fromHabitSection(oldWidget.section);
    final nextStatus = HabitStatus.fromHabitSection(widget.section);
    if (!_sameStatus(oldStatus, nextStatus)) {
      _status = nextStatus;
    }
  }

  Future<bool> _update(HabitStatus next, String field) async {
    if (_updatingField != null) return false;

    final previous = _status;
    setState(() {
      _status = next;
      _updatingField = field;
    });

    var ok = false;
    try {
      ok = await widget.onUpdate(next);
    } catch (_) {
      ok = false;
    }

    if (!mounted) return ok;

    if (!ok) {
      setState(() {
        _status = previous;
        _updatingField = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('更新失败')));
      return false;
    }

    if (_isPositiveTransition(previous, next, field)) {
      widget.onPositiveFeedback?.call();
    }
    setState(() => _updatingField = null);
    return true;
  }

  void _handleCheckboxTap(HabitStatus next, String field) {
    _update(next, field);
  }

  Future<void> _handleWaterSheet(Color color) async {
    if (_updatingField != null) return;
    final result = await showHabitWaterSheet(
      context,
      current: _status.water,
      quickAmounts: _settings.waterQuickAmounts,
      accentColor: color,
      onQuickAmountsChanged: widget.onWaterQuickAmountsChanged,
    );
    if (!mounted || result == null) return;
    final nextWater = result.type == HabitWaterActionType.clear
        ? 0
        : _status.water + result.amount;
    if (nextWater == _status.water) return;
    _update(_status.copyWith(water: nextWater), 'water');
  }

  Future<void> _handleStepsEdit() async {
    final currentStatus = _status;
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
      final next = _status.copyWith(steps: result);
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

  bool _isPositiveTransition(
    HabitStatus previous,
    HabitStatus next,
    String field,
  ) {
    switch (field) {
      case 'water':
        return next.water > previous.water;
      case 'steps':
        return next.steps > previous.steps;
      case 'reading':
        return !previous.reading && next.reading;
      case 'language':
        return !previous.language && next.language;
      case 'supplements':
        return !previous.supplements && next.supplements;
      default:
        return false;
    }
  }

  bool _sameStatus(HabitStatus first, HabitStatus second) {
    return first.water == second.water &&
        first.steps == second.steps &&
        first.reading == second.reading &&
        first.language == second.language &&
        first.supplements == second.supplements;
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
    final status = _status;

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
        children.add(
          _CustomCheckboxRow(
            key: ValueKey('custom_habit_$key'),
            habitKey: key,
            settings: settings,
            checked: _customCheckboxStates[key] ?? false,
            onToggle: _handleCustomCheckboxToggle,
            enabled: !widget.readOnly && _updatingField == null,
          ),
        );
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
            target: _settings.targetFor(habit.habitKey!),
            progressColor: Color(_settings.colorFor(habit.habitKey!)),
            onOpen: () =>
                _handleWaterSheet(Color(_settings.colorFor(habit.habitKey!))),
          );
        }
        final habitKey = habit.habitKey;
        return _StepsCounterRow(
          habit: habit,
          status: status,
          loading: _updatingField != null,
          displayName: _displayName(habit),
          icon: _icon(habit),
          target: habitKey == null ? null : _settings.targetFor(habitKey),
          progressColor: habitKey == null
              ? null
              : Color(_settings.colorFor(habitKey)),
          onEdit: _handleStepsEdit,
        );
    }
  }

  Future<bool> _handleCustomCheckboxToggle(String key, bool newChecked) async {
    if (_updatingField != null) return false;

    final previous = Map<String, bool>.from(_customCheckboxStates);
    setState(() => _customCheckboxStates[key] = newChecked);
    if (widget.onCustomCheckboxToggle == null) return true;

    setState(() => _updatingField = 'custom:$key');
    var ok = false;
    try {
      ok = await widget.onCustomCheckboxToggle!(
        _status,
        Map.from(_customCheckboxStates),
      );
    } catch (_) {
      ok = false;
    }

    if (!mounted) return ok;

    if (!ok) {
      setState(() {
        _customCheckboxStates = previous;
        _updatingField = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('更新失败')));
      return false;
    }

    if (!(previous[key] ?? false) && newChecked) {
      widget.onPositiveFeedback?.call();
    }
    setState(() => _updatingField = null);
    return true;
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
            onOpen: null,
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
    final checkedColor = theme.brightness == Brightness.dark
        ? AppColors.darkSuccess
        : AppColors.success;

    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AnimatedHabitCheckbox(checked: _checked, color: checkedColor),
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
  final int? target;
  final Color? progressColor;
  final VoidCallback? onOpen;

  const _WaterCounterRow({
    required this.habit,
    required this.status,
    required this.loading,
    required this.displayName,
    this.icon,
    this.target,
    this.progressColor,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = habit.unit?.trim().isNotEmpty == true
        ? habit.unit!.trim()
        : 'mL';
    final progress = target == null
        ? null
        : _HabitProgressBar(
            key: const ValueKey('habit_progress_water'),
            label: displayName,
            current: status.water,
            target: target!,
            unit: unit,
            color: progressColor ?? theme.colorScheme.primary,
            onTap: onOpen,
            enabled: !loading,
            tapHint: '点击快捷记录饮水',
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
                  target == null
                      ? '$displayName ${status.water} $unit'
                      : displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            progress,
          ] else ...[
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _StepsCounterRow extends StatelessWidget {
  final HabitItem habit;
  final HabitStatus status;
  final bool loading;
  final String displayName;
  final String? icon;
  final int? target;
  final Color? progressColor;
  final VoidCallback onEdit;

  const _StepsCounterRow({
    required this.habit,
    required this.status,
    required this.loading,
    required this.displayName,
    this.icon,
    this.target,
    this.progressColor,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = habit.unit?.trim().isNotEmpty == true
        ? habit.unit!.trim()
        : '步';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              HabitIcon(icon!, size: 16, color: theme.colorScheme.onSurface),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                target == null
                    ? '$displayName ${status.steps} $unit'
                    : displayName,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
        if (target != null) ...[
          const SizedBox(height: 2),
          _HabitProgressBar(
            key: const ValueKey('habit_progress_steps'),
            label: displayName,
            current: status.steps,
            target: target!,
            unit: unit,
            color: progressColor ?? theme.colorScheme.primary,
            onTap: onEdit,
            enabled: !loading,
            tapHint: '点击编辑步数',
          ),
        ],
      ],
    );
  }
}

class _HabitProgressBar extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final String unit;
  final Color color;
  final VoidCallback? onTap;
  final String? tapHint;
  final bool enabled;

  const _HabitProgressBar({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
    required this.color,
    this.onTap,
    this.tapHint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = target <= 0
        ? 0.0
        : (current / target).clamp(0.0, 1.0).toDouble();
    final valueText = '$current/$target $unit';
    final trackColor = color.withAlpha(
      theme.brightness == Brightness.dark ? 62 : 42,
    );

    final progressRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ClipRRect(
                key: ValueKey('habit_progress_track_$label'),
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: trackColor),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: constraints.maxWidth * ratio,
                          height: 6,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valueText,
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.textTheme.bodySmall?.color ??
                    theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
    final hasTapTarget = onTap != null;
    final content = !hasTapTarget
        ? progressRow
        : InkWell(
            onTap: enabled ? onTap : null,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(FloraRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: progressRow,
            ),
          );

    return Semantics(
      label: '$label进度',
      value: valueText,
      hint: enabled && hasTapTarget ? tapHint : null,
      button: hasTapTarget,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: content,
    );
  }
}

class _CustomCheckboxRow extends StatefulWidget {
  final String habitKey;
  final HabitSettings settings;
  final bool checked;
  final Future<bool> Function(String key, bool checked) onToggle;
  final bool enabled;

  const _CustomCheckboxRow({
    super.key,
    required this.habitKey,
    required this.settings,
    required this.checked,
    required this.onToggle,
    required this.enabled,
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
    final color = Color(widget.settings.colorFor(widget.habitKey));

    return InkWell(
      onTap: widget.enabled ? _toggle : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AnimatedHabitCheckbox(checked: _checked, color: color),
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

  Future<void> _toggle() async {
    final previous = _checked;
    final next = !previous;
    setState(() => _checked = next);
    final ok = await widget.onToggle(widget.habitKey, next);
    if (!mounted || ok) return;
    setState(() => _checked = previous);
  }
}

class _AnimatedHabitCheckbox extends StatefulWidget {
  final bool checked;
  final Color color;

  const _AnimatedHabitCheckbox({required this.checked, required this.color});

  @override
  State<_AnimatedHabitCheckbox> createState() => _AnimatedHabitCheckboxState();
}

class _AnimatedHabitCheckboxState extends State<_AnimatedHabitCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.checked ? 1 : 0,
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedHabitCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checked == widget.checked) return;
    if (widget.checked) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactiveColor = theme.colorScheme.onSurface.withAlpha(
      theme.brightness == Brightness.dark ? 120 : 95,
    );

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final value = _curve.value;
        final scale = 1 - (0.10 * (1 - (2 * value - 1).abs()));
        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            size: const Size.square(22),
            painter: _HabitCheckboxPainter(
              progress: value,
              color: widget.color,
              inactiveColor: inactiveColor,
            ),
          ),
        );
      },
    );
  }
}

class _HabitCheckboxPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color inactiveColor;

  const _HabitCheckboxPainter({
    required this.progress,
    required this.color,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final boxRect = Rect.fromCenter(center: center, width: 18, height: 18);
    const radius = Radius.circular(3);
    final borderColor = Color.lerp(inactiveColor, color, progress)!;

    if (progress > 0) {
      final haloPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withAlpha((58 * (1 - progress)).round());
      canvas.drawCircle(center, 9 * (1 + 2.5 * progress), haloPaint);
    }

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withAlpha((255 * progress).round());
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, radius), fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = borderColor;
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, radius), borderPaint);

    if (progress == 0) return;

    final checkProgress = ((progress - 0.25) / 0.75).clamp(0.0, 1.0);
    if (checkProgress == 0) return;

    final checkPath = Path()
      ..moveTo(boxRect.left + 3.5, boxRect.top + 9)
      ..lineTo(boxRect.left + 6.5, boxRect.top + 12)
      ..lineTo(boxRect.left + 12.5, boxRect.top + 4);

    final metric = checkPath.computeMetrics().first;
    final visiblePath = metric.extractPath(0, metric.length * checkProgress);
    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withAlpha(245);
    canvas.drawPath(visiblePath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _HabitCheckboxPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
