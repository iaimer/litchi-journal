import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 静态内容形状占位，不使用闪烁或 shimmer 动画。
class FloraSkeletonBox extends StatelessWidget {
  const FloraSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = FloraRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withAlpha(150),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// 一组静态占位共用一个加载语义，避免读屏重复播报。
class FloraSkeletonRegion extends StatelessWidget {
  const FloraSkeletonRegion({
    super.key,
    required this.child,
    this.label = '正在加载',
  });

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }
}
