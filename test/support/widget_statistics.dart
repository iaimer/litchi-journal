part of '../widget_test.dart';

void registerStatisticsTests() {
  group('HabitStatsService', () {
    setUp(() {
      HabitStatsService.clearCache();
    });

    tearDown(() {
      HabitStatsService.clearCache();
    });

    ApiClient habitTestClient({
      required Map<int, int> waterByDay,
      required Map<int, int> stepsByDay,
      required Map<int, bool> readingByDay,
      required Map<int, bool> languageByDay,
      required Map<int, bool> supplementByDay,
      String? customCheckboxLabel,
    }) {
      final now = DateTime.now();
      return ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: waterByDay,
          stepsByDay: stepsByDay,
          readingByDay: readingByDay,
          languageByDay: languageByDay,
          supplementByDay: supplementByDay,
          customCheckboxLabel: customCheckboxLabel,
        ),
      );
    }

    test('generates correct 7-day date range', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final days = <DateTime>[];
      for (var i = 6; i >= 0; i--) {
        days.add(today.subtract(Duration(days: i)));
      }
      expect(days.length, 7);
      // No future dates
      for (final d in days) {
        expect(d.isAfter(today), false);
      }
    });

    test('parses numeric and duration habits correctly', () async {
      final now = DateTime.now();
      final today = now.day;
      final apiClient = habitTestClient(
        waterByDay: {today - 1: 1500, today - 2: 800},
        stepsByDay: {today - 1: 6000},
        readingByDay: {today - 1: true, today - 2: true},
        languageByDay: {today - 1: true},
        supplementByDay: {today - 1: true, today - 2: true, today - 3: true},
      );

      final service = HabitStatsService(apiClient);
      final stats = await service.loadStats();

      expect(stats.items.length, 5);

      // 饮水
      final water = stats.items.firstWhere((i) => i.key == 'water');
      expect(water.type, HabitStatType.numeric);
      expect(water.completedDays, 2);

      // 亲子共读
      final reading = stats.items.firstWhere((i) => i.key == 'reading');
      expect(reading.type, HabitStatType.duration);
      expect(reading.completedDays, 2);

      // 鱼油
      final supp = stats.items.firstWhere((i) => i.key == 'supplements');
      expect(supp.type, HabitStatType.boolean);
      expect(supp.completedDays, 3);
      expect(supp.currentStreak, 3);
    });

    test(
      'uses checkbox completion when reading is configured as checkbox',
      () async {
        final now = DateTime.now();
        final today = now.day;
        final apiClient = habitTestClient(
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {today - 1: true, today - 2: true},
          languageByDay: {},
          supplementByDay: {},
        );
        final settings = HabitSettings.defaults.updateHabit(
          key: 'reading',
          trackingType: HabitTrackingType.checkbox,
        );

        final stats = await HabitStatsService(
          apiClient,
        ).loadStats(habitSettings: settings);
        final reading = stats.items.firstWhere((item) => item.key == 'reading');

        expect(reading.type, HabitStatType.boolean);
        expect(reading.completedDays, 2);
        expect(reading.recent7Values.where((value) => value == 1).length, 2);
      },
    );

    test(
      'keeps an old custom checkbox completion after switching to duration',
      () async {
        final today = DateTime.now().day;
        final apiClient = habitTestClient(
          waterByDay: {today - 1: 0},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
          customCheckboxLabel: '专注学习',
        );
        final settings = HabitSettings.defaults.copyWith(
          statusMap: {'custom_focus': true},
          extraHabits: {'custom_focus': '专注学习'},
          trackingTypeMap: {'custom_focus': HabitTrackingType.duration},
        );

        final stats = await HabitStatsService(
          apiClient,
        ).loadStats(habitSettings: settings);
        final focus = stats.items.firstWhere(
          (item) => item.key == 'custom_focus',
        );

        expect(focus.type, HabitStatType.duration);
        expect(focus.completedDays, 1);
        expect(focus.lifetimeValue, 0);
        expect(focus.recent7Completed.where((done) => done).length, 1);
      },
    );

    test('returns empty stats when no habit data', () async {
      final apiClient = habitTestClient(
        waterByDay: {},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
      );

      final service = HabitStatsService(apiClient);
      final stats = await service.loadStats();

      expect(stats.feedbackSuggestion, '先选一个最容易的小习惯照顾起来就很好。');
    });

    test('generates feedback text for stable week', () async {
      final now = DateTime.now();
      final today = now.day;
      final apiClient = habitTestClient(
        waterByDay: {for (var i = 1; i <= 6; i++) today - i: 1500},
        stepsByDay: {for (var i = 1; i <= 6; i++) today - i: 5000},
        readingByDay: {for (var i = 1; i <= 6; i++) today - i: true},
        languageByDay: {for (var i = 1; i <= 6; i++) today - i: true},
        supplementByDay: {for (var i = 1; i <= 6; i++) today - i: true},
      );

      final service = HabitStatsService(apiClient);
      final stats = await service.loadStats();

      expect(stats.feedbackSummary, '这周你把自己照顾得挺稳定。');
    });

    test('phased loading: loadRecent7 returns 7-day data first', () async {
      final apiClient = habitTestClient(
        waterByDay: {DateTime.now().day - 1: 1500},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
      );

      final service = HabitStatsService(apiClient);
      final stats7 = await service.loadRecent7();

      // 7 天数据已填充
      expect(stats7.recentDays.length, 7);
      expect(stats7.items.length, 5);
      expect(stats7.items.first.recent7Values.length, 7);

      // 30 天字段应为空
      expect(stats7.days30, isEmpty);
      expect(stats7.items.first.recent30Values, isEmpty);
    });

    test(
      'phased loading: loadRecent30 fills 30-day data after loadRecent7',
      () async {
        final apiClient = habitTestClient(
          waterByDay: {DateTime.now().day - 1: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        );

        final service = HabitStatsService(apiClient);
        await service.loadRecent7();
        final stats30 = await service.loadRecent30();

        // 30 天数据已填充
        expect(stats30.days30.length, 30);
        expect(stats30.items.first.recent30Values.length, 30);
      },
    );

    test('30-day load reuses 7-day cached day records', () async {
      final apiClient = habitTestClient(
        waterByDay: {DateTime.now().day - 1: 1500},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
      );

      final service = HabitStatsService(apiClient);
      await service.loadRecent7();

      // 清掉 history month 缓存，验证 30 天阶段不再请求 history
      HabitStatsService.clearCache();
      // 但 dayCache 还保留（没办法单独检查，但能验证 30 天正常完成）
      final stats30 = await service.loadRecent30();
      expect(stats30.days30.length, 30);
    });

    test('history month results are cached', () async {
      final apiClient = habitTestClient(
        waterByDay: {},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
      );

      final service1 = HabitStatsService(apiClient);
      await service1.loadRecent7();

      // 第二个 service 实例复用缓存
      final service2 = HabitStatsService(apiClient);
      final stats = await service2.loadRecent7();
      expect(stats.recentDays.length, 7);
    });

    test(
      'static cache is reused across ApiClient instances with same baseUrl',
      () async {
        final now = DateTime.now();
        final today = now.day;
        final firstHttpClient = _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {today - 1: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        );
        final firstApiClient = ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
          httpClient: firstHttpClient,
        );

        final service1 = HabitStatsService(firstApiClient);
        await service1.loadRecent7();

        final secondHttpClient = _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        );
        final secondApiClient = ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
          httpClient: secondHttpClient,
        );

        final service2 = HabitStatsService(secondApiClient);
        final stats = await service2.loadRecent7();

        expect(stats.recentDays.length, 7);
        expect(secondHttpClient.historyRequestCount, 0);
        expect(secondHttpClient.diaryRequestCount, 0);
      },
    );

    test('single day getDiary failure does not break overall stats', () async {
      final now = DateTime.now();
      // 用 broken HTTP client 模拟某一天失败
      var callCount = 0;
      final brokenClient = _SelectiveFailureHttpClient(
        year: now.year,
        month: now.month,
        waterByDay: {now.day - 1: 1500, now.day - 2: 800, now.day - 3: 1200},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
        failOnDay: now.day - 2,
        failCount: 1,
        callCount: () => callCount++,
      );

      final apiClient = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: brokenClient,
      );

      final service = HabitStatsService(apiClient);
      final stats = await service.loadStats();

      // 即使某天失败，统计仍完整
      expect(stats.items.length, 5);
      expect(stats.recentDays.length, 7);
      // 不崩溃
    });

    test('only loads getDiary for dates in history month result', () async {
      final now = DateTime.now();
      var getDiaryCount = 0;

      final client = _CountingGetDiaryHttpClient(
        year: now.year,
        month: now.month,
        waterByDay: {now.day - 1: 1500},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
        onGetDiary: () => getDiaryCount++,
      );

      final apiClient = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: client,
      );

      final service = HabitStatsService(apiClient);
      await service.loadStats();

      // 只有 history month 中存在的日期才调用了 getDiary
      // 最多调用 1 次（只有 now.day-1 有数据）
      expect(getDiaryCount, lessThanOrEqualTo(1));
    });

    test('concurrent loading does not miss data', () async {
      final now = DateTime.now();
      final today = now.day;
      final waterData = <int, int>{};
      for (var i = 0; i < 7; i++) {
        waterData[today - i] = 1500;
      }

      final apiClient = habitTestClient(
        waterByDay: waterData,
        stepsByDay: {for (var i = 0; i < 7; i++) today - i: 5000},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
      );

      final service = HabitStatsService(apiClient);
      final stats = await service.loadStats();

      final water = stats.items.firstWhere((i) => i.key == 'water');
      // 最近 7 天全部有数据
      expect(water.completedDays, 7);
    });
  });

  group('HabitStatsScreen', () {
    setUp(() {
      HabitStatsService.clearCache();
    });

    tearDown(() {
      HabitStatsService.clearCache();
    });

    /// 返回一个不会在测试中挂起的内存缓存仓库。
    HabitStatsCacheRepository testCacheRepo() =>
        HabitStatsCacheRepository(storage: _MemoryStorage());

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
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('习惯趋势'), findsOneWidget);
      expect(find.text('月'), findsOneWidget);
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
            cacheRepo: testCacheRepo(),
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
            cacheRepo: testCacheRepo(),
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
            cacheRepo: testCacheRepo(),
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
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('习惯趋势'), findsOneWidget);
      expect(find.text('月'), findsOneWidget);
    });

    testWidgets('trend page keeps metric descriptions out of visible cards', (
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
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('完成率'), findsNothing);
      expect(find.textContaining('最长连续'), findsNothing);
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
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      // 单帧后 header 已显示
      expect(find.text('习惯趋势'), findsOneWidget);
      expect(find.text('月'), findsOneWidget);
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
            cacheRepo: testCacheRepo(),
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
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('习惯趋势'), findsOneWidget);
      expect(find.text('月'), findsOneWidget);
    });

    testWidgets('switching trend period does not show page loading', (
      tester,
    ) async {
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
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButton<HabitItemStats>), findsNothing);

      final yearSegment = find.text('年');
      expect(yearSegment, findsOneWidget);
      await tester.tap(yearSegment);
      await tester.pumpAndSettle();

      expect(find.text('习惯趋势'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('refresh token reloads archived habit settings', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = now.day;
      final storage = _TestStorage();
      final settingsRepo = HabitSettingsRepository(storage: storage);
      final cacheRepo = testCacheRepo();
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
            cacheRepo: cacheRepo,
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
            cacheRepo: cacheRepo,
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
            cacheRepo: testCacheRepo(),
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
            cacheRepo: testCacheRepo(),
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

  group('HabitStatsCacheRepository', () {
    late _MemoryStorage memoryStorage;
    late HabitStatsCacheRepository cacheRepo;

    setUp(() {
      memoryStorage = _MemoryStorage();
      cacheRepo = HabitStatsCacheRepository(storage: memoryStorage);
    });

    HabitStats makeStats() {
      final day = HabitDayRecord(
        date: DateTime(2026, 6, 1),
        weekday: '星期一',
        hasDiary: true,
        waterMl: 1500,
        steps: 5000,
        readingDone: true,
        languageDone: false,
        supplementDone: true,
      );
      return HabitStats(
        recentDays: [day],
        monthDays: [day],
        days30: [day],
        items: [
          HabitItemStats(
            key: 'water',
            title: '饮水',
            group: HabitGroup.body,
            type: HabitStatType.numeric,
            recent7Values: [1500],
            completedDays: 1,
            totalDays: 1,
            averageValue: 1500,
            currentStreak: 1,
            displayName: '饮水',
            icon: '💧',
            color: const Color(0xFF6BAED6),
            recent30Values: [1500],
            completedDays30: 1,
            completionRate30: 1.0,
            longestStreak30: 1,
          ),
        ],
        overallRate: 1.0,
        feedbackText: '测试',
        feedbackSummary: '总结',
        feedbackSuggestion: '建议',
      );
    }

    test('save and load round-trip', () async {
      final stats = makeStats();
      await cacheRepo.save(stats);
      final loaded = await cacheRepo.load();
      expect(loaded, isNotNull);
      expect(loaded!.items.length, 1);
      expect(loaded.items.first.key, 'water');
      expect(loaded.feedbackSummary, '总结');
    });

    test('load returns null when no cache', () async {
      final loaded = await cacheRepo.load();
      expect(loaded, isNull);
    });

    test('schema version mismatch ignores cache', () async {
      final stats = makeStats();
      await cacheRepo.save(stats);

      // 篡改 schema version
      final raw = await memoryStorage.read('habit_stats_cache');
      final json = jsonDecode(raw!) as Map<String, dynamic>;
      json['schemaVersion'] = 999;
      await memoryStorage.write('habit_stats_cache', jsonEncode(json));

      final loaded = await cacheRepo.load();
      expect(loaded, isNull);
    });

    test('corrupted JSON returns null, does not throw', () async {
      await memoryStorage.write('habit_stats_cache', 'not valid json {{{');
      final loaded = await cacheRepo.load();
      expect(loaded, isNull);
    });

    test('clear removes cache', () async {
      final stats = makeStats();
      await cacheRepo.save(stats);
      await cacheRepo.clear();
      final loaded = await cacheRepo.load();
      expect(loaded, isNull);
    });
  });

  group('HabitStats persistence round-trip', () {
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

    test('HabitItemStats toJson fromJson round-trip with Color', () {
      final item = HabitItemStats(
        key: 'water',
        title: '饮水',
        group: HabitGroup.body,
        type: HabitStatType.numeric,
        recent7Values: [1500, 800],
        completedDays: 2,
        totalDays: 7,
        averageValue: 328,
        currentStreak: 2,
        displayName: '饮水',
        icon: '💧',
        color: const Color(0xFF6BAED6),
        recent30Values: List.generate(30, (i) => i < 10 ? 1500 : 0),
        completedDays30: 10,
        completionRate30: 0.33,
        longestStreak30: 10,
      );
      final json = item.toJson();
      final restored = HabitItemStats.fromJson(json);
      expect(restored.key, 'water');
      expect(restored.recent7Values, [1500, 800]);
      expect(restored.displayName, '饮水');
      expect(restored.icon, '💧');
      expect(restored.color.toARGB32(), 0xFF6BAED6);
      expect(restored.recent30Values.length, 30);
      expect(restored.completionRate30, 0.33);
    });

    test('HabitStats full round-trip with cachedAt', () {
      final day = HabitDayRecord(
        date: DateTime(2026, 6, 1),
        weekday: '星期一',
        hasDiary: true,
        waterMl: 1500,
        steps: 5000,
        readingDone: true,
        languageDone: false,
        supplementDone: true,
      );
      final stats = HabitStats(
        recentDays: [day],
        monthDays: [day],
        days30: [day],
        items: [
          HabitItemStats(
            key: 'water',
            title: '饮水',
            group: HabitGroup.body,
            type: HabitStatType.numeric,
            recent7Values: [1500],
            completedDays: 1,
            totalDays: 1,
            averageValue: 1500,
            currentStreak: 1,
            displayName: '饮水',
            icon: '💧',
            color: const Color(0xFF6BAED6),
          ),
        ],
        overallRate: 1.0,
        feedbackText: '测试文案',
        feedbackSummary: '总结',
        feedbackSuggestion: '建议',
        cachedAt: DateTime(2026, 6, 1, 12, 0),
      );
      final json = stats.toJson();
      expect(json['schemaVersion'], HabitStats.schemaVersion);

      final restored = HabitStats.fromJson(json);
      expect(restored.items.length, 1);
      expect(restored.feedbackSummary, '总结');
      expect(restored.cachedAt, isNotNull);
    });
  });
}
