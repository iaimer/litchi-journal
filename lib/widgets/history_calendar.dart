import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'flora_icon.dart';
import 'flora_origin.dart';

class HistoryCalendar extends StatelessWidget {
  final DateTime displayedMonth;
  final Set<String> recordedDateKeys;
  final bool loading;
  final bool markerLoadFailed;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime today;

  const HistoryCalendar({
    super.key,
    required this.displayedMonth,
    required this.recordedDateKeys,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.today,
    this.loading = false,
    this.markerLoadFailed = false,
  });

  DateTime get _normalizedToday => DateTime(today.year, today.month, today.day);

  void _changeMonth(int offset) {
    final next = DateTime(displayedMonth.year, displayedMonth.month + offset);
    if (next.isAfter(DateTime(today.year, today.month))) return;
    onMonthChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('history_calendar'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(FloraRadius.lg),
        border: Border.all(color: theme.dividerColor, width: 0.5),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -120) _changeMonth(1);
          if (velocity > 120) _changeMonth(-1);
        },
        child: _buildCalendarBody(context, theme),
      ),
    );
  }

  Widget _buildCalendarBody(BuildContext context, ThemeData theme) {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMonthHeader(theme),
            const SizedBox(height: 4),
            _buildDateGrid(context, theme),
            if (!loading && markerLoadFailed) ...[
              const SizedBox(height: 8),
              Text('记录标记暂未加载，仍可选择日期', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        // 利用日期格底部留白显示进度，不增减弹窗高度。
        if (loading)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(child: LinearProgressIndicator(minHeight: 2)),
          ),
      ],
    );
  }

  Widget _buildMonthHeader(ThemeData theme) {
    final currentMonth = DateTime(today.year, today.month);
    final canGoNext = displayedMonth.isBefore(currentMonth);
    return Row(
      children: [
        IconButton(
          key: const Key('history_calendar_previous_month'),
          tooltip: '上个月',
          onPressed: () => _changeMonth(-1),
          icon: const FloraIcon(FloraIcons.chevronLeft),
        ),
        Expanded(
          child: Text(
            '${displayedMonth.year}年${displayedMonth.month}月',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        IconButton(
          key: const Key('history_calendar_next_month'),
          tooltip: '下个月',
          onPressed: canGoNext ? () => _changeMonth(1) : null,
          icon: const FloraIcon(FloraIcons.chevronRight),
        ),
      ],
    );
  }

  Widget _buildWeekdays(ThemeData theme) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: [
        for (final weekday in weekdays)
          Expanded(
            child: Center(
              child: Text(weekday, style: theme.textTheme.bodySmall),
            ),
          ),
      ],
    );
  }

  Widget _buildDateGrid(BuildContext context, ThemeData theme) {
    final dayStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: MediaQuery.boldTextOf(context)
          ? FontWeight.w700
          : FontWeight.w500,
    );
    final dayText = TextPainter(
      text: TextSpan(text: '30', style: dayStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final rowHeight = math.max(48.0, dayText.height + 15);
    final minWidth = (dayText.width + 8) * 7;
    dayText.dispose();
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SizedBox(
          width: math.max(constraints.maxWidth, minWidth),
          child: Column(
            children: [
              _buildWeekdays(theme),
              const SizedBox(height: 4),
              _buildDays(theme, rowHeight),
            ],
          ),
        );
        if (minWidth <= constraints.maxWidth) return content;
        // 极大字体下保留完整日期，横向滚动承接七列所需宽度。
        return SingleChildScrollView(
          key: const Key('history_calendar_grid_scroll'),
          scrollDirection: Axis.horizontal,
          primary: false,
          child: content,
        );
      },
    );
  }

  Widget _buildDays(ThemeData theme, double rowHeight) {
    final firstDay = DateTime(displayedMonth.year, displayedMonth.month);
    final leading = firstDay.weekday - 1;
    final daysInMonth = DateTime(
      displayedMonth.year,
      displayedMonth.month + 1,
      0,
    ).day;
    final cellCount = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: rowHeight,
      ),
      itemCount: cellCount,
      itemBuilder: (context, index) {
        final day = index - leading + 1;
        if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
        return _buildDay(
          theme,
          DateTime(displayedMonth.year, displayedMonth.month, day),
        );
      },
    );
  }

  Widget _buildDay(ThemeData theme, DateTime date) {
    final selectable = date.isBefore(_normalizedToday);
    final hasRecord = recordedDateKeys.contains(ApiClient.formatDate(date));
    return Semantics(
      label:
          '${date.month}月${date.day}日${hasRecord ? '，有记录' : ''}${selectable ? '' : '，不可选择'}',
      button: selectable,
      child: FloraInkWell(
        key: ValueKey('history_calendar_day_${ApiClient.formatDate(date)}'),
        customBorder: const CircleBorder(),
        onTap: selectable ? () => onDateSelected(date) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selectable
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withAlpha(80),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 5,
              height: 5,
              child: hasRecord
                  ? DecoratedBox(
                      key: ValueKey(
                        'history_calendar_marker_${ApiClient.formatDate(date)}',
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
