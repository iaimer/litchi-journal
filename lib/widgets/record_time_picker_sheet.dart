import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<TimeOfDay?> showRecordTimePickerSheet(
  BuildContext context, {
  required DateTime targetDate,
  required TimeOfDay initialTime,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(FloraRadius.lg)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) {
      final mediaQuery = MediaQuery.of(sheetContext);
      return FractionallySizedBox(
        heightFactor: _sheetHeightFactor(mediaQuery),
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          child: _RecordTimePickerSheet(
            targetDate: targetDate,
            initialTime: initialTime,
          ),
        ),
      );
    },
  );
}

double _sheetHeightFactor(MediaQueryData mediaQuery) {
  final scaledBody = mediaQuery.textScaler.scale(16);
  if (mediaQuery.size.height < 700 || scaledBody > 21) return 0.82;
  return 0.62;
}

class _RecordTimePickerSheet extends StatefulWidget {
  final DateTime targetDate;
  final TimeOfDay initialTime;

  const _RecordTimePickerSheet({
    required this.targetDate,
    required this.initialTime,
  });

  @override
  State<_RecordTimePickerSheet> createState() => _RecordTimePickerSheetState();
}

class _RecordTimePickerSheetState extends State<_RecordTimePickerSheet> {
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String get _dateLabel =>
      '${widget.targetDate.year}年${widget.targetDate.month}月${widget.targetDate.day}日';

  void _confirm() {
    Navigator.of(context).pop(TimeOfDay(hour: _hour, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildHeader(theme),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FloraSpacing.lg,
              vertical: FloraSpacing.md,
            ),
            child: _buildWheels(theme),
          ),
        ),
        _buildActions(theme),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FloraSpacing.lg,
        FloraSpacing.sm,
        FloraSpacing.lg,
        FloraSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '选择发生时间',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: FloraSpacing.sm),
          Semantics(
            label: '记录日期',
            value: _dateLabel,
            child: Text(
              _dateLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FloraSpacing.lg,
        FloraSpacing.sm,
        FloraSpacing.lg,
        FloraSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('record_time_cancel'),
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: theme.colorScheme.primary,
              ),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: FloraSpacing.md),
          Expanded(
            child: FilledButton(
              key: const Key('record_time_confirm'),
              onPressed: _confirm,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('确定'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheels(ThemeData theme) {
    final wheelStyle =
        theme.textTheme.headlineSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ) ??
        const TextStyle(fontSize: 24);
    final mediaQuery = MediaQuery.of(context);
    final itemExtent = (mediaQuery.textScaler.scale(24) + 20)
        .clamp(48, 72)
        .toDouble();
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Container(
            height: itemExtent + FloraSpacing.xs,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(FloraRadius.md),
            ),
          ),
        ),
        CupertinoTheme(
          data: CupertinoThemeData(
            brightness: theme.brightness,
            primaryColor: theme.colorScheme.primary,
            textTheme: CupertinoTextThemeData(pickerTextStyle: wheelStyle),
          ),
          child: _buildWheelRow(wheelStyle, itemExtent),
        ),
      ],
    );
  }

  Widget _buildWheelRow(TextStyle style, double itemExtent) {
    return Row(
      children: [
        _buildWheelColumn(
          wheelKey: const Key('record_time_hour_wheel'),
          valueKey: const Key('record_time_hour_value'),
          label: '小时',
          value: '${_twoDigits(_hour)}点',
          itemCount: 24,
          itemExtent: itemExtent,
          controller: _hourController,
          style: style,
          onChanged: (hour) => setState(() => _hour = hour),
        ),
        Text(':', style: style),
        _buildWheelColumn(
          wheelKey: const Key('record_time_minute_wheel'),
          valueKey: const Key('record_time_minute_value'),
          label: '分钟',
          value: '${_twoDigits(_minute)}分',
          itemCount: 60,
          itemExtent: itemExtent,
          controller: _minuteController,
          style: style,
          onChanged: (minute) => setState(() => _minute = minute),
        ),
      ],
    );
  }

  Widget _buildWheelColumn({
    required Key wheelKey,
    required Key valueKey,
    required String label,
    required String value,
    required int itemCount,
    required double itemExtent,
    required FixedExtentScrollController controller,
    required TextStyle style,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: Semantics(
        key: valueKey,
        label: label,
        value: value,
        child: CupertinoPicker(
          key: wheelKey,
          scrollController: controller,
          itemExtent: itemExtent,
          looping: true,
          useMagnifier: true,
          magnification: 1.22,
          selectionOverlay: const SizedBox.shrink(),
          onSelectedItemChanged: onChanged,
          children: [
            for (var index = 0; index < itemCount; index++)
              Center(child: Text(_twoDigits(index), style: style)),
          ],
        ),
      ),
    );
  }
}
