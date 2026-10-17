import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'flora_sheet.dart';
import 'flora_origin.dart';

import '../models/diary_document.dart';
import '../services/failure_messages.dart';
import '../models/focus_timer.dart';
import '../models/habit_settings.dart';
import '../models/habit_visual_config.dart';
import '../theme/app_theme.dart';
import 'habit_icon.dart';
import 'habit_steps_sheet.dart';
import 'habit_water_sheet.dart';
import 'diary_section_title.dart';
import 'section_card.dart';

class HabitCard extends StatefulWidget {
  final HabitSection section;
  final Future<bool> Function(HabitStatus) onUpdate;
  final bool readOnly;
  final bool preserveControlLayout;

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

  /// 从习惯行打开全局专注计时页。
  final Future<bool> Function(HabitTimerTarget target)? onStartDuration;

  /// 手动设置或追加计时型习惯的今日分钟数。
  /// 第三个参数为 true 时覆盖今日总量，否则追加分钟数。
  final Future<bool> Function(
    HabitTimerTarget target,
    int minutes,
    bool replace,
  )?
  onDurationUpdate;

  /// 自定义计时习惯状态变化回调。
  final Future<bool> Function(
    HabitStatus status,
    Map<String, bool> checkboxStates,
    Map<String, int> durationStates,
  )?
  onCustomDurationUpdate;

  /// 当前习惯所属日，用于跨日计时写回。
  final DateTime? diaryDate;

  const HabitCard({
    super.key,
    required this.section,
    required this.onUpdate,
    this.readOnly = false,
    this.preserveControlLayout = false,
    this.activeHabitKeys,
    this.habitSettings,
    this.onCustomCheckboxToggle,
    this.onPositiveFeedback,
    this.onWaterQuickAmountsChanged,
    this.onStartDuration,
    this.onDurationUpdate,
    this.onCustomDurationUpdate,
    this.diaryDate,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> with WidgetsBindingObserver {
  String? _updatingField;
  final _feedback = <String, _HabitFeedback>{};
  int _feedbackRevision = 0;
  bool get _motionAllowed =>
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  late HabitStatus _status;
  late Map<String, bool> _customCheckboxStates;
  late Map<String, int> _customDurationStates;

  HabitSettings get _settings => widget.habitSettings ?? HabitSettings.defaults;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = HabitStatus.fromHabitSection(widget.section);
    _customCheckboxStates = {};
    _customDurationStates = {};
    // 从已解析的 Markdown 中读取自定义习惯的 checked 状态
    for (final item in widget.section.habits) {
      if (item.habitKey != null) continue;
      final key = _settings.customHabitKeyForLabel(item.label);
      if (key != null) {
        _customCheckboxStates[key] = item.checked;
        if (item.kind == HabitKind.duration) {
          _customDurationStates[key] = item.value ?? 0;
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant HabitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diaryDate != widget.diaryDate ||
        oldWidget.readOnly != widget.readOnly ||
        oldWidget.habitSettings != widget.habitSettings ||
        !setEquals(oldWidget.activeHabitKeys, widget.activeHabitKeys)) {
      _feedback.clear();
    }
    if (_updatingField != null) return;

    final oldStatus = HabitStatus.fromHabitSection(oldWidget.section);
    final nextStatus = HabitStatus.fromHabitSection(widget.section);
    if (!_sameStatus(oldStatus, nextStatus)) {
      _status = nextStatus;
    }
    _syncCustomStatesFromSection();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_motionAllowed) _feedback.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _feedback.clear();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  _HabitFeedback? _beginFeedback(String key, bool before, bool after) {
    if (before == after || !_motionAllowed || widget.readOnly) return null;
    final feedback = _HabitFeedback(++_feedbackRevision);
    _feedback[key] = feedback;
    return feedback;
  }

  void _confirmFeedback(String key, _HabitFeedback? feedback) {
    if (feedback == null || !identical(_feedback[key], feedback)) return;
    _feedback[key] = _HabitFeedback(feedback.revision, confirmed: true);
  }

  void _rollbackFeedback(String key, _HabitFeedback? feedback) {
    if (feedback == null || !identical(_feedback[key], feedback)) return;
    _feedback[key] = _HabitFeedback(++_feedbackRevision, rollback: true);
  }

  bool _completed(String key, HabitStatus status) {
    switch (key) {
      case 'water':
        return status.water >= _settings.targetFor(key)!;
      case 'steps':
        return status.steps >= _settings.targetFor(key)!;
      case 'reading':
        return _settings.trackingTypeFor(key) == HabitTrackingType.duration
            ? _durationCompleted(key, status.readingMinutes, status)
            : status.reading;
      case 'language':
        return _settings.trackingTypeFor(key) == HabitTrackingType.duration
            ? _durationCompleted(key, status.languageMinutes, status)
            : status.language;
      case 'supplements':
        return status.supplements;
      default:
        return false;
    }
  }

  void _syncCustomStatesFromSection() {
    for (final item in widget.section.habits) {
      if (item.habitKey != null) continue;
      final key = _settings.customHabitKeyForLabel(item.label);
      if (key == null) continue;
      if (item.kind == HabitKind.duration) {
        _customDurationStates[key] = item.value ?? 0;
      } else {
        _customCheckboxStates[key] = item.checked;
      }
    }
  }

  Future<bool> _update(HabitStatus next, String field) async {
    if (_updatingField != null) return false;

    final previous = _status;
    _HabitFeedback? feedback;
    setState(() {
      feedback = _beginFeedback(
        field,
        _completed(field, previous),
        _completed(field, next),
      );
      _status = next;
      _updatingField = field;
    });

    var ok = false;
    Object? failure;
    try {
      ok = await widget.onUpdate(next);
    } catch (error) {
      failure = error;
      ok = false;
    }

    if (!mounted) return ok;

    if (!ok) {
      setState(() {
        _rollbackFeedback(field, feedback);
        _status = previous;
        _updatingField = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(writeFailureMessage(failure, fallback: '更新失败'))),
      );
      return false;
    }

    if (_isPositiveTransition(previous, next, field)) {
      widget.onPositiveFeedback?.call();
    }
    setState(() {
      if (_completed(field, next)) _confirmFeedback(field, feedback);
      _updatingField = null;
    });
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
    if (_updatingField != null) return;
    final currentStatus = _status;
    final result = await showHabitStepsSheet(
      context,
      current: currentStatus.steps,
    );
    if (result != null && result != currentStatus.steps) {
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
        first.supplements == second.supplements &&
        first.readingMinutes == second.readingMinutes &&
        first.languageMinutes == second.languageMinutes;
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
        final isDuration =
            settings.trackingTypeFor(key) == HabitTrackingType.duration &&
            widget.onStartDuration != null;
        children.add(
          isDuration
              ? _CustomDurationRow(
                  key: ValueKey('custom_duration_$key'),
                  habitKey: key,
                  settings: settings,
                  minutes: _customDurationStates[key] ?? 0,
                  diaryDate: widget.diaryDate ?? DateTime.now(),
                  onStart: _startDuration,
                  onEdit: _editCustomDuration,
                  enabled: !widget.readOnly && _updatingField == null,
                )
              : _CustomCheckboxRow(
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

    return _HabitFeedbackScope(
      feedback: Map.of(_feedback),
      child: IgnorePointer(
        ignoring: widget.readOnly && widget.preserveControlLayout,
        child: ExcludeFocus(
          excluding: widget.readOnly && widget.preserveControlLayout,
          child: SectionCard(
            accentColor: _accentColor,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            children: [
              Text(
                diarySectionDisplayTitle(widget.section),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(HabitItem habit, HabitStatus status) {
    if (widget.readOnly && !widget.preserveControlLayout) {
      return _buildReadOnlyRow(habit, status);
    }
    if (_isDurationHabit(habit)) {
      return _buildDurationRow(habit, status);
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
      case HabitKind.duration:
        return habit.habitKey == null
            ? _CheckboxRow(
                habit: habit,
                status: status,
                loading: _updatingField != null,
                displayName: _displayName(habit),
                icon: _icon(habit),
                onTap: () {},
              )
            : _buildDurationRow(habit, status);
    }
  }

  Future<bool> _handleCustomCheckboxToggle(String key, bool newChecked) async {
    if (_updatingField != null) return false;

    final previous = Map<String, bool>.from(_customCheckboxStates);
    _HabitFeedback? feedback;
    setState(() {
      feedback = _beginFeedback(key, previous[key] ?? false, newChecked);
      _customCheckboxStates[key] = newChecked;
      if (widget.onCustomCheckboxToggle == null && newChecked) {
        _confirmFeedback(key, feedback);
      }
    });
    if (widget.onCustomCheckboxToggle == null) return true;

    setState(() => _updatingField = 'custom:$key');
    var ok = false;
    Object? failure;
    try {
      ok = await widget.onCustomCheckboxToggle!(
        _status,
        Map.from(_customCheckboxStates),
      );
    } catch (error) {
      failure = error;
      ok = false;
    }

    if (!mounted) return ok;

    if (!ok) {
      setState(() {
        _rollbackFeedback(key, feedback);
        _customCheckboxStates = previous;
        _updatingField = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(writeFailureMessage(failure, fallback: '更新失败'))),
      );
      return false;
    }

    if (!(previous[key] ?? false) && newChecked) {
      widget.onPositiveFeedback?.call();
    }
    setState(() {
      if (newChecked) _confirmFeedback(key, feedback);
      _updatingField = null;
    });
    return true;
  }

  Widget _buildReadOnlyRow(HabitItem habit, HabitStatus status) {
    if (_isDurationHabit(habit)) {
      return _buildDurationRow(habit, status, readOnly: true);
    }
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
          onEdit: null,
        );
      case HabitKind.duration:
        return habit.habitKey == null
            ? _CheckboxRow(
                habit: habit,
                status: status,
                loading: false,
                displayName: _displayName(habit),
                icon: _icon(habit),
                onTap: () {},
              )
            : _buildDurationRow(habit, status, readOnly: true);
    }
  }

  bool _isWaterHabit(HabitItem item) => item.habitKey == 'water';

  bool _isDurationHabit(HabitItem item) {
    final key = item.habitKey;
    return key != null &&
        widget.onStartDuration != null &&
        _settings.trackingTypeFor(key) == HabitTrackingType.duration;
  }

  int _durationMinutes(HabitItem item, HabitStatus status) {
    switch (item.habitKey) {
      case 'reading':
        return status.readingMinutes;
      case 'language':
        return status.languageMinutes;
      default:
        return item.value ?? 0;
    }
  }

  bool _durationCompleted(String key, int minutes, HabitStatus status) {
    final target = _settings.durationDailyTargetFor(key);
    if (minutes > 0) return target == null || minutes >= target;
    // 旧日记只有 checkbox 标记，没有时长，继续保留其完成状态和 streak。
    if (key == 'reading') return status.reading;
    if (key == 'language') return status.language;
    return false;
  }

  HabitTimerTarget _timerTarget({
    required String key,
    required String displayName,
    required String markdownLabel,
    required String? icon,
    required Color color,
    required String rawLine,
    required int minutes,
  }) {
    final date = widget.diaryDate ?? DateTime.now();
    return HabitTimerTarget(
      habitKey: key,
      displayName: displayName,
      markdownLabel: markdownLabel,
      icon: icon ?? HabitVisualConfig.of(key).icon,
      colorArgb: color.toARGB32(),
      diaryDate: date,
      rawLine: rawLine,
      currentMinutes: minutes,
      dailyTargetMinutes: _settings.durationDailyTargetFor(key),
    );
  }

  Widget _buildDurationRow(
    HabitItem habit,
    HabitStatus status, {
    bool readOnly = false,
  }) {
    final key = habit.habitKey!;
    final minutes = _durationMinutes(habit, status);
    final color = _color(habit) ?? Color(_settings.colorFor(key));
    final item = _DurationHabitRow(
      key: ValueKey('habit_duration_$key'),
      habitKey: key,
      displayName: _displayName(habit),
      icon: _icon(habit),
      color: color,
      minutes: minutes,
      dailyTargetMinutes: _settings.durationDailyTargetFor(key),
      checked: _durationCompleted(key, minutes, status),
      onStart: readOnly
          ? null
          : () => _startDuration(
              _timerTarget(
                key: key,
                displayName: _displayName(habit),
                markdownLabel: habit.label,
                icon: _icon(habit),
                color: color,
                rawLine: habit.rawLine,
                minutes: minutes,
              ),
            ),
      onLongPress: readOnly
          ? null
          : () => _editDuration(
              _timerTarget(
                key: key,
                displayName: _displayName(habit),
                markdownLabel: habit.label,
                icon: _icon(habit),
                color: color,
                rawLine: habit.rawLine,
                minutes: minutes,
              ),
            ),
      enabled: !readOnly && _updatingField == null,
    );
    return item;
  }

  Future<void> _startDuration(HabitTimerTarget target) async {
    if (widget.onStartDuration == null || _updatingField != null) return;
    final ok = await widget.onStartDuration!(target);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已有一个专注计时正在进行')));
    }
  }

  Future<void> _editDuration(HabitTimerTarget target) async {
    final result = await _showDurationEditSheet(
      target.displayName,
      target.currentMinutes,
    );
    if (!mounted || result == null) return;
    await _updateDuration(
      target,
      result.minutes,
      result.replace,
      'duration:${target.habitKey}',
    );
  }

  Future<void> _editCustomDuration(String key) async {
    final settings = _settings;
    final minutes = _customDurationStates[key] ?? 0;
    final target = _timerTarget(
      key: key,
      displayName: settings.displayNameFor(key),
      markdownLabel: '📝 ${settings.displayNameFor(key)}',
      icon: settings.iconFor(key),
      color: Color(settings.colorFor(key)),
      rawLine: _customRawLine(key),
      minutes: minutes,
    );
    final result = await _showDurationEditSheet(target.displayName, minutes);
    if (!mounted || result == null) return;
    await _updateCustomDuration(target, result.minutes, result.replace);
  }

  String _customRawLine(String key) {
    for (final item in widget.section.habits) {
      if (item.habitKey == null &&
          _settings.customHabitKeyForLabel(item.label) == key) {
        return item.rawLine;
      }
    }
    return '';
  }

  Future<bool> _updateDuration(
    HabitTimerTarget target,
    int minutes,
    bool replace,
    String field,
  ) async {
    if (_updatingField != null ||
        minutes < 0 ||
        minutes > HabitSettings.maxDurationTarget) {
      return false;
    }
    final previous = _status;
    final current = target.currentMinutes;
    final nextMinutes = replace ? minutes : current + minutes;
    if (nextMinutes > HabitSettings.maxDurationTarget) return false;
    _HabitFeedback? feedback;
    setState(() {
      final next = _statusForDuration(target.habitKey, nextMinutes);
      feedback = _beginFeedback(
        target.habitKey,
        _completed(target.habitKey, previous),
        _completed(target.habitKey, next),
      );
      _status = next;
      _updatingField = field;
    });
    var ok = false;
    Object? failure;
    try {
      ok = widget.onDurationUpdate == null
          ? true
          : await widget.onDurationUpdate!(target, minutes, replace);
    } catch (error) {
      failure = error;
      ok = false;
    }
    if (!mounted) return ok;
    if (!ok) {
      setState(() {
        _rollbackFeedback(target.habitKey, feedback);
        _status = previous;
        _updatingField = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(writeFailureMessage(failure, fallback: '更新失败'))),
      );
      return false;
    }
    if (nextMinutes > current) widget.onPositiveFeedback?.call();
    setState(() {
      if (nextMinutes > current) _confirmFeedback(target.habitKey, feedback);
      _updatingField = null;
    });
    return true;
  }

  HabitStatus _statusForDuration(String key, int minutes) {
    final completed = _settings.durationDailyTargetFor(key) == null
        ? minutes > 0
        : minutes >= _settings.durationDailyTargetFor(key)!;
    if (key == 'reading') {
      return _status.copyWith(reading: completed, readingMinutes: minutes);
    }
    if (key == 'language') {
      return _status.copyWith(language: completed, languageMinutes: minutes);
    }
    return _status;
  }

  Future<bool> _updateCustomDuration(
    HabitTimerTarget target,
    int minutes,
    bool replace,
  ) async {
    if (_updatingField != null ||
        minutes < 0 ||
        minutes > HabitSettings.maxDurationTarget) {
      return false;
    }
    final previous = _customDurationStates[target.habitKey] ?? 0;
    final next = replace ? minutes : previous + minutes;
    if (next > HabitSettings.maxDurationTarget) return false;
    final dailyTarget = _settings.durationDailyTargetFor(target.habitKey);
    bool completed(int value) =>
        dailyTarget == null ? value > 0 : value >= dailyTarget;
    _HabitFeedback? feedback;
    setState(() {
      feedback = _beginFeedback(
        target.habitKey,
        completed(previous),
        completed(next),
      );
      _customDurationStates[target.habitKey] = next;
      _updatingField = 'duration:${target.habitKey}';
    });
    var ok = false;
    Object? failure;
    try {
      ok = widget.onCustomDurationUpdate == null
          ? true
          : await widget.onCustomDurationUpdate!(
              _status,
              Map.from(_customCheckboxStates),
              Map.from(_customDurationStates),
            );
    } catch (error) {
      failure = error;
      ok = false;
    }
    if (!mounted) return ok;
    if (!ok) {
      setState(() {
        _rollbackFeedback(target.habitKey, feedback);
        _customDurationStates[target.habitKey] = previous;
        _updatingField = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(writeFailureMessage(failure, fallback: '更新失败'))),
      );
      return false;
    }
    if (next > previous) widget.onPositiveFeedback?.call();
    setState(() {
      if (next > previous) _confirmFeedback(target.habitKey, feedback);
      _updatingField = null;
    });
    return true;
  }

  Future<_DurationEditResult?> _showDurationEditSheet(
    String displayName,
    int currentMinutes,
  ) async {
    final controller = TextEditingController();
    final result = await showFloraSheet<_DurationEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('记录「$displayName」', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '今日已记录 $currentMinutes 分钟',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '分钟数',
                  suffixText: '分钟',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        const _DurationEditResult(minutes: 0, replace: true),
                      ),
                      child: const Text('清零'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final value = int.tryParse(controller.text.trim());
                        if (value == null || value <= 0) return;
                        Navigator.pop(
                          sheetContext,
                          _DurationEditResult(minutes: value, replace: false),
                        );
                      },
                      child: const Text('追加'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final value = int.tryParse(controller.text.trim());
                        if (value == null || value < 0) return;
                        Navigator.pop(
                          sheetContext,
                          _DurationEditResult(minutes: value, replace: true),
                        );
                      },
                      child: const Text('设为'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    // 弹层 Future 返回时，退出动画的最后一帧可能仍在使用 TextField。
    // 延后一帧释放，避免重建期间访问已 dispose 的 controller。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    return result;
  }
}

class _DurationEditResult {
  final int minutes;
  final bool replace;

  const _DurationEditResult({required this.minutes, required this.replace});
}

class _HabitFeedback {
  final int revision;
  final bool confirmed;
  final bool rollback;

  const _HabitFeedback(
    this.revision, {
    this.confirmed = false,
    this.rollback = false,
  });
}

class _HabitFeedbackScope extends InheritedWidget {
  final Map<String, _HabitFeedback> feedback;

  const _HabitFeedbackScope({required this.feedback, required super.child});

  static _HabitFeedback? forHabit(BuildContext context, String? key) => context
      .dependOnInheritedWidgetOfExactType<_HabitFeedbackScope>()
      ?.feedback[key];

  @override
  bool updateShouldNotify(_HabitFeedbackScope oldWidget) =>
      !mapEquals(feedback, oldWidget.feedback);
}

class _CompactHabitRow extends StatelessWidget {
  final String? feedbackKey;
  final Key? rowKey;
  final Key? statusKey;
  final String displayName;
  final String? icon;
  final bool checked;
  final Color checkedColor;
  final String? valueText;
  final double? progress;
  final Color? progressColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onProgressTap;
  final Key? progressKey;
  final Key? progressTrackKey;
  final String? progressSemanticLabel;
  final String? progressHint;
  final bool enabled;
  final String? semanticLabel;
  final String? semanticHint;
  final String? onTapHint;
  final String? onLongPressHint;

  const _CompactHabitRow({
    this.feedbackKey,
    this.rowKey,
    this.statusKey,
    required this.displayName,
    this.icon,
    required this.checked,
    required this.checkedColor,
    this.valueText,
    this.progress,
    this.progressColor,
    this.onTap,
    this.onLongPress,
    this.onProgressTap,
    this.progressKey,
    this.progressTrackKey,
    this.progressSemanticLabel,
    this.progressHint,
    required this.enabled,
    this.semanticLabel,
    this.semanticHint,
    this.onTapHint,
    this.onLongPressHint,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 300;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final nameWidth = (56.0 * textScale.clamp(1.0, 1.3))
            .clamp(56.0, 72.0)
            .toDouble();
        final valueWidth = isNarrow ? 82.0 : 88.0;
        const statusIconGap = 6.0;
        const iconNameGap = 4.0;
        const nameMetricGap = 6.0;
        final theme = Theme.of(context);
        final hasMetric = valueText != null || progress != null;

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AnimatedHabitCheckbox(
              key: statusKey,
              checked: checked,
              color: checkedColor,
              feedback: _HabitFeedbackScope.forHabit(context, feedbackKey),
            ),
            const SizedBox(width: statusIconGap),
            if (icon != null) ...[
              SizedBox(
                width: 18,
                height: 22,
                child: Center(
                  child: HabitIcon(
                    icon!,
                    size: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: iconNameGap),
            ],
            SizedBox(
              width: nameWidth,
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ),
            if (hasMetric) ...[
              const SizedBox(width: nameMetricGap),
              Expanded(
                child: _HabitProgressBar(
                  key: progressKey,
                  label: progressSemanticLabel ?? displayName,
                  valueText: valueText,
                  valueWidth: valueWidth,
                  ratio: progress,
                  color: progressColor ?? checkedColor,
                  trackKey: progressTrackKey,
                  onTap: onProgressTap,
                  tapHint: progressHint,
                  enabled: enabled,
                ),
              ),
            ] else
              const Spacer(),
          ],
        );

        final rowInteractive = onTap != null || onLongPress != null;
        final content = FloraInkWell(
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          borderRadius: BorderRadius.circular(FloraRadius.sm),
          child: Padding(
            padding: hasMetric
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(vertical: 4),
            child: row,
          ),
        );

        if (rowInteractive) {
          return Semantics(
            key: rowKey,
            container: true,
            excludeSemantics: true,
            button: true,
            enabled: enabled,
            checked: checked,
            label: semanticLabel ?? displayName,
            hint: semanticHint,
            onTapHint: onTapHint,
            onLongPressHint: onLongPressHint,
            onTap: enabled && onTap != null
                ? () => FloraOrigin.run(context, onTap!)
                : null,
            onLongPress: enabled && onLongPress != null
                ? () => FloraOrigin.run(context, onLongPress!)
                : null,
            child: content,
          );
        }

        return Semantics(
          key: rowKey,
          container: true,
          checked: checked,
          label: semanticLabel ?? displayName,
          explicitChildNodes: hasMetric,
          child: content,
        );
      },
    );
  }
}

class _DurationHabitRow extends StatelessWidget {
  final String habitKey;
  final String displayName;
  final String? icon;
  final Color color;
  final int minutes;
  final int? dailyTargetMinutes;
  final bool checked;
  final VoidCallback? onStart;
  final VoidCallback? onLongPress;
  final bool enabled;

  const _DurationHabitRow({
    super.key,
    required this.habitKey,
    required this.displayName,
    required this.icon,
    required this.color,
    required this.minutes,
    required this.dailyTargetMinutes,
    required this.checked,
    required this.onStart,
    required this.onLongPress,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final minutesLabel = minutes > 0 ? '$minutes 分钟' : null;
    final canStart = enabled && onStart != null;
    final canEdit = enabled && onLongPress != null;
    final interactive = canStart || canEdit;
    final semanticLabel = minutesLabel == null
        ? displayName
        : '$displayName，已记录 $minutesLabel';
    final semanticHint = canStart && canEdit
        ? '点击开始计时，长按手动记录时长'
        : canStart
        ? '点击开始计时'
        : canEdit
        ? '长按手动记录时长'
        : null;

    return _CompactHabitRow(
      rowKey: ValueKey('duration_row_$habitKey'),
      feedbackKey: habitKey,
      statusKey: ValueKey('habit_status_$habitKey'),
      displayName: displayName,
      icon: icon,
      checked: checked,
      checkedColor: color,
      valueText: minutesLabel,
      progress: dailyTargetMinutes == null || dailyTargetMinutes! <= 0
          ? null
          : (minutes / dailyTargetMinutes!).clamp(0.0, 1.0).toDouble(),
      progressColor: color,
      progressKey: dailyTargetMinutes == null || dailyTargetMinutes! <= 0
          ? null
          : ValueKey('habit_progress_$habitKey'),
      progressTrackKey: dailyTargetMinutes == null || dailyTargetMinutes! <= 0
          ? null
          : ValueKey('habit_progress_track_$habitKey'),
      onTap: canStart ? onStart : null,
      onLongPress: canEdit ? onLongPress : null,
      enabled: interactive,
      semanticLabel: semanticLabel,
      semanticHint: semanticHint,
      onTapHint: canStart ? '开始计时' : null,
      onLongPressHint: canEdit ? '手动记录时长' : null,
    );
  }
}

class _CustomDurationRow extends StatelessWidget {
  final String habitKey;
  final HabitSettings settings;
  final int minutes;
  final DateTime diaryDate;
  final Future<void> Function(HabitTimerTarget target) onStart;
  final Future<void> Function(String key) onEdit;
  final bool enabled;

  const _CustomDurationRow({
    super.key,
    required this.habitKey,
    required this.settings,
    required this.minutes,
    required this.diaryDate,
    required this.onStart,
    required this.onEdit,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(settings.colorFor(habitKey));
    final target = settings.durationDailyTargetFor(habitKey);
    final name = settings.displayNameFor(habitKey);
    return _DurationHabitRow(
      habitKey: habitKey,
      displayName: name,
      icon: settings.iconFor(habitKey),
      color: color,
      minutes: minutes,
      dailyTargetMinutes: target,
      checked: target == null ? minutes > 0 : minutes >= target,
      onStart: enabled
          ? () => onStart(
              HabitTimerTarget(
                habitKey: habitKey,
                displayName: name,
                markdownLabel: '📝 $name',
                icon: settings.iconFor(habitKey),
                colorArgb: color.toARGB32(),
                diaryDate: diaryDate,
                rawLine: '',
                currentMinutes: minutes,
                dailyTargetMinutes: target,
              ),
            )
          : null,
      onLongPress: enabled ? () => onEdit(habitKey) : null,
      enabled: enabled,
    );
  }
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

    return _CompactHabitRow(
      statusKey: ValueKey('habit_status_${habit.habitKey ?? displayName}'),
      feedbackKey: habit.habitKey,
      displayName: displayName,
      icon: icon,
      checked: _checked,
      checkedColor: checkedColor,
      onTap: loading ? null : onTap,
      enabled: !loading,
      semanticLabel: displayName,
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
    final color = progressColor ?? theme.colorScheme.primary;
    return _CompactHabitRow(
      statusKey: const ValueKey('habit_status_water'),
      feedbackKey: 'water',
      displayName: displayName,
      icon: icon,
      checked: target != null && status.water >= target!,
      checkedColor: color,
      valueText: target == null
          ? '${status.water} $unit'
          : '${status.water}/$target $unit',
      progress: target == null
          ? null
          : (status.water / target!).clamp(0.0, 1.0).toDouble(),
      progressColor: color,
      onProgressTap: onOpen,
      progressKey: target == null
          ? null
          : const ValueKey('habit_progress_water'),
      progressTrackKey: target == null
          ? null
          : const ValueKey('habit_progress_track_饮水'),
      progressSemanticLabel: displayName,
      progressHint: '点击快捷记录饮水',
      enabled: !loading,
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
  final VoidCallback? onEdit;

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
    final color = progressColor ?? theme.colorScheme.primary;
    return _CompactHabitRow(
      statusKey: const ValueKey('habit_status_steps'),
      feedbackKey: 'steps',
      displayName: displayName,
      icon: icon,
      checked: target != null && status.steps >= target!,
      checkedColor: color,
      valueText: target == null
          ? '${status.steps} $unit'
          : '${status.steps}/$target $unit',
      progress: target == null
          ? null
          : (status.steps / target!).clamp(0.0, 1.0).toDouble(),
      progressColor: color,
      onProgressTap: onEdit,
      progressKey: target == null
          ? null
          : const ValueKey('habit_progress_steps'),
      progressTrackKey: target == null
          ? null
          : const ValueKey('habit_progress_track_运动'),
      progressSemanticLabel: displayName,
      progressHint: '点击编辑步数',
      enabled: !loading,
    );
  }
}

class _HabitProgressBar extends StatelessWidget {
  final String label;
  final String? valueText;
  final double? ratio;
  final double valueWidth;
  final Color color;
  final Key? trackKey;
  final VoidCallback? onTap;
  final String? tapHint;
  final bool enabled;

  const _HabitProgressBar({
    super.key,
    required this.label,
    required this.valueText,
    required this.valueWidth,
    required this.ratio,
    required this.color,
    this.trackKey,
    this.onTap,
    this.tapHint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = color.withAlpha(
      theme.brightness == Brightness.dark ? 62 : 42,
    );

    final progressRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (ratio != null)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ClipRRect(
                  key: trackKey,
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
                            duration: FloraMotion.fastFor(
                              MediaQuery.of(context),
                            ),
                            curve: Curves.easeOutCubic,
                            width: constraints.maxWidth * ratio!,
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
          )
        else
          const Spacer(),
        const SizedBox(width: 6),
        SizedBox(
          width: valueWidth,
          child: valueText == null
              ? const SizedBox.shrink()
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    valueText!,
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
    final hasTapTarget = enabled && onTap != null && ratio != null;
    final progressContent = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 30),
      child: Center(child: progressRow),
    );
    final content = !hasTapTarget
        ? progressContent
        : FloraInkWell(
            onTap: onTap,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(FloraRadius.sm),
            child: progressContent,
          );
    final semanticLabel = ratio == null
        ? label
        : label.endsWith('进度')
        ? label
        : '$label进度';

    return Semantics(
      label: semanticLabel,
      value: valueText,
      hint: hasTapTarget ? tapHint : null,
      button: hasTapTarget ? true : null,
      enabled: hasTapTarget ? true : null,
      onTap: hasTapTarget ? () => FloraOrigin.run(context, onTap!) : null,
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
    final displayName = widget.settings.displayNameFor(widget.habitKey);
    final icon = widget.settings.iconFor(widget.habitKey);
    final color = Color(widget.settings.colorFor(widget.habitKey));

    return _CompactHabitRow(
      statusKey: ValueKey('habit_status_${widget.habitKey}'),
      feedbackKey: widget.habitKey,
      displayName: displayName,
      icon: icon.isEmpty ? null : icon,
      checked: _checked,
      checkedColor: color,
      onTap: widget.enabled ? _toggle : null,
      enabled: widget.enabled,
      semanticLabel: displayName,
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
  final _HabitFeedback? feedback;

  const _AnimatedHabitCheckbox({
    super.key,
    required this.checked,
    required this.color,
    this.feedback,
  });

  @override
  State<_AnimatedHabitCheckbox> createState() => _AnimatedHabitCheckboxState();
}

class _AnimatedHabitCheckboxState extends State<_AnimatedHabitCheckbox>
    with TickerProviderStateMixin {
  late final AnimationController _draw;
  late final AnimationController _fade;
  late final AnimationController _celebration;
  bool _pendingCelebration = false;
  bool _drawing = false;
  bool _fading = false;
  bool get _motionDisabled =>
      MediaQuery.disableAnimationsOf(context) ||
      !TickerMode.valuesOf(context).enabled ||
      !(ModalRoute.of(context)?.isCurrent ?? true) ||
      (WidgetsBinding.instance.lifecycleState != null &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed);
  double _frozenFill = 0;
  double _frozenStroke = 0;

  @override
  void initState() {
    super.initState();
    _draw =
        AnimationController(
          vsync: this,
          duration: FloraMotion.habitCheck,
          value: widget.checked ? 1 : 0,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _drawing = false;
            _startCelebrationIfReady();
          }
        });
    _fade = AnimationController(
      vsync: this,
      duration: FloraMotion.fast,
      value: 1,
    );
    _celebration = AnimationController(
      vsync: this,
      duration: FloraMotion.standard,
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionDisabled) _finishImmediately();
  }

  @override
  void didUpdateWidget(covariant _AnimatedHabitCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final feedback = widget.feedback;
    if (_motionDisabled || feedback == null) {
      _finishImmediately();
      return;
    }
    if (oldWidget.feedback?.revision != feedback.revision) {
      _pendingCelebration = false;
      _celebration.value = 1;
      if (widget.checked && !feedback.rollback) {
        _fading = false;
        _fade.value = 1;
        _drawing = true;
        _draw.forward(from: 0);
      } else if (!widget.checked) {
        // 回滚保留当前笔画形状，只降低透明度，不倒着擦除路径。
        _frozenFill = _fillProgress;
        _frozenStroke = _strokeProgress;
        _draw.stop();
        _drawing = false;
        _fading = true;
        _fade.forward(from: 0);
      } else {
        _finishImmediately();
      }
    } else if (oldWidget.checked != widget.checked) {
      _finishImmediately();
    }
    if (feedback.confirmed &&
        (oldWidget.feedback?.revision != feedback.revision ||
            oldWidget.feedback?.confirmed != true) &&
        widget.checked) {
      _pendingCelebration = true;
      _startCelebrationIfReady();
    }
  }

  double get _fillProgress => (_draw.value / 0.2).clamp(0.0, 1.0);

  double get _strokeProgress {
    final value = _draw.value;
    if (value <= 0.3) return value / 0.3 * _HabitCheckboxPainter.shortFraction;
    final longProgress = Curves.easeOutQuad.transform((value - 0.3) / 0.7);
    return _HabitCheckboxPainter.shortFraction +
        (1 - _HabitCheckboxPainter.shortFraction) * longProgress;
  }

  void _startCelebrationIfReady() {
    if (!_pendingCelebration ||
        _drawing ||
        !widget.checked ||
        _motionDisabled) {
      return;
    }
    _pendingCelebration = false;
    _celebration.forward(from: 0);
  }

  void _finishImmediately() {
    _pendingCelebration = false;
    _drawing = false;
    _fading = false;
    _draw.value = widget.checked ? 1 : 0;
    _fade.value = 1;
    _celebration.value = 1;
  }

  @override
  void dispose() {
    _draw.dispose();
    _fade.dispose();
    _celebration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactiveColor = theme.colorScheme.onSurface.withAlpha(
      theme.brightness == Brightness.dark ? 120 : 95,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_draw, _fade, _celebration]),
      builder: (context, child) {
        final opacity = _fading ? 1 - _fade.value : 1.0;
        return CustomPaint(
          size: const Size.square(22),
          painter: _HabitCheckboxPainter(
            fill: (_fading ? _frozenFill : _fillProgress) * opacity,
            stroke: _fading ? _frozenStroke : _strokeProgress,
            strokeOpacity: opacity,
            celebration: _celebration.value,
            color: widget.color,
            inactiveColor: inactiveColor,
          ),
        );
      },
    );
  }
}

class _HabitCheckboxPainter extends CustomPainter {
  static final shortFraction = math.sqrt(18) / (math.sqrt(18) + 10);
  final double fill;
  final double stroke;
  final double strokeOpacity;
  final double celebration;
  final Color color;
  final Color inactiveColor;

  const _HabitCheckboxPainter({
    required this.fill,
    required this.stroke,
    required this.strokeOpacity,
    required this.celebration,
    required this.color,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final boxRect = Rect.fromCenter(center: center, width: 18, height: 18);
    final borderColor = Color.lerp(inactiveColor, color, fill)!;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withAlpha((255 * fill).round());
    canvas.drawCircle(center, 9, fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = borderColor;
    canvas.drawCircle(center, 9, borderPaint);

    final checkPath = Path()
      ..moveTo(boxRect.left + 3.5, boxRect.top + 9)
      ..lineTo(boxRect.left + 6.5, boxRect.top + 12)
      ..lineTo(boxRect.left + 12.5, boxRect.top + 4);

    final metric = checkPath.computeMetrics().first;
    final visiblePath = metric.extractPath(0, metric.length * stroke);
    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withAlpha((245 * strokeOpacity).round());
    if (stroke > 0 && strokeOpacity > 0) {
      canvas.drawPath(visiblePath, checkPaint);
    }
    if (celebration >= 1) return;
    final burst = Curves.easeOutCubic.transform(celebration);
    final burstPaint = Paint()
      ..color = color.withAlpha((220 * (1 - celebration)).round())
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 2;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final start = center + direction * (8 + 3 * burst);
      canvas.drawLine(start, start + direction * 2.5, burstPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HabitCheckboxPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.stroke != stroke ||
        oldDelegate.strokeOpacity != strokeOpacity ||
        oldDelegate.celebration != celebration ||
        oldDelegate.color != color ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
