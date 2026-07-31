import 'package:flutter/material.dart';

import '../services/api_client.dart';

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 0.5),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -120) _changeMonth(1);
          if (velocity > 120) _changeMonth(-1);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMonthHeader(theme),
            const SizedBox(height: 4),
            _buildWeekdays(theme),
            const SizedBox(height: 4),
            _buildDays(theme),
            if (loading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ] else if (markerLoadFailed) ...[
              const SizedBox(height: 8),
              Text('记录标记暂未加载，仍可选择日期', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
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
          icon: const Icon(Icons.chevron_left),
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
          icon: const Icon(Icons.chevron_right),
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

  Widget _buildDays(ThemeData theme) {
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
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 48,
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
      child: InkResponse(
        key: ValueKey('history_calendar_day_${ApiClient.formatDate(date)}'),
        radius: 24,
        onTap: selectable ? () => onDateSelected(date) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
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
