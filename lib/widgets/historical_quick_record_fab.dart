import 'package:flutter/material.dart';

import 'entry_type.dart';
import 'flora_icon.dart';
import 'quick_record_menu.dart';

class HistoricalQuickRecordFab extends StatelessWidget {
  final bool expanded;
  final double topInset;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<EntryType> onEntrySelected;

  const HistoricalQuickRecordFab({
    super.key,
    required this.expanded,
    this.topInset = 0,
    required this.onExpandedChanged,
    required this.onEntrySelected,
  });

  @override
  Widget build(BuildContext context) {
    return QuickRecordMenu(
      expanded: expanded,
      topInset: topInset,
      mainButtonKey: const Key('historical_quick_record_fab'),
      tooltip: '补录',
      onExpandedChanged: onExpandedChanged,
      actions: [
        QuickRecordMenuAction(
          key: const Key('historical_quick_record_happiness'),
          title: '小确幸',
          icon: const FloraIcon(FloraIcons.fabHappy, size: 28),
          onTap: () => onEntrySelected(EntryType.happiness),
        ),
        QuickRecordMenuAction(
          key: const Key('historical_quick_record_reflection'),
          title: '觉察',
          icon: const FloraIcon(FloraIcons.fabInsight, size: 28),
          onTap: () => onEntrySelected(EntryType.reflection),
        ),
        QuickRecordMenuAction(
          key: const Key('historical_quick_record_quick_note'),
          title: '随手记',
          icon: const FloraIcon(FloraIcons.fabWrite, size: 28),
          onTap: () => onEntrySelected(EntryType.quickNote),
        ),
      ],
    );
  }
}
