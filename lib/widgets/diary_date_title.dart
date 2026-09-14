import 'dart:math' as math;

import 'package:flutter/material.dart';

class DiaryDateTitle extends StatelessWidget {
  final DateTime date;
  final bool showYear;

  const DiaryDateTitle({super.key, required this.date, this.showYear = false});

  static double preferredToolbarHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final titleHeight = scaler.scale(24) * 1.25;
    final metaHeight = scaler.scale(12) * 1.3;
    return math.max(84, titleHeight + metaHeight + 28);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final dateLabel = '${date.month}月${date.day}日';
    final metaLabel = showYear
        ? '${date.year}年 · 星期${weekdays[date.weekday - 1]}'
        : '星期${weekdays[date.weekday - 1]}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLabel,
          maxLines: 1,
          overflow: TextOverflow.fade,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          metaLabel,
          maxLines: 1,
          overflow: TextOverflow.fade,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
