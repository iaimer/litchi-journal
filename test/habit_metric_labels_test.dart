import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/models/habit_stats.dart';
import 'package:litchi_journal_flutter/models/habit_trend.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/habit_trend_dashboard.dart';

HabitTrendItem metric(String key, HabitStatType type) => HabitTrendItem(
  key: key,
  displayName: key == 'custom' ? '自定义的较长习惯名称' : '饮水',
  icon: 'habit-water',
  color: Colors.blue,
  type: type,
  dailyTarget: null,
  days: const [],
  totalDurationMinutes: 78,
  longestStreak: 2,
);

void main() {
  for (final range in HabitTrendRange.values) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.3, 1.6, 2.0, 2.5, 3.0, 4.0]) {
        testWidgets(
          '$range dark=$dark scale=$scale labels do not crowd values',
          (tester) async {
            final semantics = tester.ensureSemantics();

            await tester.binding.setSurfaceSize(const Size(320, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    highContrast: scale == 4.0,
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: HabitTrendDashboard(
                      period: HabitTrendPeriod.forAnchor(
                        range,
                        DateTime(2026, 10, 28),
                      ),
                      items: [
                        metric('water', HabitStatType.numeric),
                        metric('custom', HabitStatType.duration),
                      ],
                    ),
                  ),
                ),
              ),
            );
            expect(find.text('最长连续'), findsOneWidget);
            expect(find.text('累计'), findsOneWidget);
            for (final key in ['water', 'custom']) {
              final card = find.byKey(ValueKey('habit_metric_$key'));
              final label = find.descendant(
                of: card,
                matching: find.text(key == 'water' ? '最长连续' : '累计'),
              );
              final value = find.descendant(
                of: card,
                matching: find.text(key == 'water' ? '2 天' : '1.3 小时'),
              );
              expect(
                tester.getRect(label).bottom,
                lessThanOrEqualTo(tester.getRect(value).top),
              );
              expect(
                tester.getRect(label).right,
                closeTo(tester.getRect(card).right - 10, 0.1),
              );
              expect(tester.widget<Text>(label).style!.fontSize, 11);
              expect(tester.widget<Text>(value).style!.fontSize, 24);
              expect(tester.widget<Text>(label).maxLines, 1);
              final expectedHeight = 18 + 17 * scale * 1.4 + 24 * scale;
              expect(
                tester.getSize(card).height,
                closeTo(expectedHeight < 82 ? 82 : expectedHeight, 0.1),
              );
              expect(tester.widget<Text>(value).maxLines, 1);
              expect(
                tester.getSemantics(card).label,
                contains(key == 'water' ? '最长连续 2 天' : '累计 1.3 小时'),
              );
            }
            expect(tester.takeException(), isNull);
            semantics.dispose();
          },
        );
      }
    }
  }
}
