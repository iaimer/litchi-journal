import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'flora_icon.dart';

/// 照片角标只占少量画面，点击区域独立保留 48dp。
class PhotoCornerButton extends StatelessWidget {
  final String icon;
  final String tooltip;
  final VoidCallback onPressed;

  const PhotoCornerButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
      style: IconButton.styleFrom(backgroundColor: Colors.transparent),
      icon: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(FloraSpacing.xs),
          child: SizedBox.square(
            dimension: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.darkBackground.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: FloraIcon(
                  icon,
                  size: 14,
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
