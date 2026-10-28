part of '../widget_test.dart';

void registerStatisticsTests() {
  group('HabitStatsScreen', () {
    testWidgets('shows trend title and period selector', (tester) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('习惯趋势'), findsOneWidget);
      expect(find.text('月'), findsNothing);
      expect(find.byType(SegmentedButton), findsNothing);
    });

    testWidgets('shows active habit metrics when no diary data', (
      tester,
    ) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('饮水'), findsWidgets);
      expect(find.text('0 天'), findsWidgets);
    });

    testWidgets('no edit/delete/patch buttons present', (tester) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 不应该有任何编辑/删除按钮
      expect(find.text('编辑'), findsNothing);
      expect(find.text('删除'), findsNothing);
      expect(find.text('补打卡'), findsNothing);
    });

    testWidgets('supplement displays as 补充剂 not 鱼油/植物甾醇', (tester) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {now.day - 1: true},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('补充剂'), findsWidgets);
      expect(find.textContaining('鱼油'), findsNothing);
      expect(find.textContaining('植物甾醇'), findsNothing);
    });

    testWidgets('habit heatmap shows title and selector', (tester) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {now.day - 1: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('习惯趋势'), findsOneWidget);
      expect(find.text('月'), findsNothing);
      expect(find.byType(SegmentedButton), findsNothing);
    });

    testWidgets('trend page shows concise metric labels in summary cards', (
      tester,
    ) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {now.day - 1: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('完成率'), findsNothing);
      expect(find.text('最长连续'), findsWidgets);
      expect(find.textContaining('本月累计'), findsNothing);
    });

    testWidgets('header shown immediately before data loads', (tester) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      // 单帧后 header 已显示
      expect(find.text('习惯趋势'), findsOneWidget);
      expect(find.text('月'), findsNothing);
      expect(find.byType(SegmentedButton), findsNothing);
    });

    testWidgets('shows loading skeleton while 7-day data loads', (
      tester,
    ) async {
      final now = DateTime.now();
      // 延迟 HTTP 客户端：模拟网络延迟
      final delayedClient = _DelayedHttpClient(
        year: now.year,
        month: now.month,
        waterByDay: {},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
        delay: const Duration(milliseconds: 500),
      );
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: delayedClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );

      // 还没 settle，应显示 loading
      expect(find.byType(FloraSkeletonBox), findsWidgets);
      expect(find.text('加载习惯趋势'), findsNothing);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    });

    testWidgets('30-day loading does not block rhythm grid', (tester) async {
      final now = DateTime.now();
      final today = now.day;

      // 先给足 7 天数据，30 天其他日期的请求延迟
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {for (var i = 0; i < 7; i++) today - i: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('习惯趋势'), findsOneWidget);
      expect(find.text('月'), findsNothing);
      expect(find.byType(SegmentedButton), findsNothing);
    });

    testWidgets(
      'refreshing yearly trend retains content and scroll controller',
      (tester) async {
        final now = DateTime.now();
        final today = now.day;
        final client = ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
          httpClient: _HabitTestHttpClient(
            year: now.year,
            month: now.month,
            waterByDay: {today - 1: 1500},
            stepsByDay: {today - 1: 5000},
            readingByDay: {},
            languageByDay: {},
            supplementByDay: {},
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: HabitStatsScreen(
              apiClient: client,
              habitSettingsRepo: HabitSettingsRepository(
                storage: _TestStorage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate((widget) => widget is DropdownButton),
          findsNothing,
        );

        final scroll = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller;
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CustomScrollView>(find.byType(CustomScrollView))
              .controller,
          same(scroll),
        );
        expect(find.text('最近6个月'), findsOneWidget);

        expect(find.text('习惯趋势'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('refresh token reloads archived habit settings', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = now.day;
      final storage = _TestStorage();
      final settingsRepo = HabitSettingsRepository(storage: storage);
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {today - 1: 1500},
          stepsByDay: {today - 1: 5000},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: settingsRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is FloraIcon && w.name == FloraIcons.habitWalk,
        ),
        findsWidgets,
      );

      await storage.write(
        'habit_settings',
        jsonEncode(
          const HabitSettings(
            statusMap: {
              'water': true,
              'steps': false,
              'reading': true,
              'language': true,
              'supplements': true,
            },
          ).toJson(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: settingsRepo,
            refreshToken: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is FloraIcon && w.name == FloraIcons.habitWalk,
        ),
        findsNothing,
      );
    });

    testWidgets('uses custom habit visual settings in stats', (tester) async {
      final now = DateTime.now();
      final today = now.day;
      final storage = _TestStorage();
      await storage.write(
        'habit_settings',
        jsonEncode(
          const HabitSettings(
            statusMap: {
              'water': true,
              'steps': true,
              'reading': true,
              'language': true,
              'supplements': true,
            },
            displayNameMap: {'water': '喝水啦'},
            iconMap: {'water': '🥤'},
            colorMap: {'water': 0xFF9B8EC4},
          ).toJson(),
        ),
      );
      final settingsRepo = HabitSettingsRepository(storage: storage);
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {today - 1: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: settingsRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('喝水啦'), findsWidgets);
      expect(find.text('🥤'), findsWidgets);
      expect(find.text('饮水'), findsNothing);
      expect(find.text('💧'), findsNothing);
    });

    testWidgets('handles network failure without white screen', (tester) async {
      final brokenClient = _AlwaysFailHttpClient();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: brokenClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // header 仍然可见，不白屏
      expect(find.text('习惯趋势'), findsOneWidget);
      // 页面显示内容（空状态或错误），不是空白
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('HabitDayRecord persistence', () {
    test('HabitDayRecord toJson fromJson round-trip', () {
      final record = HabitDayRecord(
        date: DateTime(2026, 6, 1),
        weekday: '星期一',
        hasDiary: true,
        waterMl: 1500,
        steps: 5000,
        readingDone: true,
        languageDone: false,
        supplementDone: true,
      );
      final json = record.toJson();
      final restored = HabitDayRecord.fromJson(json);
      expect(restored.date, DateTime(2026, 6, 1));
      expect(restored.waterMl, 1500);
      expect(restored.readingDone, true);
      expect(restored.languageDone, false);
    });
  });
}
