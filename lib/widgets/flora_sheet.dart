import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'flora_glass.dart';
import 'flora_origin.dart';
import 'flora_origin_transform.dart';
import 'flora_motion_gate.dart';

Future<T?> showFloraSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool showDragHandle = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
}) {
  final navigator = Navigator.of(context);
  final route = _FloraSheetRoute<T>(
    builder: builder,
    origin: FloraOrigin.current,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    disableAnimations: MediaQuery.disableAnimationsOf(context),
    clipBehavior: clipBehavior,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    shape: shape,
  );
  return navigator.push(route);
}

class _FloraSheetRoute<T> extends PopupRoute<T> with FloraPopupMotion<T> {
  final WidgetBuilder builder;
  final FloraOrigin? origin;
  final CapturedThemes themes;
  final bool isScrollControlled;
  final bool showDragHandle;
  final String label;
  final Clip? clipBehavior;
  final bool useSafeArea;
  final Color? backgroundColor;
  final ShapeBorder? shape;

  _FloraSheetRoute({
    required this.builder,
    required this.origin,
    required this.themes,
    required this.isScrollControlled,
    required this.showDragHandle,
    required bool disableAnimations,
    required this.label,
    this.clipBehavior,
    required this.useSafeArea,
    this.backgroundColor,
    this.shape,
  }) {
    motionDisabled = disableAnimations;
  }

  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.18);
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
    SafeArea(
      top: useSafeArea,
      minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  constraints.maxHeight * (isScrollControlled ? 1 : 0.75),
              maxWidth: 640,
            ),
            child: AnimatedBuilder(
              animation: animation,
              child: BottomSheet(
                animationController: controller,
                backgroundColor: Colors.transparent,
                elevation: 0,
                clipBehavior: clipBehavior ?? Clip.none,
                showDragHandle: showDragHandle,
                onClosing: () {
                  if (isCurrent) Navigator.of(context).pop();
                },
                builder: builder,
              ),
              builder: (context, sheet) => FloraMotionGate(
                onMotionChanged: updateMotion,
                builder: (context, disabled) {
                  final progress = disabled
                      ? 1.0
                      : Curves.easeOutQuart.transform(animation.value);
                  final size = MediaQuery.sizeOf(context);
                  final source = animation.status == AnimationStatus.reverse
                      ? origin?.returnRect(size)
                      : origin?.scaledRect(size);
                  return FloraOriginTransform(
                    source: source,
                    progress: progress,
                    child: Opacity(
                      opacity: disabled ? 1 : animation.value,
                      child: FloraGlassSurface(
                        tint: backgroundColor,
                        borderRadius: shape is RoundedRectangleBorder
                            ? (shape as RoundedRectangleBorder).borderRadius
                                  .resolve(Directionality.of(context))
                            : const BorderRadius.all(
                                Radius.circular(FloraRadius.lg),
                              ),
                        child: sheet!,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
