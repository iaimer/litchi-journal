import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'flora_icon.dart';

/// 缓存和连接错误共用单行提示，空间不足时只缩小文字。
class ReadingCacheStatus extends StatelessWidget {
  final String? message;

  const ReadingCacheStatus({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark
        ? AppColors.cacheNoticeDarkForeground
        : AppColors.cacheNoticeForeground;
    final label = message ?? '正在显示本地缓存';
    return Padding(
      padding: const EdgeInsets.only(bottom: FloraSpacing.md),
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: dark
                  ? AppColors.cacheNoticeDarkBackground
                  : AppColors.cacheNoticeBackground,
              borderRadius: BorderRadius.circular(FloraRadius.md),
            ),
            child: _buildContent(label, foreground),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(String label, Color foreground) {
    return Row(
      children: [
        FloraIcon(FloraIcons.calloutInfo, size: 18, color: foreground),
        const SizedBox(width: FloraSpacing.sm),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: foreground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
