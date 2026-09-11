import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/habit_settings.dart';
import '../theme/app_theme.dart';

enum HabitWaterActionType { add, clear }

class HabitWaterAction {
  final HabitWaterActionType type;
  final int amount;

  const HabitWaterAction.add(this.amount) : type = HabitWaterActionType.add;
  const HabitWaterAction.clear()
    : type = HabitWaterActionType.clear,
      amount = 0;
}

Future<HabitWaterAction?> showHabitWaterSheet(
  BuildContext context, {
  required int current,
  required List<int> quickAmounts,
  required Color accentColor,
  Future<bool> Function(List<int> amounts)? onQuickAmountsChanged,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<HabitWaterAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(FloraRadius.lg)),
    ),
    builder: (sheetContext) => _HabitWaterSheet(
      current: current,
      quickAmounts: quickAmounts,
      accentColor: accentColor,
      onQuickAmountsChanged: onQuickAmountsChanged,
    ),
  );
}

enum _SheetMode { actions, custom, settings }

class _HabitWaterSheet extends StatefulWidget {
  final int current;
  final List<int> quickAmounts;
  final Color accentColor;
  final Future<bool> Function(List<int> amounts)? onQuickAmountsChanged;

  const _HabitWaterSheet({
    required this.current,
    required this.quickAmounts,
    required this.accentColor,
    required this.onQuickAmountsChanged,
  });

  @override
  State<_HabitWaterSheet> createState() => _HabitWaterSheetState();
}

class _HabitWaterSheetState extends State<_HabitWaterSheet> {
  _SheetMode _mode = _SheetMode.actions;
  late List<int> _quickAmounts;
  final _customController = TextEditingController();
  late final List<TextEditingController> _settingControllers;
  String? _customError;
  String? _settingsError;
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    _quickAmounts = _normalizedQuickAmounts(widget.quickAmounts);
    _settingControllers = _quickAmounts
        .map((value) => TextEditingController(text: '$value'))
        .toList();
  }

  List<int> _normalizedQuickAmounts(List<int> values) {
    if (values.length != 3 ||
        values.toSet().length != 3 ||
        values.any(
          (value) => value <= 0 || value > HabitSettings.maxCounterTarget,
        )) {
      return [...HabitSettings.defaultWaterQuickAmounts];
    }
    return [...values]..sort();
  }

  @override
  void dispose() {
    _customController.dispose();
    for (final controller in _settingControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addAmount(int amount) {
    if (widget.current + amount > HabitSettings.maxCounterTarget) {
      _showCustom();
      setState(() => _customError = '今日饮水量不能超过 500000 mL');
      return;
    }
    Navigator.of(context).pop(HabitWaterAction.add(amount));
  }

  void _showCustom() {
    setState(() {
      _mode = _SheetMode.custom;
      _customError = null;
    });
  }

  void _submitCustom() {
    final amount = int.tryParse(_customController.text.trim());
    if (amount == null ||
        amount <= 0 ||
        amount > HabitSettings.maxCounterTarget) {
      setState(() => _customError = '请输入 1–500000 的整数');
      return;
    }
    if (widget.current + amount > HabitSettings.maxCounterTarget) {
      setState(() => _customError = '今日饮水量不能超过 500000 mL');
      return;
    }
    Navigator.of(context).pop(HabitWaterAction.add(amount));
  }

  void _showSettings() {
    for (var index = 0; index < _settingControllers.length; index++) {
      _settingControllers[index].text = '${_quickAmounts[index]}';
    }
    setState(() {
      _mode = _SheetMode.settings;
      _settingsError = null;
    });
  }

  Future<void> _saveSettings() async {
    final values = _settingControllers
        .map((controller) => int.tryParse(controller.text.trim()))
        .toList();
    if (values.any(
      (value) =>
          value == null || value <= 0 || value > HabitSettings.maxCounterTarget,
    )) {
      setState(() => _settingsError = '每个快捷量都必须是 1–500000 的整数');
      return;
    }
    final amounts = values.cast<int>()..sort();
    if (amounts.toSet().length != 3) {
      setState(() => _settingsError = '三个快捷量不能重复');
      return;
    }

    setState(() {
      _savingSettings = true;
      _settingsError = null;
    });
    final ok = await widget.onQuickAmountsChanged?.call(amounts) ?? false;
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _savingSettings = false;
        _settingsError = '保存失败，请重试';
      });
      return;
    }
    setState(() {
      _quickAmounts = amounts;
      _savingSettings = false;
      _mode = _SheetMode.actions;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.fromLTRB(
          FloraSpacing.lg,
          FloraSpacing.xs,
          FloraSpacing.lg,
          FloraSpacing.lg + bottomInset,
        ),
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: switch (_mode) {
            _SheetMode.actions => _buildActions(),
            _SheetMode.custom => _buildCustom(),
            _SheetMode.settings => _buildSettings(),
          },
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      key: const ValueKey('habit_water_sheet_actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var index = 0; index < _quickAmounts.length; index++) ...[
              if (index > 0) const SizedBox(width: FloraSpacing.sm),
              Expanded(
                child: _ActionTile(
                  key: ValueKey('habit_water_quick_${_quickAmounts[index]}'),
                  label: '+${_quickAmounts[index]}',
                  color: widget.accentColor,
                  onTap: () => _addAmount(_quickAmounts[index]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: FloraSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                key: const ValueKey('habit_water_custom'),
                label: '手动输入',
                onTap: _showCustom,
              ),
            ),
            const SizedBox(width: FloraSpacing.sm),
            Expanded(
              child: _ActionTile(
                key: const ValueKey('habit_water_clear'),
                label: '清零',
                destructive: true,
                onTap: () =>
                    Navigator.of(context).pop(const HabitWaterAction.clear()),
              ),
            ),
            const SizedBox(width: FloraSpacing.sm),
            Expanded(
              child: _ActionTile(
                key: const ValueKey('habit_water_settings'),
                label: '自定义预设',
                semanticsLabel: '自定义饮水预设',
                onTap: widget.onQuickAmountsChanged == null
                    ? null
                    : _showSettings,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustom() {
    return Column(
      key: const ValueKey('habit_water_sheet_custom'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('手动输入饮水量', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: FloraSpacing.md),
        TextField(
          key: const ValueKey('habit_water_custom_input'),
          controller: _customController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: '添加水量',
            suffixText: 'mL',
            errorText: _customError,
          ),
          onChanged: (_) => setState(() => _customError = null),
          onSubmitted: (_) => _submitCustom(),
        ),
        const SizedBox(height: FloraSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _mode = _SheetMode.actions),
                child: const Text('返回'),
              ),
            ),
            const SizedBox(width: FloraSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: _submitCustom,
                child: const Text('添加'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettings() {
    return Column(
      key: const ValueKey('habit_water_sheet_settings'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('自定义饮水预设', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: FloraSpacing.md),
        for (var index = 0; index < _settingControllers.length; index++) ...[
          TextField(
            key: ValueKey('habit_water_setting_${index + 1}'),
            controller: _settingControllers[index],
            enabled: !_savingSettings,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: '快捷量 ${index + 1}',
              suffixText: 'mL',
            ),
            onChanged: (_) => setState(() => _settingsError = null),
          ),
          if (index < _settingControllers.length - 1)
            const SizedBox(height: FloraSpacing.sm),
        ],
        if (_settingsError != null) ...[
          const SizedBox(height: FloraSpacing.sm),
          Text(
            _settingsError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: FloraSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _savingSettings
                    ? null
                    : () {
                        for (
                          var index = 0;
                          index < _settingControllers.length;
                          index++
                        ) {
                          _settingControllers[index].text =
                              '${HabitSettings.defaultWaterQuickAmounts[index]}';
                        }
                        setState(() => _settingsError = null);
                      },
                child: const Text('恢复默认'),
              ),
            ),
            const SizedBox(width: FloraSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: _savingSettings ? null : _saveSettings,
                child: Text(_savingSettings ? '保存中…' : '保存'),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: _savingSettings
              ? null
              : () => setState(() => _mode = _SheetMode.actions),
          child: const Text('返回快捷添加'),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final String? semanticsLabel;
  final Color? color;
  final bool destructive;
  final VoidCallback? onTap;

  const _ActionTile({
    super.key,
    required this.label,
    this.semanticsLabel,
    this.color,
    this.destructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = theme.brightness == Brightness.dark
        ? AppColors.darkSurfaceElevated
        : AppColors.surfaceSoft;
    final contentColor = destructive
        ? theme.colorScheme.error
        : color ?? theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(FloraRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FloraRadius.lg),
          child: SizedBox(
            height: 56,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
