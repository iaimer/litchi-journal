import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'entry_type.dart';
import 'flora_icon.dart';

class HistoricalQuickRecordFab extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<EntryType> onEntrySelected;
  final VoidCallback onImagesSelected;

  const HistoricalQuickRecordFab({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.onEntrySelected,
    required this.onImagesSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = [
      _HistoricalAction(
        key: const Key('historical_quick_record_quick_note'),
        title: '随手记',
        icon: const FloraIcon(FloraIcons.fabWrite, size: 19),
        angleDegrees: 180,
        onTap: () => onEntrySelected(EntryType.quickNote),
      ),
      _HistoricalAction(
        key: const Key('historical_quick_record_reflection'),
        title: '觉察',
        icon: const FloraIcon(FloraIcons.fabInsight, size: 19),
        angleDegrees: 147,
        onTap: () => onEntrySelected(EntryType.reflection),
      ),
      _HistoricalAction(
        key: const Key('historical_quick_record_happiness'),
        title: '小确幸',
        icon: const FloraIcon(FloraIcons.fabHappy, size: 19),
        angleDegrees: 114,
        onTap: () => onEntrySelected(EntryType.happiness),
      ),
      _HistoricalAction(
        key: const Key('historical_quick_record_images'),
        title: '添加相片',
        icon: const FloraIcon(FloraIcons.fabPhoto, size: 19),
        angleDegrees: 82,
        onTap: onImagesSelected,
      ),
    ];

    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomRight,
        children: [
          if (expanded)
            for (final action in actions) _buildAction(context, action),
          FloatingActionButton(
            key: const Key('historical_quick_record_fab'),
            tooltip: '补录',
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: const CircleBorder(),
            onPressed: onToggle,
            child: Icon(expanded ? Icons.close : Icons.add, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, _HistoricalAction action) {
    const radius = 120.0;
    const mainCenter = 28.0;
    const hitSize = 48.0;
    const visualSize = 42.0;
    final angle = action.angleDegrees * math.pi / 180;
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);
    final theme = Theme.of(context);

    return Positioned(
      right: mainCenter - dx - hitSize / 2,
      bottom: mainCenter + dy - hitSize / 2,
      child: Tooltip(
        message: action.title,
        child: Semantics(
          label: action.title,
          button: true,
          child: SizedBox(
            key: action.key,
            width: hitSize,
            height: hitSize,
            child: Center(
              child: SizedBox(
                width: visualSize,
                height: visualSize,
                child: Material(
                  color: theme.colorScheme.surface,
                  elevation: 2,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: action.onTap,
                    child: Center(child: action.icon),
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

class _HistoricalAction {
  final Key key;
  final String title;
  final Widget icon;
  final double angleDegrees;
  final VoidCallback onTap;

  const _HistoricalAction({
    required this.key,
    required this.title,
    required this.icon,
    required this.angleDegrees,
    required this.onTap,
  });
}
