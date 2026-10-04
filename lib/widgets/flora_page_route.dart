import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'flora_origin.dart';
import 'flora_origin_transform.dart';

class FloraPageRoute<T> extends MaterialPageRoute<T> {
  final FloraOrigin? origin;
  bool _motionDisabled;

  FloraPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
    FloraOrigin? origin,
  }) : origin = origin ?? FloraOrigin.current,
       _motionDisabled =
           (origin ?? FloraOrigin.current)?.disableAnimations ?? false,
       super(allowSnapshotting: false);

  @override
  Duration get transitionDuration =>
      _motionDisabled ? Duration.zero : FloraMotion.slow;

  @override
  Duration get reverseTransitionDuration =>
      _motionDisabled ? Duration.zero : FloraMotion.standard;

  void completeMotion() {
    final animationController = controller;
    if (animationController == null || !animationController.isAnimating) return;
    animationController.value =
        animationController.status == AnimationStatus.reverse ? 0 : 1;
  }

  void updateMotion(bool disabled) {
    _motionDisabled = disabled;
    controller?.duration = disabled ? Duration.zero : FloraMotion.slow;
    controller?.reverseDuration = disabled
        ? Duration.zero
        : FloraMotion.standard;
    if (disabled) completeMotion();
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _FloraPageTransition(route: this, animation: animation, child: child);
}

enum _BackPhase { idle, dragging, committing, cancelling }

class _FloraPageTransition extends StatefulWidget {
  final FloraPageRoute<dynamic> route;
  final Animation<double> animation;
  final Widget child;

  const _FloraPageTransition({
    required this.route,
    required this.animation,
    required this.child,
  });

  @override
  State<_FloraPageTransition> createState() => _FloraPageTransitionState();
}

class _FloraPageTransitionState extends State<_FloraPageTransition>
    with WidgetsBindingObserver {
  _BackPhase _phase = _BackPhase.idle;
  SwipeEdge _edge = SwipeEdge.left;
  double _gestureProgress = 0;
  double _cancelStart = 0;
  Rect? _releaseRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _phase == _BackPhase.cancelling) {
      setState(() => _phase = _BackPhase.idle);
    }
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent event) {
    if (event.isButtonEvent ||
        !widget.route.isCurrent ||
        !widget.route.popGestureEnabled ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      return false;
    }
    setState(() {
      _phase = _BackPhase.dragging;
      _edge = event.swipeEdge;
      _gestureProgress = event.progress;
    });
    widget.route.handleStartBackGesture(progress: 1 - event.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent event) {
    if (_phase != _BackPhase.dragging || !widget.route.isCurrent) return;
    setState(() => _gestureProgress = event.progress);
    widget.route.handleUpdateBackGestureProgress(progress: 1 - event.progress);
  }

  Rect _dragRect(Size size) {
    final progress = _gestureProgress.clamp(0.0, 1.0);
    final direction = _edge == SwipeEdge.left ? -1 : 1;
    return Rect.fromLTWH(
      direction * size.width * 0.3 * progress,
      size.height * 0.03 * progress,
      size.width * (1 - 0.06 * progress),
      size.height * (1 - 0.06 * progress),
    );
  }

  @override
  void handleCommitBackGesture() {
    if (_phase != _BackPhase.dragging) return;
    _releaseRect = _dragRect(MediaQuery.sizeOf(context));
    setState(() => _phase = _BackPhase.committing);
    widget.route.handleCommitBackGesture();
  }

  @override
  void handleCancelBackGesture() {
    if (_phase != _BackPhase.dragging) return;
    _releaseRect = _dragRect(MediaQuery.sizeOf(context));
    _cancelStart = widget.animation.value;
    setState(() => _phase = _BackPhase.cancelling);
    widget.route.handleCancelBackGesture();
    // 零进度取消时控制器已经完成，不会再发出 completed 通知。
    if (widget.animation.isCompleted) {
      setState(() => _phase = _BackPhase.idle);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.route.updateMotion(disabled);
      if (disabled && _phase == _BackPhase.dragging) {
        setState(() => _phase = _BackPhase.idle);
        widget.route.handleCancelBackGesture();
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.animation,
    builder: (context, _) => _buildFrame(context),
  );

  Widget _buildFrame(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final disabled =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    final value = disabled ? 1.0 : widget.animation.value;
    final gesture = _phase != _BackPhase.idle && !disabled;
    final source = gesture ? _gestureRect(size, value) : _originRect(size);
    final progress = gesture ? 0.0 : Curves.easeOutQuart.transform(value);
    final opacity = gesture
        ? (_phase == _BackPhase.committing ? value : 1.0)
        : (disabled ? 1.0 : value.clamp(0.0, 1.0));
    return IgnorePointer(
      ignoring: !disabled && (gesture || value < 1),
      child: FloraOriginTransform(
        source: source,
        progress: progress,
        child: Opacity(
          opacity: opacity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(FloraRadius.lg * (1 - value)),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Rect? _originRect(Size size) =>
      widget.animation.status == AnimationStatus.reverse
      ? widget.route.origin?.returnRect(size)
      : widget.route.origin?.scaledRect(size);

  Rect _gestureRect(Size size, double value) {
    if (_phase == _BackPhase.dragging) return _dragRect(size);
    if (_phase == _BackPhase.cancelling) {
      final progress = _cancelStart >= 1
          ? 1.0
          : ((value - _cancelStart) / (1 - _cancelStart)).clamp(0.0, 1.0);
      return Rect.lerp(_releaseRect!, Offset.zero & size, progress)!;
    }
    final target = Rect.fromLTWH(
      _edge == SwipeEdge.left ? -size.width : size.width,
      0,
      size.width,
      size.height,
    );
    return Rect.lerp(_releaseRect!, target, 1 - value)!;
  }
}
