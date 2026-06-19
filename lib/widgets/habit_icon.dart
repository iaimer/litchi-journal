import 'package:flutter/material.dart';

import 'flora_icon.dart';

/// 习惯图标渲染器。
///
/// 新配置使用 FloraIcons 的逻辑名称；旧配置里保存过的 emoji 继续按文本显示。
class HabitIcon extends StatelessWidget {
  final String icon;
  final double size;
  final Color? color;

  const HabitIcon(this.icon, {super.key, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) {
    if (FloraIcons.hasAsset(icon)) {
      return FloraIcon(icon, size: size, color: color);
    }
    return Text(icon, style: TextStyle(fontSize: size));
  }
}
