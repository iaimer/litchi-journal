import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'flora_primary_header.dart';

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

/// 今天页的日期以同行元信息呈现，历史详情继续使用 [DiaryDateTitle]。
class CompactDiaryDateTitle extends StatelessWidget {
  final DateTime date;

  const CompactDiaryDateTitle({super.key, required this.date});

  static double preferredToolbarHeight(BuildContext context, DateTime date) {
    final titleHeight = _dateTextHeight(context, date);
    final metaHeight = _weekdayTextHeight(context);
    return math.max(
      FloraPrimaryHeader.contentHeight,
      _shouldWrapWeekday(context, date)
          ? titleHeight + metaHeight + 18
          : math.max(titleHeight, metaHeight) + 16,
    );
  }

  static bool _shouldWrapWeekday(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final dateWidth = _measureText(
      '${date.month}月${date.day}日',
      theme.textTheme.headlineLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      scaler,
      textDirection,
    ).width;
    final weekdayWidth = _measureText(
      '星期日',
      theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      scaler,
      textDirection,
    ).width;
    // AppBar 标题要避开默认的左侧间距和右侧操作槽位。
    final availableWidth = math.max(0, MediaQuery.sizeOf(context).width - 88);
    return dateWidth + 12 + weekdayWidth > availableWidth;
  }

  static double _dateTextHeight(BuildContext context, DateTime date) =>
      _measureText(
        '${date.month}月${date.day}日',
        Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        MediaQuery.textScalerOf(context),
        Directionality.of(context),
      ).height;

  static double _weekdayTextHeight(BuildContext context) => _measureText(
    '星期日',
    Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, height: 1.3),
    MediaQuery.textScalerOf(context),
    Directionality.of(context),
  ).height;

  static Size _measureText(
    String text,
    TextStyle? style,
    TextScaler scaler,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: textDirection,
    )..layout();
    return painter.size;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final dateLabel = '${date.month}月${date.day}日';
    final weekdayLabel = '星期${weekdays[date.weekday - 1]}';
    final dateStyle = theme.textTheme.headlineLarge?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    final weekdayStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final dateText = Text(dateLabel, maxLines: 1, style: dateStyle);
    final weekdayText = Text(weekdayLabel, maxLines: 1, style: weekdayStyle);

    if (_shouldWrapWeekday(context, date)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [dateText, const SizedBox(height: 2), weekdayText],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [dateText, const SizedBox(width: 12), weekdayText],
    );
  }
}
