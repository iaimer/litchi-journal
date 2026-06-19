import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (splashAsset.isNotEmpty)
                SvgPicture.asset(splashAsset, width: 168, height: 168),
              const SizedBox(height: 28),
              Text(
                '荔枝日记',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '记录 · 成长 · 觉察',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 16,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
