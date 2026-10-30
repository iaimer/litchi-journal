import 'package:flutter/material.dart';

import 'diary_module_visual.dart';
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
          icon: FloraIcon(
            DiaryModuleVisual.forType('happiness')!.icon,
            size: 28,
            color: DiaryModuleVisual.forType('happiness')!.color,
          ),
          onTap: () => onEntrySelected(EntryType.happiness),
        ),
        QuickRecordMenuAction(
          key: const Key('historical_quick_record_reflection'),
          title: '觉察',
          icon: FloraIcon(
            DiaryModuleVisual.forType('review')!.icon,
            size: 28,
            color: DiaryModuleVisual.forType('review')!.color,
          ),
          onTap: () => onEntrySelected(EntryType.reflection),
        ),
        QuickRecordMenuAction(
          key: const Key('historical_quick_record_quick_note'),
          title: '随手记',
          icon: FloraIcon(
            DiaryModuleVisual.forType('quickNote')!.icon,
            size: 28,
            color: DiaryModuleVisual.forType('quickNote')!.color,
          ),
          onTap: () => onEntrySelected(EntryType.quickNote),
        ),
      ],
    );
  }
}
