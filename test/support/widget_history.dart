part of '../widget_test.dart';

void registerHistoryTests() {
  group('Top page headers', () {
    ApiClient clientWithBody(String body) {
      return ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _FakeHttpClient(body: body),
      );
    }

    testWidgets('HomeScreen uses date as title and hides connection label', (
      tester,
    ) async {
      final now = DateTime.now();
      const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      final monthDay = '${now.month}月${now.day}日';
      final weekday = '星期${weekdays[now.weekday - 1]}';
      final client = clientWithBody(
        jsonEncode({
          'date': ApiClient.formatDate(now),
          'title': '今天',
          'raw': '# 今天\n',
          'sections': {},
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('荔枝日记'), findsNothing);
      expect(find.text(monthDay), findsOneWidget);
      expect(find.text(weekday), findsOneWidget);
      final title = tester.widget<Text>(find.text(monthDay));
      expect(title.maxLines, 1);
      expect(title.overflow, isNull);
      expect(tester.widget<Text>(find.text(weekday)).overflow, isNull);
      final titleRect = tester.getRect(find.text(monthDay));
      final weekdayRect = tester.getRect(find.text(weekday));
      expect(weekdayRect.top, lessThan(titleRect.bottom));
      expect(find.text('已连接服务器'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is FloraIcon && w.name == FloraIcons.settings,
        ),
        findsNothing,
      );
    });

    testWidgets(
      'PastScreen keeps a safe pinned header in the gallery viewport',
      (tester) async {
        final client = clientWithBody(
          jsonEncode({
            'year': DateTime.now().year,
            'month': DateTime.now().month,
            'diaries': [],
            'raw': '',
          }),
        );

        await tester.pumpWidget(
          MaterialApp(home: PastScreen(apiClient: client)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SafeArea), findsOneWidget);
        expect(find.text('过往'), findsOneWidget);
        expect(find.text('把值得记住的日子，慢慢翻出来'), findsNothing);
        expect(find.byKey(const Key('gallery_month_picker')), findsNothing);
        expect(find.text('今天曾经发生过'), findsNothing);
        expect(find.text('随便走走'), findsNothing);
        expect(
          find.ancestor(of: find.text('过往'), matching: find.byType(ListView)),
          findsNothing,
        );
        expect(
          find.ancestor(
            of: find.byKey(const Key('history_calendar_toggle')),
            matching: find.byType(PinnedHeaderSliver),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.text('过往'),
            matching: find.byType(PinnedHeaderSliver),
          ),
          findsOneWidget,
        );
        final scrollView = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView),
        );
        expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());
      },
    );

    testWidgets('PastScreen labels the memory capsule as 随机漫步', (tester) async {
      final image = img.Image(width: 2, height: 2);
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _PastMemoryHttpClient(
          imageBytes: Uint8List.fromList(img.encodeJpg(image)),
        ),
      );

      await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
      await tester.pumpAndSettle();

      expect(find.text('随机漫步'), findsOneWidget);
      expect(find.text('那年今日'), findsNothing);
      expect(find.byTooltip('随机回顾'), findsOneWidget);
    });

    testWidgets('PastScreen renders one gallery tile per photo day', (
      tester,
    ) async {
      final image = img.Image(width: 2, height: 2);
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _GalleryHttpClient(
          galleryBody: jsonEncode({
            'months': [
              {
                'year': 2024,
                'month': 3,
                'totalDays': 1,
                'totalImages': 2,
                'days': [
                  {
                    'date': '2024-03-08',
                    'images': ['first.jpg', 'second.jpg'],
                    'hasContent': true,
                  },
                ],
              },
            ],
            'nextCursor': null,
          }),
          imageBytes: Uint8List.fromList(img.encodeJpg(image)),
        ),
      );

      await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
      await tester.pumpAndSettle();

      expect(find.byType(GalleryImageTile), findsOneWidget);
      expect(find.text('2024年3月'), findsOneWidget);
      expect(find.text('1天 · 2张'), findsOneWidget);
      expect(find.text('今天曾经发生过'), findsNothing);
      expect(find.text('随便走走'), findsNothing);
    });

    testWidgets(
      'calendar month navigation does not create a gallery jump control',
      (tester) async {
        final client = clientWithBody(
          jsonEncode({
            'year': DateTime.now().year,
            'month': DateTime.now().month,
            'diaries': [],
            'raw': '',
          }),
        );
        final now = DateTime.now();
        final previous = DateTime(now.year, now.month - 1);
        final previousLabel = '${previous.year}年${previous.month}月';

        await tester.pumpWidget(
          MaterialApp(home: PastScreen(apiClient: client)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('history_calendar_toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('history_calendar_previous_month')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('gallery_month_picker')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('history_calendar')),
            matching: find.text(previousLabel),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('stale calendar requests cannot overwrite the latest state', (
      tester,
    ) async {
      final httpClient = _CalendarRaceHttpClient();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: httpClient,
      );

      await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history_calendar_toggle')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('history_calendar_previous_month')),
      );
      await tester.pump();

      expect(httpClient.historyResponses, hasLength(2));
      httpClient.completeHistory(1, statusCode: 200);
      await tester.pumpAndSettle();
      httpClient.completeHistory(0, statusCode: 500);
      await tester.pumpAndSettle();

      expect(find.text('记录标记暂未加载，仍可选择日期'), findsNothing);
    });

    testWidgets(
      'switching api clients clears calendar markers from the old server',
      (tester) async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayKey = ApiClient.formatDate(yesterday);
        final oldClient = ApiClient(
          ApiConfig(baseUrl: 'https://old.test', token: 'test'),
          httpClient: _GalleryHttpClient(
            galleryBody: '{"months":[],"nextCursor":null}',
            imageBytes: Uint8List.fromList([1, 2, 3]),
            historyBody: jsonEncode({
              'year': now.year,
              'month': now.month,
              'diaries': [
                {
                  'date': yesterdayKey,
                  'hasImages': false,
                  'quickNotesCount': 1,
                  'exists': true,
                  'hasContent': true,
                },
              ],
            }),
          ),
        );
        final newClient = ApiClient(
          ApiConfig(baseUrl: 'https://new.test', token: 'test'),
          httpClient: _GalleryHttpClient(
            galleryBody: '{"months":[],"nextCursor":null}',
            imageBytes: Uint8List.fromList([1, 2, 3]),
          ),
        );
        var currentClient = oldClient;
        late VoidCallback switchClient;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              switchClient = () => setState(() => currentClient = newClient);
              return MaterialApp(home: PastScreen(apiClient: currentClient));
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('history_calendar_toggle')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('history_calendar_marker_$yesterdayKey')),
          findsOneWidget,
        );

        switchClient();
        await tester.pumpAndSettle();

        expect(
          find.byKey(ValueKey('history_calendar_marker_$yesterdayKey')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'GalleryImageViewerScreen shows day photo count and diary action',
      (tester) async {
        final image = img.Image(width: 2, height: 2);
        final client = ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
          httpClient: _GalleryHttpClient(
            galleryBody: '{"months":[],"nextCursor":null}',
            imageBytes: Uint8List.fromList(img.encodeJpg(image)),
          ),
        );
        final service = GalleryService(client);
        const day = GalleryDay(
          date: '2024-03-08',
          images: ['first.jpg', 'second.jpg'],
          hasContent: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: GalleryImageViewerScreen(
              day: day,
              galleryService: service,
              apiClient: client,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2024年3月8日'), findsNWidgets(2));
        expect(find.text('1 / 2'), findsOneWidget);
        expect(find.text('查看当天日记'), findsOneWidget);
        final overlayStyles = tester
            .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            );
        expect(
          overlayStyles.any(
            (region) =>
                region.value.systemNavigationBarColor == Colors.black &&
                region.value.systemNavigationBarIconBrightness ==
                    Brightness.light,
          ),
          isTrue,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: _floraIcon(FloraIcons.habitRead),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'GalleryImageViewerScreen shows unavailable state for a missing image',
      (tester) async {
        final client = ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
          httpClient: _GalleryHttpClient(
            galleryBody: '{"months":[],"nextCursor":null}',
            imageBytes: Uint8List.fromList([1, 2, 3]),
            imageStatusCode: 404,
          ),
        );
        final service = GalleryService(client);
        const day = GalleryDay(
          date: '2024-03-08',
          images: ['missing.jpg'],
          hasContent: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: GalleryImageViewerScreen(
              day: day,
              galleryService: service,
              apiClient: client,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('图片不可用'), findsOneWidget);
        expect(find.text('图片加载失败，点击重试'), findsNothing);
      },
    );

    testWidgets(
      'ReadOnlyDiaryScreen keeps refresh available for short content',
      (tester) async {
        final client = clientWithBody(
          jsonEncode({
            'date': '2026-06-08',
            'title': '旧日记',
            'raw': '# 今天\n\n### 🧠 人生教练\n📌 模式识别\n旧内容',
            'sections': {},
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ReadOnlyDiaryScreen(
              date: DateTime(2026, 6, 8),
              apiClient: client,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.physics, isA<AlwaysScrollableScrollPhysics>());
      },
    );

    testWidgets('HistoryCalendar marks only recorded past dates', (
      tester,
    ) async {
      DateTime? selectedDate;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryCalendar(
              displayedMonth: DateTime(2026, 7),
              recordedDateKeys: const {'2026-07-10'},
              today: DateTime(2026, 8, 1),
              onMonthChanged: (_) {},
              onDateSelected: (date) => selectedDate = date,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('history_calendar_marker_2026-07-10')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('history_calendar_marker_2026-07-11')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('history_calendar_day_2026-07-11')),
      );
      expect(selectedDate, DateTime(2026, 7, 11));
    });

    testWidgets('HistoryCalendar disables today and future dates', (
      tester,
    ) async {
      DateTime? selectedDate;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryCalendar(
              displayedMonth: DateTime(2026, 7),
              recordedDateKeys: const {},
              today: DateTime(2026, 7, 10),
              onMonthChanged: (_) {},
              onDateSelected: (date) => selectedDate = date,
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('history_calendar_day_2026-07-10')),
      );
      await tester.tap(
        find.byKey(const Key('history_calendar_day_2026-07-11')),
      );
      expect(selectedDate, isNull);

      await tester.tap(
        find.byKey(const Key('history_calendar_day_2026-07-09')),
      );
      expect(selectedDate, DateTime(2026, 7, 9));
    });

    testWidgets('historical detail exposes only supported backfill actions', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      final client = clientWithBody(
        jsonEncode({
          'date': '2026-06-08',
          'title': '旧日记',
          'raw': '# 今天\n\n## ✍️ 随手记 & 灵感\n- **09:30** 旧内容',
          'sections': {},
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReadOnlyDiaryScreen(
            date: DateTime(2026, 6, 8),
            apiClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('historical_quick_record_fab')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('historical_quick_record_fab')));
      await tester.pump();

      expect(
        find.byKey(const Key('historical_quick_record_quick_note')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('historical_quick_record_reflection')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('historical_quick_record_happiness')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('historical_quick_record_images')),
        findsNothing,
      );
      expect(find.text('焦虑四问'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('historical_quick_record_quick_note')),
        findsNothing,
      );
    });

    testWidgets('historical backfill attaches photos to the text entry', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      final httpClient = _HistoricalBackfillHttpClient();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: httpClient,
        uploadBodyEncoder: _encodeUploadBodyForTest,
      );
      final image = img.Image(width: 8, height: 8);
      _fillSolidImage(image);
      final bytes = Uint8List.fromList(img.encodeJpg(image));
      final imageSettingsRepository = ImageSettingsRepository(
        storage: _TestStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReadOnlyDiaryScreen(
            date: DateTime(2026, 6, 8),
            apiClient: client,
            imageSettingsRepository: imageSettingsRepository,
            imageCompressor: (bytes, settings) async {
              return ImageCompressService.fromSettings(
                settings,
              ).compressToBase64(bytes);
            },
            imagePicker: (_, _) async => [
              XFile.fromData(bytes, name: 'first.jpg', mimeType: 'image/jpeg'),
              XFile.fromData(bytes, name: 'second.jpg', mimeType: 'image/jpeg'),
              XFile.fromData(bytes, name: 'third.jpg', mimeType: 'image/jpeg'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('historical_quick_record_fab')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('historical_quick_record_quick_note')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '历史的一段记录');
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick_capture_add_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();

      expect(httpClient.createCalls, 1);
      expect(httpClient.appendCalls, 2);
      expect(httpClient.uploadCalls, 2);
      expect(find.text('文字已保存，部分照片操作未完成，请重试'), findsOneWidget);
      expect(find.text('上传失败\n点击重试'), findsOneWidget);

      await tester.tap(find.text('上传失败\n点击重试'));
      await tester.pumpAndSettle();

      expect(httpClient.uploadCalls, 3);
      expect(
        httpClient.uploadOperationIds[1],
        httpClient.uploadOperationIds[2],
      );
      final appendBody =
          jsonDecode(httpClient.lastAppendBody!) as Map<String, dynamic>;
      expect(httpClient.uploadEntryIds, everyElement(appendBody['entryId']));
      expect(find.text('上传失败\n点击重试'), findsNothing);
      expect(find.text('重试照片'), findsOneWidget);
      await tester.tap(find.text('重试照片'));
      await tester.pumpAndSettle();
      expect(httpClient.uploadCalls, 4);
      expect(
        httpClient.uploadOperationIds[2],
        isNot(httpClient.uploadOperationIds[3]),
      );
      expect(find.byType(QuickCaptureScreen), findsNothing);
    });

    testWidgets('历史补录部分保存后离开会重新读取目标日期', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final httpClient = _HistoricalBackfillHttpClient();
      final image = img.Image(width: 8, height: 8);
      _fillSolidImage(image);
      final bytes = Uint8List.fromList(img.encodeJpg(image));
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: httpClient,
        uploadBodyEncoder: _encodeUploadBodyForTest,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReadOnlyDiaryScreen(
            date: DateTime(2026, 6, 8),
            apiClient: client,
            imageSettingsRepository: ImageSettingsRepository(
              storage: _TestStorage(),
            ),
            imagePicker: (_, _) async => [
              XFile.fromData(bytes, name: 'first.jpg', mimeType: 'image/jpeg'),
              XFile.fromData(bytes, name: 'second.jpg', mimeType: 'image/jpeg'),
            ],
            imageCompressor: (bytes, settings) async =>
                ImageCompressService.fromSettings(
                  settings,
                ).compressToBase64(bytes),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialGetCalls = httpClient.diaryGetCalls;
      await tester.tap(find.byKey(const Key('historical_quick_record_fab')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('historical_quick_record_quick_note')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '部分保存的历史记录');
      await tester.tap(find.byKey(const Key('quick_capture_add_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();
      expect(httpClient.uploadCalls, 2);
      expect(find.text('上传失败\n点击重试'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();

      expect(httpClient.diaryGetCalls, greaterThan(initialGetCalls));
      expect(find.byType(QuickCaptureScreen), findsNothing);
    });

    testWidgets('historical text backfill creates diary only on save', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      final httpClient = _HistoricalBackfillHttpClient();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: httpClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReadOnlyDiaryScreen(
            date: DateTime(2026, 6, 8),
            apiClient: client,
            draftRepository: DraftRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(httpClient.createCalls, 0);
      await tester.tap(find.byKey(const Key('historical_quick_record_fab')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('historical_quick_record_quick_note')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QuickCaptureScreen), findsOneWidget);
      expect(httpClient.createCalls, 0);

      await tester.enterText(find.byType(TextField), '补录一条旧时光');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();

      expect(httpClient.appendCalls, 2);
      expect(httpClient.createCalls, 1);
      final requestBody =
          jsonDecode(httpClient.lastAppendBody!) as Map<String, dynamic>;
      expect(requestBody['date'], '2026-06-08');
      expect(requestBody['content'], '补录一条旧时光');
      expect(requestBody['time'], matches(RegExp(r'^\d{2}:\d{2}$')));
      expect(find.text('已补录'), findsOneWidget);
    });
  });
}
