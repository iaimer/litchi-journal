import 'package:flutter/material.dart';

import 'entry_type.dart';

class EntryTypeSelector extends StatelessWidget {
  final EntryType selected;
  final ValueChanged<EntryType> onChanged;

  const EntryTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: EntryType.values.map((type) {
        final isSelected = selected == type;
        return ChoiceChip(
          label: Text(
            type.label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
          selected: isSelected,
          onSelected: (_) => onChanged(type),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          selectedColor: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          side: const BorderSide(color: Colors.transparent),
        );
      }).toList(growable: false),
    );
  }
}
