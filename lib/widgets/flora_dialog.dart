import 'package:flutter/material.dart';

import 'flora_origin.dart';
import 'flora_origin_transform.dart';
import 'flora_motion_gate.dart';

/// 保留原生 Dialog 的焦点、确认与安全区域，只替换出现和退出动效。
Future<T?> showFloraDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
  bool barrierDismissible = true,
}) {
  final origin = FloraOrigin.current;
  final reduced = MediaQuery.disableAnimationsOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  late final _FloraDialogRoute<T> route;
  route = _FloraDialogRoute<T>(
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.18),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    disableAnimations: reduced,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    pageBuilder: (dialogContext, _, _) =>
        themes.wrap(SafeArea(child: Builder(builder: builder))),
    transitionBuilder: (context, animation, _, child) {
      final size = MediaQuery.sizeOf(context);
      return FloraMotionGate(
        onMotionChanged: route.updateMotion,
        builder: (context, disabled) => FloraOriginTransform(
          source: animation.status == AnimationStatus.reverse
              ? origin?.returnRect(size)
              : origin?.scaledRect(size),
          progress: disabled
              ? 1
              : Curves.easeOutQuart.transform(animation.value),
          child: Opacity(opacity: disabled ? 1 : animation.value, child: child),
        ),
      );
    },
  );
  return navigator.push<T>(route);
}

class _FloraDialogRoute<T> extends RawDialogRoute<T> with FloraPopupMotion<T> {
  _FloraDialogRoute({
    required super.pageBuilder,
    required super.transitionBuilder,
    required super.barrierDismissible,
    required super.barrierColor,
    required super.barrierLabel,
    required bool disableAnimations,
    required super.traversalEdgeBehavior,
  }) {
    motionDisabled = disableAnimations;
  }
}
