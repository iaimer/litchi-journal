import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'flora_glass.dart';
import 'flora_icon.dart';
import 'flora_origin.dart';
import 'flora_origin_transform.dart';
import 'flora_motion_gate.dart';

enum TimelineAction { edit, delete }

Future<TimelineAction?> showTimelineActionSheet(
  BuildContext context, {
  required bool showEdit,
  required bool showDelete,
}) async {
  final actions = [
    if (showEdit) TimelineAction.edit,
    if (showDelete) TimelineAction.delete,
  ];
  if (actions.isEmpty) return Future.value();
  final navigator = Navigator.of(context);
  final route = _TimelineMenuRoute(
    actions: actions,
    origin: FloraOrigin.current,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    disableAnimations: MediaQuery.disableAnimationsOf(context),
    label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}

/// 按可用空间选择按钮下方或上方，始终留在安全区域内。
Rect timelineMenuBounds({
  required Rect source,
  required Size viewport,
  required EdgeInsets padding,
  required Size menuSize,
}) {
  final safe = Rect.fromLTRB(
    padding.left + 12,
    padding.top + 12,
    viewport.width - padding.right - 12,
    viewport.height - padding.bottom - 12,
  );
  final width = math.min(menuSize.width, safe.width);
  final height = math.min(menuSize.height, safe.height);
  final left = (source.right - width).clamp(safe.left, safe.right - width);
  final below = source.bottom + 8;
  final top = (below + height <= safe.bottom ? below : source.top - height - 8)
      .clamp(safe.top, safe.bottom - height);
  return Rect.fromLTWH(left, top, width, height);
}

class _TimelineMenuRoute extends PopupRoute<TimelineAction>
    with FloraPopupMotion<TimelineAction> {
  final List<TimelineAction> actions;
  final FloraOrigin? origin;
  final CapturedThemes themes;
  final String label;

  _TimelineMenuRoute({
    required this.actions,
    required this.origin,
    required this.themes,
    required bool disableAnimations,
    required this.label,
  }) {
    motionDisabled = disableAnimations;
  }

  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.06);
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => label;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => themes.wrap(
    LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final size = constraints.biggest;
        final rowHeight = math.max(56.0, media.textScaler.scale(16) + 32);
        final source =
            origin?.scaledRect(size) ??
            Rect.fromCenter(
              center: size.center(Offset.zero),
              width: 48,
              height: 48,
            );
        final bounds = timelineMenuBounds(
          source: source,
          viewport: size,
          padding: media.padding.copyWith(
            bottom: math.max(media.padding.bottom, media.viewInsets.bottom),
          ),
          menuSize: Size(176, rowHeight * actions.length),
        );
        return Stack(
          children: [
            Positioned.fromRect(
              rect: bounds,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) => FloraMotionGate(
                  onMotionChanged: updateMotion,
                  builder: (context, disabled) => FloraOriginTransform(
                    source: animation.status == AnimationStatus.reverse
                        ? origin?.returnRect(size)
                        : origin?.scaledRect(size),
                    progress: disabled
                        ? 1
                        : Curves.easeOutQuart.transform(animation.value),
                    child: Opacity(
                      opacity: disabled ? 1 : animation.value,
                      child: FloraGlassSurface(
                        child: Semantics(
                          scopesRoute: true,
                          namesRoute: true,
                          explicitChildNodes: true,
                          label: '记录操作',
                          child: FocusScope(
                            autofocus: true,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final action in actions)
                                    _TimelineActionRow(
                                      action: action,
                                      height: rowHeight,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _TimelineActionRow extends StatelessWidget {
  final TimelineAction action;
  final double height;

  const _TimelineActionRow({required this.action, required this.height});

  @override
  Widget build(BuildContext context) {
    final deleting = action == TimelineAction.delete;
    final color = deleting
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: () => Navigator.of(context).pop(action),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FloraIcon(
                deleting ? FloraIcons.delete : FloraIcons.edit,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  deleting ? '删除' : '编辑',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
