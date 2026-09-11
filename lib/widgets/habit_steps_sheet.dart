import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/habit_settings.dart';
import '../theme/app_theme.dart';

Future<int?> showHabitStepsSheet(BuildContext context, {required int current}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(FloraRadius.lg)),
    ),
    builder: (sheetContext) => _HabitStepsSheet(current: current),
  );
}

class _HabitStepsSheet extends StatefulWidget {
  final int current;

  const _HabitStepsSheet({required this.current});

  @override
  State<_HabitStepsSheet> createState() => _HabitStepsSheetState();
}

class _HabitStepsSheetState extends State<_HabitStepsSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.current}');
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 0 || value > HabitSettings.maxCounterTarget) {
      setState(() => _error = '请输入 0–500000 的整数');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        padding: EdgeInsets.fromLTRB(
          FloraSpacing.lg,
          FloraSpacing.xs,
          FloraSpacing.lg,
          FloraSpacing.lg + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const ValueKey('habit_steps_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('编辑今日步数', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: FloraSpacing.md),
              TextField(
                key: const ValueKey('habit_steps_input'),
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '今日步数',
                  suffixText: '步',
                  errorText: _error,
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: FloraSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('habit_steps_cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: FloraSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('habit_steps_save'),
                      onPressed: _submit,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
