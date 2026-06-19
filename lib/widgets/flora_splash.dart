import 'package:flutter/material.dart';

import 'flora_icon.dart';

/// Flora 品牌启动过渡页。
class FloraSplash extends StatefulWidget {
  const FloraSplash({
    super.key,
    required this.onDone,
    this.displayDuration = const Duration(milliseconds: 1400),
  });

  /// 展示完成后的回调。
  final VoidCallback onDone;

  /// 品牌页最短展示时长。
  final Duration displayDuration;

  @override
  State<FloraSplash> createState() => _FloraSplashState();
}

class _FloraSplashState extends State<FloraSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    Future.delayed(widget.displayDuration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SizedBox.expand(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Image.asset(splashAsset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
