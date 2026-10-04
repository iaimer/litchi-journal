import 'dart:async';

import 'package:flutter/material.dart';

/// 来源属于一次操作的异步链，避免后一次点击覆盖尚未完成的导航。
class FloraOrigin {
  static final _zoneKey = Object();

  final Rect rect;
  final Size viewport;
  final bool disableAnimations;
  final BuildContext? returnContext;
  final RenderBox? returnBox;

  const FloraOrigin({
    required this.rect,
    required this.viewport,
    this.disableAnimations = false,
    this.returnContext,
    this.returnBox,
  });

  static FloraOrigin? get current => Zone.current[_zoneKey] as FloraOrigin?;

  static FloraOrigin? capture(
    BuildContext context, {
    BuildContext? returnContext,
  }) {
    if (!context.mounted) return null;
    final box = context.findRenderObject();
    final media = MediaQuery.maybeOf(context);
    if (box is! RenderBox || !box.attached || !box.hasSize || media == null) {
      return null;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.isEmpty ||
        !rect.isFinite ||
        media.size.isEmpty ||
        !rect.overlaps(Offset.zero & media.size)) {
      return null;
    }
    final returnObject = returnContext?.findRenderObject() ?? box;
    return FloraOrigin(
      rect: rect,
      viewport: media.size,
      disableAnimations: media.disableAnimations,
      returnContext: returnContext ?? context,
      returnBox: returnObject is RenderBox ? returnObject : null,
    );
  }

  static R run<R>(
    BuildContext context,
    R Function() action, {
    BuildContext? returnContext,
  }) {
    final origin = capture(context, returnContext: returnContext);
    if (origin == null) return action();
    return withOrigin(origin, action);
  }

  static R withOrigin<R>(FloraOrigin? origin, R Function() action) =>
      runZoned(action, zoneValues: {_zoneKey: origin});

  Rect scaledRect(Size size) => Rect.fromLTWH(
    rect.left * size.width / viewport.width,
    rect.top * size.height / viewport.height,
    rect.width * size.width / viewport.width,
    rect.height * size.height / viewport.height,
  );

  Rect? returnRect(Size size) {
    final context = returnContext;
    if (context == null) return scaledRect(size);
    if (!context.mounted) return null;
    // Element 在退出时可能仍 mounted 但已 inactive；不要再查它的祖先或 RenderObject。
    final box = returnBox;
    if (box == null || !box.attached || !box.hasSize) return null;
    final result = box.localToGlobal(Offset.zero) & box.size;
    return result.overlaps(Offset.zero & size) ? result : null;
  }
}

/// 保留原生 InkWell 的交互，只为下一步菜单或导航携带来源。
class FloraInkWell extends StatelessWidget {
  final Widget? child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final bool excludeFromSemantics;

  const FloraInkWell({
    super.key,
    this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.customBorder,
    this.excludeFromSemantics = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap == null ? null : () => FloraOrigin.run(context, onTap!),
    onLongPress: onLongPress == null
        ? null
        : () => FloraOrigin.run(context, onLongPress!),
    borderRadius: borderRadius,
    customBorder: customBorder,
    excludeFromSemantics: excludeFromSemantics,
    child: child,
  );
}

class FloraOriginIconButton extends StatelessWidget {
  final IconButton button;

  const FloraOriginIconButton({super.key, required this.button});

  @override
  Widget build(BuildContext context) => IconButton(
    key: button.key,
    icon: button.icon,
    iconSize: button.iconSize,
    padding: button.padding,
    alignment: button.alignment,
    constraints: button.constraints,
    splashRadius: button.splashRadius,
    color: button.color,
    focusColor: button.focusColor,
    hoverColor: button.hoverColor,
    highlightColor: button.highlightColor,
    splashColor: button.splashColor,
    disabledColor: button.disabledColor,
    tooltip: button.tooltip,
    visualDensity: button.visualDensity,
    style: button.style,
    onHover: button.onHover,
    mouseCursor: button.mouseCursor,
    focusNode: button.focusNode,
    autofocus: button.autofocus,
    enableFeedback: button.enableFeedback,
    isSelected: button.isSelected,
    selectedIcon: button.selectedIcon,
    statesController: button.statesController,
    onLongPress: button.onLongPress == null
        ? null
        : () => FloraOrigin.run(context, button.onLongPress!),
    onPressed: button.onPressed == null
        ? null
        : () => FloraOrigin.run(context, button.onPressed!),
  );
}
