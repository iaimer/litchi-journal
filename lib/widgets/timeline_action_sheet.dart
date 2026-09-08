import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'flora_icon.dart';

enum TimelineAction { edit, delete }

Future<TimelineAction?> showTimelineActionSheet(
  BuildContext context, {
  required bool showEdit,
  required bool showDelete,
}) {
  final theme = Theme.of(context);
  final actions = [
    if (showEdit)
      const _TimelineSheetAction(
        action: TimelineAction.edit,
        label: '编辑',
        icon: FloraIcon(FloraIcons.edit, size: 24),
      ),
    if (showDelete)
      const _TimelineSheetAction(
        action: TimelineAction.delete,
        label: '删除',
        icon: Icon(Icons.delete_outline_rounded, size: 24),
      ),
  ];

  return showModalBottomSheet<TimelineAction>(
    context: context,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(FloraRadius.lg)),
    ),
    builder: (sheetContext) {
      final actionLayout = actions.length == 1
          ? SizedBox(
              width: double.infinity,
              child: _TimelineActionTile(
                action: actions.first,
                horizontal: true,
                onTap: () =>
                    Navigator.of(sheetContext).pop(actions.first.action),
              ),
            )
          : Row(
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) const SizedBox(width: FloraSpacing.md),
                  Expanded(
                    child: _TimelineActionTile(
                      action: actions[index],
                      onTap: () =>
                          Navigator.of(sheetContext).pop(actions[index].action),
                    ),
                  ),
                ],
              ],
            );

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FloraSpacing.lg,
            FloraSpacing.xs,
            FloraSpacing.lg,
            FloraSpacing.lg,
          ),
          child: actionLayout,
        ),
      );
    },
  );
}

class _TimelineSheetAction {
  final TimelineAction action;
  final String label;
  final Widget icon;

  const _TimelineSheetAction({
    required this.action,
    required this.label,
    required this.icon,
  });
}

class _TimelineActionTile extends StatelessWidget {
  final _TimelineSheetAction action;
  final bool horizontal;
  final VoidCallback onTap;

  const _TimelineActionTile({
    required this.action,
    this.horizontal = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = theme.brightness == Brightness.dark
        ? AppColors.darkSurfaceElevated
        : AppColors.surfaceSoft;
    final contentColor = action.action == TimelineAction.delete
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      label: action.label,
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(FloraRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FloraRadius.lg),
          child: SizedBox(
            height: horizontal ? 56 : 88,
            child: Padding(
              padding: horizontal
                  ? const EdgeInsets.symmetric(horizontal: FloraSpacing.lg)
                  : const EdgeInsets.all(FloraSpacing.md),
              child: horizontal
                  ? Row(
                      children: [
                        IconTheme(
                          data: IconThemeData(color: contentColor, size: 24),
                          child: action.icon,
                        ),
                        const SizedBox(width: FloraSpacing.md),
                        Text(
                          action.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: contentColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconTheme(
                          data: IconThemeData(color: contentColor, size: 24),
                          child: action.icon,
                        ),
                        const SizedBox(height: FloraSpacing.xs),
                        Text(
                          action.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: contentColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
