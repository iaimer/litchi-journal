import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 扇形记录菜单展开时，为阅读内容提供独立的退场层。
///
/// 顶部 Banner 与 Scaffold 上层的 Dock、FAB 不在此组件的绘制范围内，
/// 因此始终保持清晰且可操作。
class QuickRecordBackdrop extends StatefulWidget {
  final Widget child;
  final bool expanded;
  final double bannerBottom;
  final VoidCallback onDismiss;

  const QuickRecordBackdrop({
    super.key,
    required this.child,
    required this.expanded,
    required this.bannerBottom,
    required this.onDismiss,
  });

  @override
  State<QuickRecordBackdrop> createState() => _QuickRecordBackdropState();
}

class _QuickRecordBackdropState extends State<QuickRecordBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _readingKey = GlobalKey();
  final _readingPointers = <int>{};
  bool _skipMotion = false;

  bool get _isBlocking => widget.expanded || _controller.value > 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: widget.expanded ? 1 : 0,
      duration: FloraMotion.standard,
      reverseDuration: FloraMotion.fast,
    )..addStatusListener(_handleAnimationStatus);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) {
      // 收回完成后移除滤镜与拦截层，避免留下零强度的合成层。
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final skipMotion =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    if (_skipMotion == skipMotion) return;
    _skipMotion = skipMotion;
    _moveToTarget();
  }

  @override
  void didUpdateWidget(covariant QuickRecordBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    if (widget.expanded) _pauseReadingInteractions();
    _moveToTarget();
  }

  void _pauseReadingInteractions() {
    // IgnorePointer 只拦截新事件，不会撤销已命中的按压或停止惯性滚动。
    for (final pointer in _readingPointers.toList()) {
      GestureBinding.instance.cancelPointer(pointer);
    }
    _readingPointers.clear();
    // 等子树更新完再停止滚动，不在构建过程中遍历或发送滚动通知。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isBlocking) return;
      void stopScroll(Element element) {
        if (element is StatefulElement && element.state is ScrollableState) {
          final position = (element.state as ScrollableState).position;
          position.jumpTo(position.pixels);
        }
        element.visitChildElements(stopScroll);
      }

      _readingKey.currentContext?.visitChildElements(stopScroll);
    });
  }

  void _moveToTarget() {
    final target = widget.expanded ? 1.0 : 0.0;
    if (_skipMotion) {
      _controller.value = target;
      return;
    }
    final distance = (target - _controller.value).abs();
    final fullDuration = widget.expanded
        ? FloraMotion.standard
        : FloraMotion.fast;
    final duration = Duration(
      microseconds: (fullDuration.inMicroseconds * distance).round(),
    );
    if (duration == Duration.zero) {
      _controller.value = target;
      return;
    }
    if (widget.expanded) {
      _controller.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOutQuart,
      );
    } else {
      _controller.animateBack(
        target,
        duration: duration,
        curve: Curves.easeOutQuart,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocking = _isBlocking;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: blocking,
          child: ExcludeFocus(
            excluding: blocking,
            child: IgnorePointer(
              ignoring: blocking,
              child: Listener(
                key: _readingKey,
                onPointerDown: (event) => _readingPointers.add(event.pointer),
                onPointerUp: (event) => _readingPointers.remove(event.pointer),
                onPointerCancel: (event) =>
                    _readingPointers.remove(event.pointer),
                child: widget.child,
              ),
            ),
          ),
        ),
        if (blocking)
          Positioned.fill(
            top: widget.bannerBottom,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _QuickRecordBarrier(
                progress: _controller.value,
                onDismiss: widget.onDismiss,
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickRecordBarrier extends StatelessWidget {
  final double progress;
  final VoidCallback onDismiss;

  const _QuickRecordBarrier({required this.progress, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final scrimOpacity = (dark ? 0.12 : 0.08) * progress;
    final overlay = ColoredBox(
      color: highContrast
          ? theme.scaffoldBackgroundColor.withValues(alpha: progress)
          : theme.colorScheme.scrim.withValues(alpha: scrimOpacity),
    );
    return Semantics(
      label: '关闭记录菜单',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: ClipRect(
          child: highContrast
              ? overlay
              : BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 12 * progress,
                    sigmaY: 12 * progress,
                  ),
                  child: overlay,
                ),
        ),
      ),
    );
  }
}
