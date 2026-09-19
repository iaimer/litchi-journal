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
    return Semantics(
      label: '正在加载',
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withAlpha(150),
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
