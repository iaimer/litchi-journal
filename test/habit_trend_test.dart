import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:litchi_journal_flutter/models/habit_settings.dart';
import 'package:litchi_journal_flutter/models/habit_stats.dart';
import 'package:litchi_journal_flutter/models/habit_trend.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/habit_settings_repository.dart';
import 'package:litchi_journal_flutter/services/habit_trend_cache_repository.dart';
import 'package:litchi_journal_flutter/services/habit_trend_service.dart';
import 'package:litchi_journal_flutter/screens/habit_stats_screen.dart';
import 'package:litchi_journal_flutter/screens/habit_dashboard_settings_screen.dart';
import 'package:litchi_journal_flutter/widgets/habit_trend_dashboard.dart';
import 'package:litchi_journal_flutter/widgets/habit_trend_heatmap.dart';

void main() {
  group('HabitTrendPeriod', () {
    test('creates stable week, month, and year boundaries', () {
      final anchor = DateTime(2026, 9, 10);
      final week = HabitTrendPeriod.forAnchor(HabitTrendRange.week, anchor);
      final month = HabitTrendPeriod.forAnchor(HabitTrendRange.month, anchor);
      final year = HabitTrendPeriod.forAnchor(HabitTrendRange.year, anchor);

      expect(week.start, DateTime(2026, 9, 7));
      expect(week.end, DateTime(2026, 9, 13));
      expect(month.start, DateTime(2026, 9, 1));
      expect(month.end, DateTime(2026, 9, 30));
      expect(year.start, DateTime(2026, 1, 1));
      expect(year.end, DateTime(2026, 12, 31));
      expect(month.dayCount, 30);
      expect(year.dayCount, 365);
      expect(month.shift(-1).start, DateTime(2026, 8, 1));
      expect(month.canMoveForward(DateTime(2026, 9, 10)), isFalse);
    });

    test('freezes the reference date used by boundaries and cache keys', () {
      final referenceDate = DateTime(2026, 9, 10);
      final period = HabitTrendPeriod.forAnchor(
        HabitTrendRange.year,
        referenceDate,
        referenceDate: referenceDate,
      );
      final nextDay = HabitTrendPeriod.forAnchor(
        HabitTrendRange.year,
        referenceDate.add(const Duration(days: 1)),
        referenceDate: referenceDate.add(const Duration(days: 1)),
      );

      expect(period.asOfDate, referenceDate);
      expect(period.metricEnd, referenceDate);
      expect(period.fetchEnd, referenceDate);
      expect(period.cacheKey, isNot(nextDay.cacheKey));
      expect(
        HabitTrendPeriod.fromJson(period.toJson()).cacheKey,
        period.cacheKey,
      );
    });
  });

  group('HabitSettings dashboard selection', () {
    test('resolves selected habits first and fills the dashboard to four', () {
      const settings = HabitSettings(
        statusMap: {
          'water': true,
          'steps': true,
          'reading': true,
          'language': true,
          'supplements': true,
          'custom_archived': false,
        },
        extraHabits: {'custom_archived': '旧习惯'},
        trendDashboardHabitKeys: ['supplements', 'language', 'supplements'],
      );

      expect(settings.validTrendDashboardHabitKeys, [
        'supplements',
        'language',
      ]);
      expect(settings.resolvedTrendDashboardHabitKeys, [
        'supplements',
        'language',
        'water',
        'steps',
      ]);
    });

    test('migrates and sanitizes trend dashboard preferences', () {
      final migrated = HabitSettings.fromJson(const {
        'schemaVersion': 7,
        'statusMap': {'water': true},
      });
      expect(migrated.trendDashboardHabitKeys, isEmpty);

      final restored = HabitSettings.fromJson(const {
        'schemaVersion': 8,
        'statusMap': {
          'water': true,
          'steps': true,
          'reading': true,
          'language': true,
          'supplements': true,
        },
        'trendDashboardHabitKeys': [
          'language',
          'language',
          'missing',
          'reading',
          'steps',
          'supplements',
        ],
      });
      expect(restored.validTrendDashboardHabitKeys, [
        'language',
        'reading',
        'steps',
        'supplements',
      ]);
      expect(restored.toJson()['schemaVersion'], 8);
    });

    testWidgets('dashboard selection screen persists selected habits', (
      tester,
    ) async {
      final storage = _MemorySettingsStorage();
      final repo = HabitSettingsRepository(storage: storage);
      await tester.pumpWidget(
        MaterialApp(home: HabitDashboardSettingsScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('仪表盘显示'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(5));

      await tester.tap(find.text('补充剂'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final saved = jsonDecode(storage.values['habit_settings']!);
      expect(saved['trendDashboardHabitKeys'], ['supplements']);
    });

    testWidgets(
      'saving dashboard preferences preserves selected archived keys',
      (tester) async {
        final storage = _MemorySettingsStorage();
        const settings = HabitSettings(
          statusMap: {'custom_archived': false},
          extraHabits: {'custom_archived': '旧习惯'},
          trendDashboardHabitKeys: ['custom_archived'],
        );
        storage.values['habit_settings'] = jsonEncode(settings.toJson());
        await tester.pumpWidget(
          MaterialApp(
            home: HabitDashboardSettingsScreen(
              repository: HabitSettingsRepository(storage: storage),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        final saved = jsonDecode(storage.values['habit_settings']!);
        expect(saved['trendDashboardHabitKeys'], ['custom_archived']);
      },
    );
  });

  group('HabitTrendService', () {
    test('aggregates duration, streak, and legacy checkbox semantics', () {
      final today = _today;
      final period = HabitTrendPeriod.forAnchor(HabitTrendRange.month, today);
      final service = HabitTrendService(_unusedApiClient());
      final settings = HabitSettings.defaults;
      final days = [
        _day(today.subtract(const Duration(days: 2)), readingMinutes: 30),
        _day(today.subtract(const Duration(days: 1)), readingMinutes: 90),
        _day(today, readingMinutes: null, readingDone: true),
      ];

      final stats = service.build(
        period: period,
        sourceDays: days,
        settings: settings,
      );
      final reading = stats.items.firstWhere((item) => item.key == 'reading');
      final water = stats.items.firstWhere((item) => item.key == 'water');

      expect(reading.totalDurationMinutes, 120);
      expect(reading.longestStreak, 3);
      expect(reading.days[2].known, isFalse);
      expect(reading.days[2].completed, isTrue);
      expect(water.longestStreak, 0);
    });

    test(
      'uses the period reference date for future days and annual totals',
      () {
        final referenceDate = DateTime(2026, 9, 10);
        final period = HabitTrendPeriod.forAnchor(
          HabitTrendRange.year,
          referenceDate,
          referenceDate: referenceDate,
        );
        final stats = HabitTrendService(_unusedApiClient()).build(
          period: period,
          sourceDays: [
            _day(DateTime(2026, 1, 1), readingMinutes: 60),
            _day(referenceDate, readingMinutes: 30),
            _day(
              referenceDate.add(const Duration(days: 1)),
              readingMinutes: 90,
            ),
          ],
          settings: HabitSettings.defaults,
        );
        final reading = stats.items.firstWhere((item) => item.key == 'reading');

        expect(reading.totalDurationMinutes, 90);
        expect(reading.days.last.future, isTrue);
      },
    );

    test('maps custom names and aliases to the registered habit key', () {
      const customKey = 'custom_stretch';
      final settings = const HabitSettings(
        statusMap: {customKey: true},
        extraHabits: {customKey: '拉伸'},
        customHabitAliases: {
          customKey: ['拉伸', '伸展'],
        },
        trackingTypeMap: {customKey: HabitTrackingType.duration},
      );
      final service = HabitTrendService(_unusedApiClient());
      final today = _today;
      final stats = service.build(
        period: HabitTrendPeriod.forAnchor(HabitTrendRange.week, today),
        sourceDays: [
          HabitDayRecord(
            date: today,
            weekday: '',
            hasDiary: true,
            waterMl: 0,
            steps: 0,
            readingDone: false,
            languageDone: false,
            supplementDone: false,
            customDurationMinutes: {'伸展': 25},
          ),
        ],
        settings: settings,
      );
      final custom = stats.items.single;

      expect(custom.key, customKey);
      expect(custom.totalDurationMinutes, 25);
      expect(custom.days.single.value, 25);
      expect(custom.days.single.completed, isTrue);
    });

    test('includes custom aliases in the cache settings signature', () {
      final service = HabitTrendService(_unusedApiClient());
      const base = HabitSettings(
        statusMap: {'custom_reading': true},
        extraHabits: {'custom_reading': '共读'},
        customHabitAliases: {
          'custom_reading': ['共读'],
        },
      );
      const renamed = HabitSettings(
        statusMap: {'custom_reading': true},
        extraHabits: {'custom_reading': '共读'},
        customHabitAliases: {
          'custom_reading': ['亲子时间', '共读'],
        },
      );

      expect(
        service.settingsSignature(base),
        isNot(service.settingsSignature(renamed)),
      );
    });

    test(
      'maps server snapshot fields and excludes future days from totals',
      () async {
        final today = _today;
        final client = _TrendHttpClient([
          {
            'date': ApiClient.formatDate(today),
            'hasDiary': true,
            'water': 1500,
            'steps': 6000,
            'reading': true,
            'language': false,
            'supplements': false,
            'readingMinutes': 60,
            'languageMinutes': null,
            'customCheckboxes': {},
            'customDurations': {},
          },
        ]);
        final service = HabitTrendService(
          ApiClient(
            ApiConfig(baseUrl: 'https://test.local', token: 'test'),
            httpClient: client,
          ),
        );
        final period = HabitTrendPeriod.forAnchor(HabitTrendRange.week, today);
        final stats = await service.load(
          period: period,
          settings: HabitSettings.defaults,
        );
        final water = stats.items.firstWhere((item) => item.key == 'water');
        final reading = stats.items.firstWhere((item) => item.key == 'reading');
        final waterToday = water.days.firstWhere((day) => day.date == today);
        final readingToday = reading.days.firstWhere(
          (day) => day.date == today,
        );

        expect(client.requestCount, 1);
        expect(water.days, hasLength(7));
        expect(waterToday.value, 1500);
        expect(waterToday.completed, isTrue);
        expect(reading.totalDurationMinutes, 60);
        expect(readingToday.known, isTrue);
      },
    );
  });

  group('HabitTrend formatting and cache', () {
    test('uses compact Chinese duration and streak units', () {
      expect(formatDurationMinutes(0), '0.0 小时');
      expect(formatDurationMinutes(1), '<0.1 小时');
      expect(formatDurationMinutes(2), '<0.1 小时');
      expect(formatDurationMinutes(3), '0.1 小时');
      expect(formatDurationMinutes(15), '0.3 小时');
      expect(formatDurationMinutes(59), '1.0 小时');
      expect(formatDurationMinutes(60), '1.0 小时');
      expect(formatDurationMinutes(90), '1.5 小时');
      expect(formatDurationMinutes(119), '2.0 小时');
      expect(formatDurationMinutes(120), '2.0 小时');
      expect('${0} 天', '0 天');
      expect('${12} 天', '12 天');
    });

    testWidgets('dashboard shows at most four full-width metrics', (
      tester,
    ) async {
      final threeItems = [
        _metricItem('water', '饮水'),
        _metricItem('steps', '运动'),
        _metricItem('reading', '阅读'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: HabitTrendDashboard(
                period: _monthPeriod,
                items: threeItems,
              ),
            ),
          ),
        ),
      );

      final firstWidth = tester
          .getSize(find.byKey(const ValueKey('habit_metric_water')))
          .width;
      final lastWidth = tester
          .getSize(find.byKey(const ValueKey('habit_metric_reading')))
          .width;
      expect(lastWidth, closeTo(firstWidth, 0.1));
      expect(find.byType(Scrollable), findsNothing);

      final fiveItems = [
        ...threeItems,
        _metricItem('language', '学语言'),
        _metricItem('supplements', '补充剂'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: HabitTrendDashboard(
                period: _monthPeriod,
                items: fiveItems,
              ),
            ),
          ),
        ),
      );

      final fifthFinder = find.byKey(
        const ValueKey('habit_metric_supplements'),
      );
      expect(fifthFinder, findsNothing);
      expect(find.byType(Scrollable), findsNothing);
      final firstRect = tester.getRect(
        find.byKey(const ValueKey('habit_metric_water')),
      );
      final fourthRect = tester.getRect(
        find.byKey(const ValueKey('habit_metric_language')),
      );
      expect(firstRect.left, closeTo(0, 0.1));
      expect(fourthRect.right, closeTo(320, 0.1));
      expect(fourthRect.top, greaterThan(firstRect.top));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: HabitTrendDashboard(
                period: _monthPeriod,
                items: [
                  _metricItem('water', '饮水'),
                  _metricItem('steps', '运动'),
                  _metricItem('reading', '亲子共读'),
                  _metricItem('language', '学语言'),
                ],
              ),
            ),
          ),
        ),
      );
      final habitName = find.text('亲子共读');
      expect(habitName, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(habitName).didExceedMaxLines,
        isFalse,
      );
    });

    testWidgets('dashboard grows with large system text without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: HabitTrendDashboard(
                period: _monthPeriod,
                items: [
                  _metricItem('water', '饮水'),
                  _metricItem('steps', '运动'),
                  _metricItem('reading', '亲子共读'),
                  _metricItem('language', '学语言'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const ValueKey('habit_metric_water'))).height,
        greaterThan(82),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('year heatmap uses the denser square grid without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: HabitTrendHeatmapList(
                period: HabitTrendPeriod.forAnchor(
                  HabitTrendRange.year,
                  DateTime(2026, 9, 10),
                ),
                items: [_metricItem('water', '饮水', numeric: true)],
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .getSize(find.byKey(const ValueKey('habit_heatmap_water')))
            .height,
        lessThan(100),
      );
      expect(
        find.byKey(const ValueKey('habit_heatmap_year_weekday_labels')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    test('year heatmap date grid uses 26 weeks and seven weekdays', () {
      for (final year in [2026, 2024]) {
        final period = HabitTrendPeriod.forAnchor(
          HabitTrendRange.year,
          DateTime(year, 9, 10),
        );
        final grid = buildHabitTrendYearDateGrid(period);
        final dates = grid.expand((row) => row).whereType<DateTime>().toList();

        expect(grid, hasLength(7));
        expect(grid.every((row) => row.length == 26), isTrue);
        expect(dates, hasLength(26 * 7));
        expect(dates.toSet(), hasLength(26 * 7));
        expect(grid.first.first, period.heatmapStart);
        expect(grid.last.last, period.heatmapEnd);
        for (final row in grid) {
          for (var column = 1; column < row.length; column++) {
            expect(row[column]!.difference(row[column - 1]!).inDays, 7);
          }
        }
        for (var row = 1; row < grid.length; row++) {
          expect(grid[row].first!.difference(grid[row - 1].first!).inDays, 1);
        }
      }
    });

    testWidgets('week and month heatmaps show weekday headers and gray slots', (
      tester,
    ) async {
      final week = HabitTrendPeriod.forAnchor(
        HabitTrendRange.week,
        DateTime(2026, 9, 10),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: HabitTrendHeatmapList(
                period: week,
                items: [_metricItem('water', '饮水', numeric: true)],
              ),
            ),
          ),
        ),
      );

      for (final label in ['一', '二', '三', '四', '五', '六', '日']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        tester
            .getSize(find.byKey(const ValueKey('habit_heatmap_water')))
            .height,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);

      final month = HabitTrendPeriod.forAnchor(
        HabitTrendRange.month,
        DateTime(2026, 9, 10),
        referenceDate: DateTime(2026, 9, 10),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: HabitTrendHeatmapList(
                period: month,
                items: [_metricItem('water', '饮水', numeric: true)],
              ),
            ),
          ),
        ),
      );

      final monthGrid = buildHabitTrendMonthDateGrid(month);
      expect(monthGrid, hasLength(6));
      expect(monthGrid.every((row) => row.length == 7), isTrue);
      expect(monthGrid.first.first, isNull);
      expect(monthGrid.first[1], DateTime(2026, 9, 1));
      expect(
        monthGrid.expand((row) => row).where((date) => date == null),
        isNotEmpty,
      );
      expect(
        habitTrendPlaceholderColor(ThemeData.light()),
        ThemeData.light().dividerColor.withAlpha(52),
      );
      expect(tester.takeException(), isNull);
    });

    test('cache only returns the matching period', () async {
      final storage = _MemoryTrendStorage();
      final repo = HabitTrendCacheRepository(storage: storage);
      final period = HabitTrendPeriod.forAnchor(
        HabitTrendRange.month,
        DateTime(2026, 9, 10),
      );
      final stats = HabitTrendStats(
        period: period,
        sourceDays: const [],
        items: const [],
        settingsSignature: 'test',
        cachedAt: DateTime(2026, 9, 10),
      );

      await repo.save(stats);
      expect((await repo.load(period))?.settingsSignature, 'test');
      expect(await repo.load(period.shift(-1)), isNull);
    });

    test('keeps separate cache entries for separate periods', () async {
      final storage = _MemoryTrendStorage();
      final repo = HabitTrendCacheRepository(storage: storage);
      final month = HabitTrendPeriod.forAnchor(
        HabitTrendRange.month,
        DateTime(2026, 9, 10),
      );
      final previousMonth = month.shift(-1);

      await repo.save(
        HabitTrendStats(
          period: month,
          sourceDays: const [],
          items: const [],
          settingsSignature: 'current',
        ),
      );
      await repo.save(
        HabitTrendStats(
          period: previousMonth,
          sourceDays: const [],
          items: const [],
          settingsSignature: 'previous',
        ),
      );

      expect((await repo.load(month))?.settingsSignature, 'current');
      expect((await repo.load(previousMonth))?.settingsSignature, 'previous');
    });

    test('isolates cache entries by API namespace', () async {
      final storage = _MemoryTrendStorage();
      final firstRepo = HabitTrendCacheRepository(
        storage: storage,
        namespace: 'https://first.test',
      );
      final secondRepo = HabitTrendCacheRepository(
        storage: storage,
        namespace: 'https://second.test',
      );
      final period = HabitTrendPeriod.forAnchor(
        HabitTrendRange.month,
        DateTime(2026, 9, 10),
      );
      await firstRepo.save(
        HabitTrendStats(
          period: period,
          sourceDays: const [],
          items: const [],
          settingsSignature: 'first',
        ),
      );

      expect((await firstRepo.load(period))?.settingsSignature, 'first');
      expect(await secondRepo.load(period), isNull);
    });
  });

  test('legacy completed duration uses the completed heatmap color', () {
    const color = Color(0xFF51CF66);
    final item = HabitTrendItem(
      key: 'reading',
      displayName: '亲子共读',
      icon: 'habit-reading',
      color: color,
      type: HabitStatType.duration,
      dailyTarget: 30,
      days: const [],
      totalDurationMinutes: 0,
      longestStreak: 1,
    );
    final day = HabitTrendDay(
      date: DateTime(2026, 9, 10),
      value: 0,
      completed: true,
      known: false,
      hasDiary: true,
      future: false,
    );

    expect(
      resolveHabitTrendDayColor(item: item, day: day, theme: ThemeData.light()),
      color,
    );
  });

  test('only exact built-in labels map to built-in habit keys', () {
    expect(HabitItem.keyForLabel('运动/拉伸/快走'), 'steps');
    expect(HabitItem.keyForLabel('🇬🇧 学语言'), 'language');
    expect(HabitItem.keyForLabel('💡 学语言'), 'language');
    expect(HabitItem.keyForLabel('📝 运动拉伸'), isNull);
    expect(HabitItem.keyForLabel('📝 每天学语言'), isNull);
    expect(HabitItem.keyForLabel('📝 饮水 500 mL'), isNull);
  });

  testWidgets(
    'renders a compact dashboard and remains stable on a narrow screen',
    (tester) async {
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _TrendHttpClient(const []),
      );
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(
              storage: _MemorySettingsStorage(),
            ),
            trendCacheRepo: HabitTrendCacheRepository(
              storage: _MemoryTrendStorage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('习惯趋势'), findsOneWidget);
      expect(find.text('饮水'), findsWidgets);
      expect(find.textContaining('完成率'), findsNothing);
      expect(find.textContaining('最长连续'), findsNothing);
    },
  );

  testWidgets('rebinds trend loading when the API client changes', (
    tester,
  ) async {
    final today = _today;
    final firstHttp = _TrendHttpClient([_trendRow(today, readingMinutes: 30)]);
    final secondHttp = _TrendHttpClient([_trendRow(today, readingMinutes: 90)]);
    final settingsRepo = HabitSettingsRepository(
      storage: _MemorySettingsStorage(),
    );
    final cacheRepo = HabitTrendCacheRepository(storage: _MemoryTrendStorage());

    await tester.pumpWidget(
      MaterialApp(
        home: HabitStatsScreen(
          apiClient: ApiClient(
            ApiConfig(baseUrl: 'https://first.test', token: 'test'),
            httpClient: firstHttp,
          ),
          habitSettingsRepo: settingsRepo,
          trendCacheRepo: cacheRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0.5 小时'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: HabitStatsScreen(
          apiClient: ApiClient(
            ApiConfig(baseUrl: 'https://second.test', token: 'test'),
            httpClient: secondHttp,
          ),
          habitSettingsRepo: settingsRepo,
          trendCacheRepo: cacheRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(firstHttp.requestCount, 1);
    expect(secondHttp.requestCount, 1);
    expect(find.text('1.5 小时'), findsOneWidget);
  });
}

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

HabitTrendPeriod get _monthPeriod =>
    HabitTrendPeriod.forAnchor(HabitTrendRange.month, _today);

HabitTrendItem _metricItem(String key, String name, {bool numeric = false}) {
  return HabitTrendItem(
    key: key,
    displayName: name,
    icon: 'check',
    color: const Color(0xFF51CF66),
    type: numeric ? HabitStatType.numeric : HabitStatType.boolean,
    dailyTarget: numeric ? 1500 : null,
    days: const [],
    totalDurationMinutes: 0,
    longestStreak: 0,
  );
}

HabitDayRecord _day(
  DateTime date, {
  int? readingMinutes,
  bool readingDone = false,
}) {
  return HabitDayRecord(
    date: date,
    weekday: '',
    hasDiary: true,
    waterMl: 0,
    steps: 0,
    readingDone: readingDone,
    languageDone: false,
    supplementDone: false,
    readingMinutes: readingMinutes,
  );
}

Map<String, dynamic> _trendRow(DateTime date, {required int readingMinutes}) {
  return {
    'date': ApiClient.formatDate(date),
    'hasDiary': true,
    'water': 0,
    'steps': 0,
    'reading': true,
    'language': false,
    'supplements': false,
    'readingMinutes': readingMinutes,
    'languageMinutes': null,
    'customCheckboxes': {},
    'customDurations': {},
  };
}

ApiClient _unusedApiClient() => ApiClient(
  ApiConfig(baseUrl: 'https://test.local', token: 'test'),
  httpClient: _TrendHttpClient(const []),
);

class _TrendHttpClient extends http.BaseClient {
  final List<Map<String, dynamic>> rows;
  int requestCount = 0;

  _TrendHttpClient(this.rows);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(rows))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _MemoryTrendStorage implements HabitTrendCacheStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _MemorySettingsStorage implements HabitSettingsStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
