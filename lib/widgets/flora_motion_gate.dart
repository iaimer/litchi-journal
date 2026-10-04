import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 动态关闭动画时也结束路由计时，不能只把最后一帧画出来。
mixin FloraPopupMotion<T> on PopupRoute<T> {
  bool motionDisabled = false;

  @override
  Duration get transitionDuration =>
      motionDisabled ? Duration.zero : FloraMotion.standard;

  @override
  Duration get reverseTransitionDuration =>
      motionDisabled ? Duration.zero : FloraMotion.fast;

  void updateMotion(bool disabled) {
    motionDisabled = disabled;
    controller?.duration = disabled ? Duration.zero : transitionDuration;
    controller?.reverseDuration = disabled
        ? Duration.zero
        : reverseTransitionDuration;
    if (disabled) completeMotion();
  }

  void completeMotion() {
    final motion = controller;
    if (motion == null || !motion.isAnimating) return;
    motion.value = motion.status == AnimationStatus.reverse ? 0 : 1;
  }
}

class FloraMotionGate extends StatefulWidget {
  final ValueChanged<bool> onMotionChanged;
  final Widget Function(BuildContext context, bool disabled) builder;

  const FloraMotionGate({
    super.key,
    required this.onMotionChanged,
    required this.builder,
  });

  @override
  State<FloraMotionGate> createState() => _FloraMotionGateState();
}

class _FloraMotionGateState extends State<FloraMotionGate> {
  bool _disabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disabled =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onMotionChanged(_disabled);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _disabled);
}
