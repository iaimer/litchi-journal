import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'flora_icon.dart';

/// Flora 品牌空状态组件。
///
/// 使用品牌线稿 SVG 插图 + 场景化文案，替代通用占位文字。
///
/// ```dart
/// FloraEmpty(name: FloraIcons.emptyPast)
/// ```
class FloraEmpty extends StatelessWidget {
  const FloraEmpty({
    super.key,
    required this.name,
    this.size = 80,
  });

  /// 空状态 SVG 名称（FloraIcons.emptyPast / emptyTags / emptyHabits / emptySearch）。
  final String name;

  /// SVG 插画尺寸。默认 80dp。
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetPath = FloraIcons.path(name);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (assetPath.isNotEmpty)
            SvgPicture.asset(
              assetPath,
              width: size,
              height: size,
              colorFilter: ColorFilter.mode(
                theme.colorScheme.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
          const SizedBox(height: 20),
          Text(
            _headline(name),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _subtext(name),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static String _headline(String name) {
    switch (name) {
      case FloraIcons.emptyPast:
        return '还没有旧时光';
      case FloraIcons.emptyTags:
        return '还没有标签';
      case FloraIcons.emptyHabits:
        return '还没有习惯';
      case FloraIcons.emptySearch:
        return '没有找到相关记录';
      default:
        return '还没有内容';
    }
  }

  static String _subtext(String name) {
    switch (name) {
      case FloraIcons.emptyPast:
        return '今天写下第一条记录吧';
      case FloraIcons.emptyTags:
        return '成长会慢慢长出自己的名字';
      case FloraIcons.emptyHabits:
        return '从最小的一步开始';
      case FloraIcons.emptySearch:
        return '换个关键词试试看';
      default:
        return '';
    }
  }
}
