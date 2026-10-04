import 'package:flutter/material.dart';

import 'entry_type.dart';
import 'flora_icon.dart';
import 'quick_record_fan.dart';

class HistoricalQuickRecordFab extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<EntryType> onEntrySelected;

  const HistoricalQuickRecordFab({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.onEntrySelected,
  });

  @override
  Widget build(BuildContext context) {
    return QuickRecordFan(
      expanded: expanded,
      mainButtonKey: const Key('historical_quick_record_fab'),
      tooltip: '补录',
      onToggle: onToggle,
      actions: [
        QuickRecordFanAction(
          key: const Key('historical_quick_record_quick_note'),
          title: '随手记',
          icon: const FloraIcon(FloraIcons.fabWrite, size: 19),
          angleDegrees: 180,
          onTap: () => onEntrySelected(EntryType.quickNote),
        ),
        QuickRecordFanAction(
          key: const Key('historical_quick_record_reflection'),
          title: '觉察',
          icon: const FloraIcon(FloraIcons.fabInsight, size: 19),
          angleDegrees: 147,
          onTap: () => onEntrySelected(EntryType.reflection),
        ),
        QuickRecordFanAction(
          key: const Key('historical_quick_record_happiness'),
          title: '小确幸',
          icon: const FloraIcon(FloraIcons.fabHappy, size: 19),
          angleDegrees: 114,
          onTap: () => onEntrySelected(EntryType.happiness),
        ),
      ],
    );
  }
}
