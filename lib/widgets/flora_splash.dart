import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';
import 'flora_icon.dart';

/// Flora 品牌启动过渡页。
class FloraSplash extends StatefulWidget {
  const FloraSplash({
    super.key,
    required this.onDone,
    this.displayDuration = const Duration(milliseconds: 400),
    this.ready = true,
  });

  /// 展示完成后的回调。
  final VoidCallback onDone;

  /// 品牌页最短展示时长。
  final Duration displayDuration;

  /// 外部资源准备好后才允许结束过渡，避免落到第二个整页转圈。
  final bool ready;

  @override
  State<FloraSplash> createState() => _FloraSplashState();
}

class _FloraSplashState extends State<FloraSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  Timer? _minimumTimer;
  bool _minimumElapsed = false;
  bool _completionScheduled = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: FloraMotion.standard,
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _minimumElapsed = true;
      _completeIfReady();
      return;
    }

    _controller.forward();
    _minimumTimer = Timer(widget.displayDuration, () {
      if (!mounted) return;
      _minimumElapsed = true;
      _completeIfReady();
    });
  }

  void _completeIfReady() {
    if (_completed ||
        _completionScheduled ||
        !widget.ready ||
        !_minimumElapsed) {
      return;
    }
    _completionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _completed || !widget.ready) return;
      _completed = true;
      widget.onDone();
    });
    // Timer callbacks do not guarantee another frame; request one for the
    // post-frame completion callback so the splash cannot remain visible.
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  void didUpdateWidget(covariant FloraSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.ready && widget.ready) _completeIfReady();
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final splashAsset = isDark
        ? FloraIcons.path(FloraIcons.brandSplashDark)
        : FloraIcons.path(FloraIcons.brandSplash);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SizedBox.expand(
        child: FadeTransition(
          opacity: reducedMotion ? const AlwaysStoppedAnimation(1) : _fadeIn,
          child: Image.asset(splashAsset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
