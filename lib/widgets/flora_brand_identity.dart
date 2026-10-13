import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'flora_icon.dart';

/// 按实际名称宽度约束品牌图，爱心与轨迹也包含在图形宽度内。
class FloraBrandIdentity extends StatelessWidget {
  const FloraBrandIdentity({
    super.key,
    required this.titleStyle,
    this.spacing = 20,
  });

  final TextStyle titleStyle;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(titleStyle);
    final painter = TextPainter(
      text: TextSpan(text: '荔枝日记', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final naturalWidth = painter.width;
    painter.dispose();

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidth = math.min(naturalWidth, constraints.maxWidth);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              FloraIcons.path(FloraIcons.brandIcon),
              key: const ValueKey('brand_identity_image'),
              width: titleWidth * 0.95,
              // 固定母版比例，解码完成前也预留位置，避免冷启动文字跳动。
              height: titleWidth * 0.95 * 373 / 517,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
            SizedBox(height: spacing),
            SizedBox(
              width: titleWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('荔枝日记', style: style),
              ),
            ),
          ],
        );
      },
    );
  }
}
