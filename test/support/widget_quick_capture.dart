part of '../widget_test.dart';

void registerQuickCaptureTests() {
  group('Quick record entry', () {
    String todayDiaryBody() {
      final now = DateTime.now();
      return jsonEncode({
        'date': ApiClient.formatDate(now),
        'title': '今天',
        'raw': '# 今天\n',
        'sections': {},
      });
    }

    ApiClient homeClient(
      http.BaseClient httpClient, {
      UploadBodyEncoder? uploadBodyEncoder,
    }) {
      return ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: httpClient,
        uploadBodyEncoder: uploadBodyEncoder,
      );
    }

    Widget buildHome({ThemeData? theme, http.BaseClient? httpClient}) {
      return MaterialApp(
        theme: theme,
        home: HomeScreen(
          apiClient: homeClient(
            httpClient ?? _FakeHttpClient(body: todayDiaryBody()),
          ),
          habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
        ),
      );
    }

    testWidgets('HomeScreen shows quick record FAB', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_record_fab')), findsOneWidget);
    });

    testWidgets('HomeScreen shows habit card when today diary is empty', (
      tester,
    ) async {
      final now = DateTime.now();
      final httpClient = _RecordingHttpClient(
        body: jsonEncode({
          'date': ApiClient.formatDate(now),
          'title': '今天',
          'raw': '',
          'sections': {},
        }),
      );

      await tester.pumpWidget(buildHome(httpClient: httpClient));
      await tester.pumpAndSettle();

      expect(find.text('今日还没有日记内容'), findsOneWidget);
      expect(find.byKey(const ValueKey('habit_card')), findsOneWidget);
      expect(find.text('亲子共读'), findsOneWidget);

      // 阅读改为计时型习惯；用仍保留的 checkbox 习惯验证整组保存接口。
      await tester.tap(find.text('补充剂'));
      await tester.pumpAndSettle();

      expect(
        httpClient.requestPaths.any(
          (path) => path.startsWith('POST /api/v1/diary/habit'),
        ),
        isTrue,
      );
    });

    testWidgets('HomeScreen leaves loading state when diary request hangs', (
      tester,
    ) async {
      await tester.pumpWidget(buildHome(httpClient: _HangingHttpClient()));
      await tester.pump();

      expect(find.byType(FloraSkeletonBox), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(seconds: 13));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('此日记尚未缓存'), findsWidgets);
      expect(find.byKey(const ValueKey('habit_card')), findsNothing);
    });

    testWidgets('PastScreen does not show quick record FAB', (tester) async {
      final client = homeClient(
        _FakeHttpClient(
          body: jsonEncode({
            'year': DateTime.now().year,
            'month': DateTime.now().month,
            'diaries': [],
            'raw': '',
          }),
        ),
      );

      await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_record_fab')), findsNothing);
    });

    testWidgets('HabitStatsScreen does not show quick record FAB', (
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
      await tester.pump();

      expect(find.byKey(const Key('quick_record_fab')), findsNothing);
    });

    testWidgets('今天页竖排入口有展开收回中间帧', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pumpAndSettle();
      final fab = find.byKey(const Key('quick_record_fab'));
      final note = find.byKey(const Key('quick_record_quick_note'));
      await tester.tap(fab);
      await tester.pump();
      final start = tester.getTopLeft(note);
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getTopLeft(note).dy, lessThan(start.dy));
      await tester.pumpAndSettle();
      final end = tester.getTopLeft(note);
      expect(start.dy - end.dy, closeTo(8, 0.01));
      await tester.tapAt(const Offset(20, 180));
      await tester.pump();
      expect(note, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getTopLeft(note).dy, greaterThan(end.dy));
      await tester.pumpAndSettle();
      expect(note, findsNothing);
    });

    testWidgets('展开中选择随手记，返回今天页后菜单保持关闭', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pumpAndSettle();
      final note = find.byKey(const Key('quick_record_quick_note'));
      await tester.tap(find.byKey(const Key('quick_record_fab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(note);
      await tester.pumpAndSettle();
      expect(find.byType(QuickCaptureScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(QuickCaptureScreen), findsNothing);
      expect(note, findsNothing);
    });

    testWidgets('FAB 展开三个图文竖排入口', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pumpAndSettle();
      final fab = find.byKey(const Key('quick_record_fab'));
      final anchor = tester.getRect(fab);
      await tester.tap(fab);
      await tester.pumpAndSettle();
      final entries = [
        'happiness',
        'reflection',
        'quick_note',
      ].map((name) => find.byKey(Key('quick_record_$name'))).toList();
      for (final label in ['小确幸', '觉察', '随手记']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final entry in entries) {
        expect(tester.getSize(entry), const Size(176, 56));
        expect(tester.getRect(entry).right, closeTo(anchor.right, 0.01));
      }
      expect(
        tester.getRect(entries[0]).bottom,
        closeTo(tester.getRect(entries[1]).top, 0.01),
      );
      expect(
        tester.getRect(entries[1]).bottom,
        closeTo(tester.getRect(entries[2]).top, 0.01),
      );
      expect(tester.widget<FloatingActionButton>(fab).onPressed, isNull);
      expect(find.byKey(const Key('quick_record_anxiety')), findsNothing);
      expect(find.byKey(const Key('quick_record_image')), findsNothing);
    });

    testWidgets('today quick note adds a photo inside capture and retries it', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      final httpClient = _TodayImageUploadHttpClient();
      final image = img.Image(width: 8, height: 8);
      _fillSolidImage(image);
      final bytes = Uint8List.fromList(img.encodeJpg(image));

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            apiClient: homeClient(
              httpClient,
              uploadBodyEncoder: _encodeUploadBodyForTest,
            ),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
            imagePicker: (_, _) async => [
              XFile.fromData(bytes, name: 'today.jpg', mimeType: 'image/jpeg'),
            ],
            imageCompressor: (bytes, settings) async {
              return ImageCompressService.fromSettings(
                settings,
              ).compressToBase64(bytes);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_record_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_record_quick_note')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '今天的一段记录');
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick_capture_add_photo')));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('上传失败\n点击重试'), findsOneWidget);
      expect(find.text('文字已保存，部分照片操作未完成，请重试'), findsOneWidget);

      final retry = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('retry_image_'),
      );
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(httpClient.uploadCalls, 2);
      expect(httpClient.uploadOperationIds.toSet(), hasLength(1));
      expect(find.text('上传失败\n点击重试'), findsNothing);
      final appendBody =
          jsonDecode(httpClient.lastAppendBody!) as Map<String, dynamic>;
      expect(httpClient.uploadEntryIds, everyElement(appendBody['entryId']));
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('已保存文字但照片失败后离开仍刷新今天页', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final httpClient = _TodayImageUploadHttpClient();
      final image = img.Image(width: 8, height: 8);
      _fillSolidImage(image);
      final bytes = Uint8List.fromList(img.encodeJpg(image));

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            apiClient: homeClient(
              httpClient,
              uploadBodyEncoder: _encodeUploadBodyForTest,
            ),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
            imagePicker: (_, _) async => [
              XFile.fromData(bytes, name: 'today.jpg', mimeType: 'image/jpeg'),
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
      await tester.tap(find.byKey(const Key('quick_record_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_record_quick_note')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '已保存的正文');
      await tester.tap(find.byKey(const Key('quick_capture_add_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('上传失败\n点击重试'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();

      expect(httpClient.diaryGetCalls, greaterThan(initialGetCalls));
      expect(find.text('已保存的正文'), findsOneWidget);
    });

    testWidgets('编辑记录添加照片后刷新今天页', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      const entryId = '11111111-1111-4111-8111-111111111111';
      final httpClient = _TodayImageUploadHttpClient(
        failFirstUpload: false,
        diaryRaw:
            '''
# 今天

## ✍️ 随手记 & 灵感
- **08:00** 原文
<!-- litchi-entry-id:$entryId -->

## 📸 影像记录
''',
      );
      final image = img.Image(width: 8, height: 8);
      _fillSolidImage(image);
      final bytes = Uint8List.fromList(img.encodeJpg(image));

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            apiClient: homeClient(
              httpClient,
              uploadBodyEncoder: _encodeUploadBodyForTest,
            ),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
            imagePicker: (_, _) async => [
              XFile.fromData(bytes, name: 'today.jpg', mimeType: 'image/jpeg'),
            ],
            imageCompressor: (bytes, settings) async =>
                ImageCompressService.fromSettings(
                  settings,
                ).compressToBase64(bytes),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多操作').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_capture_add_photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureScreen), findsNothing);
      expect(find.byType(DiaryImageThumbnail), findsOneWidget);
    });

    testWidgets('quick note entry opens QuickCaptureScreen', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_record_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_record_quick_note')));
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureScreen), findsOneWidget);
      expect(find.text('随手记'), findsOneWidget);
      expect(
        find.byKey(const Key('quick_capture_time_metadata')),
        findsOneWidget,
      );
      expect(find.text('标签暂不可用'), findsNothing);
      expect(find.byKey(const Key('quick_capture_tag_toggle')), findsOneWidget);
    });

    testWidgets('happiness entry opens QuickCaptureScreen', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_record_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_record_happiness')));
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureScreen), findsOneWidget);
      expect(find.text('小确幸'), findsOneWidget);
    });

    testWidgets('reflection entry opens QuickCaptureScreen', (tester) async {
      await tester.pumpWidget(buildHome());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_record_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_record_reflection')));
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureScreen), findsOneWidget);
      expect(find.text('觉察'), findsOneWidget);
    });

    testWidgets('selecting text entries does not write empty content', (
      tester,
    ) async {
      final httpClient = _RecordingHttpClient(body: todayDiaryBody());
      await tester.pumpWidget(buildHome(httpClient: httpClient));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_record_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_record_happiness')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();

      expect(
        httpClient.requestPaths.any(
          (path) => path.startsWith('POST /api/v1/diary/happiness'),
        ),
        isFalse,
      );
      expect(find.text('有什么让你开心的小事？\n记下那个瞬间就好。'), findsOneWidget);
    });

    testWidgets('关闭竖排菜单不写入内容', (tester) async {
      final httpClient = _RecordingHttpClient(body: todayDiaryBody());
      await tester.pumpWidget(buildHome(httpClient: httpClient));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_record_fab')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 180));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_record_quick_note')), findsNothing);
      expect(
        httpClient.requestPaths.any(
          (path) =>
              path.startsWith('POST /api/v1/diary/quick-note') ||
              path.startsWith('POST /api/v1/diary/happiness') ||
              path.startsWith('POST /api/v1/diary/reflection') ||
              path.startsWith('POST /api/v1/diary/anxiety'),
        ),
        isFalse,
      );
    });

    testWidgets('FAB and fan entries are readable in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildHome(theme: AppTheme.dark));
      await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(
        find.byKey(const Key('quick_record_fab')),
      );
      expect(fab.backgroundColor, AppColors.darkPrimary);
      expect(fab.foregroundColor, AppColors.darkBackground);

      await tester.tap(find.byKey(const Key('quick_record_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick_record_quick_note')), findsOneWidget);
      expect(find.text('焦虑四问'), findsNothing);
    });

    testWidgets('HomeScreen no longer shows inline quick record card', (
      tester,
    ) async {
      await tester.pumpWidget(buildHome());
      await tester.pumpAndSettle();

      expect(find.text('快速记录'), findsNothing);
      expect(find.text('添加照片'), findsNothing);
      expect(find.text('选择图片'), findsNothing);
    });

    testWidgets('quick capture save returns home and refreshes diary', (
      tester,
    ) async {
      final httpClient = _RecordingHttpClient(body: todayDiaryBody());
      await tester.pumpWidget(buildHome(httpClient: httpClient));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_record_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_record_quick_note')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '统一记录测试');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickCaptureScreen), findsNothing);
      expect(find.text('已保存'), findsOneWidget);
      expect(
        httpClient.requestPaths.any(
          (path) => path.startsWith('POST /api/v1/diary/quick-note'),
        ),
        isTrue,
      );
      expect(
        httpClient.requestPaths.where(
          (path) => path.startsWith('GET /api/v1/diary/'),
        ),
        isNotEmpty,
      );
    });
  });

  group('QuickCaptureScreen', () {
    Widget buildCapture({
      EntryType entryType = EntryType.quickNote,
      DateTime? openedAt,
      TagConfig? tagConfig,
      Future<PolishResult> Function(String content, EntryType entryType)?
      onPolish,
      Future<TimeOfDay?> Function(BuildContext, TimeOfDay)? timePicker,
      Future<void> Function(QuickCaptureSubmission submission)? onSave,
    }) {
      return MaterialApp(
        home: QuickCaptureScreen(
          entryType: entryType,
          openedAt: openedAt ?? DateTime(2026, 6, 17, 21, 35),
          tagConfig: tagConfig,
          onPolish: onPolish,
          timePicker: timePicker,
          onSave: onSave ?? (_) async {},
        ),
      );
    }

    testWidgets('shows time picker, polish button, and bottom save', (
      tester,
    ) async {
      await tester.pumpWidget(buildCapture());

      expect(find.text('随手记'), findsOneWidget);
      expect(
        find.byKey(const Key('quick_capture_time_metadata')),
        findsOneWidget,
      );
      expect(find.text('今天 21:35'), findsOneWidget);
      expect(find.text('润色'), findsOneWidget);
      expect(find.text('AI 润色'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, '保存'), findsOneWidget);
    });

    testWidgets('historical capture displays the target date', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuickCaptureScreen(
            entryType: EntryType.quickNote,
            openedAt: DateTime(2026, 7, 31, 8, 5),
            recordDate: DateTime(2026, 7, 10),
            onSave: (_) async {},
          ),
        ),
      );

      expect(find.text('2026年7月10日 08:05'), findsOneWidget);
      expect(find.textContaining('今天'), findsNothing);
    });

    testWidgets('default time is captured when screen opens', (tester) async {
      String? savedTime;
      await tester.pumpWidget(
        buildCapture(
          openedAt: DateTime(2026, 6, 17, 8, 5),
          onSave: (submission) async => savedTime = submission.time,
        ),
      );

      await tester.enterText(find.byType(TextField), '早上的记录');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();

      expect(savedTime, '08:05');
    });

    testWidgets('changed time is used when saving', (tester) async {
      String? savedTime;
      await tester.pumpWidget(
        buildCapture(
          timePicker: (_, _) async => const TimeOfDay(hour: 22, minute: 10),
          onSave: (submission) async => savedTime = submission.time,
        ),
      );

      await tester.tap(find.byKey(const Key('quick_capture_time_metadata')));
      await tester.pumpAndSettle();
      expect(find.text('今天 22:10'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '晚上补记');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();

      expect(savedTime, '22:10');
    });

    testWidgets('tags can be selected and saved', (tester) async {
      List<String>? savedTags;
      await tester.pumpWidget(
        buildCapture(
          tagConfig: _testTagConfig(),
          onSave: (submission) async => savedTags = submission.tags,
        ),
      );

      await tester.tap(find.text('标签'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('工作'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '带标签的记录');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();

      expect(savedTags, contains('工作'));
    });

    testWidgets('polish updates content and tags', (tester) async {
      await tester.pumpWidget(
        buildCapture(
          tagConfig: _testTagConfig(),
          onPolish: (_, entryType) async {
            expect(entryType, EntryType.quickNote);
            return const PolishResult(content: '润色后的内容', tags: ['工作']);
          },
        ),
      );

      await tester.enterText(find.byType(TextField), '原始内容');
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick_capture_polish')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, '润色后的内容');
      expect(find.text('工作'), findsWidgets);
    });

    testWidgets('save and tags stay disabled while polish is pending', (
      tester,
    ) async {
      final polishResult = Completer<PolishResult>();
      await tester.pumpWidget(
        buildCapture(
          tagConfig: _testTagConfig(),
          onPolish: (_, _) => polishResult.future,
        ),
      );

      await tester.enterText(find.byType(TextField), '等待润色');
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick_capture_polish')));
      await tester.pump();

      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('quick_capture_tag_toggle')),
            )
            .onPressed,
        isNull,
      );

      polishResult.complete(const PolishResult(content: '润色完成', tags: ['工作']));
      await tester.pumpAndSettle();

      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('save failure keeps content and tags', (tester) async {
      await tester.pumpWidget(
        buildCapture(
          tagConfig: _testTagConfig(),
          onSave: (_) async => throw Exception('fail'),
        ),
      );

      await tester.tap(find.text('标签'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('工作'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '不要丢');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.text('保存失败，请重试', skipOffstage: false), findsOneWidget);
      expect(find.byType(QuickCaptureScreen), findsOneWidget);
      expect(find.text('不要丢'), findsOneWidget);
      expect(find.text('工作'), findsWidgets);
    });

    testWidgets('back with content asks before discard', (tester) async {
      await tester.pumpWidget(buildCapture());

      await tester.enterText(find.byType(TextField), '未保存内容');
      await tester.tap(_floraIcon(FloraIcons.back));
      await tester.pumpAndSettle();

      expect(find.text('放弃记录？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickCaptureScreen), findsOneWidget);
    });

    testWidgets('system back asks before discarding edit changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuickCaptureScreen(
            entryType: EntryType.quickNote,
            openedAt: DateTime(2026, 9, 11, 21, 18),
            initialContent: '已有内容',
            initialTime: '09:30',
            onSave: (_) async {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '修改后的内容');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('放弃记录？'), findsOneWidget);
      expect(find.byType(QuickCaptureScreen), findsOneWidget);
    });

    testWidgets('edit mode ignores and preserves the add-entry draft', (
      tester,
    ) async {
      final date = DateTime(2026, 9, 11);
      final repository = DraftRepository(storage: _TestStorage());
      await repository.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: '新增记录草稿',
        tags: const ['工作'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QuickCaptureScreen(
            entryType: EntryType.quickNote,
            openedAt: DateTime(2026, 9, 11, 21, 18),
            recordDate: date,
            initialContent: '已有记录',
            initialTime: '09:30',
            draftRepository: repository,
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已有记录'), findsOneWidget);
      expect(find.text('新增记录草稿'), findsNothing);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final draft = await repository.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );
      expect(draft?.content, '新增记录草稿');
      expect(draft?.tags, const ['工作']);
    });
  });

  test(
    'PastMemoryService retries month loading after transient failure',
    () async {
      final now = DateTime.now();
      final memoryDate = DateTime(
        now.year,
        now.month,
        now.day == 1 ? 2 : now.day - 1,
      );
      final httpClient = _PastMemoryRetryClient(memoryDate);
      final apiClient = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: httpClient,
      );
      final service = PastMemoryService(apiClient);

      final first = await service.getRandomMemory();
      final second = await service.getRandomMemory();

      expect(first, isNull);
      expect(second, isNotNull);
      expect(second!.date, memoryDate);
      expect(httpClient.historyCalls, greaterThan(2));
    },
  );
}
