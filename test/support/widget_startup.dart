part of '../widget_test.dart';

void registerStartupTests() {
  group('AppEntry brand splash', () {
    testWidgets('shows FloraSplash before setup when config is missing', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});

      await tester.pumpWidget(const MaterialApp(home: app.AppEntry()));

      final splashImage = tester.widget<Image>(find.byType(Image).first);
      expect(splashImage.image, isA<AssetImage>());
      expect(
        (splashImage.image as AssetImage).assetName,
        'assets/icon/app-icon.png',
      );
      expect(find.text('Flora'), findsNothing);
      expect(find.text('初始设置'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();

      expect(find.text('初始设置'), findsOneWidget);
      expect(find.text('服务器地址'), findsOneWidget);
    });

    testWidgets('shows FloraSplash before main screen when config exists', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({
        'api_base_url': 'http://127.0.0.1:9',
        'api_token': 'test-token',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: app.AppEntry(readingCache: ReadingCacheRepository.disabled),
        ),
      );

      final splashImage = tester.widget<Image>(find.byType(Image).first);
      expect(splashImage.image, isA<AssetImage>());
      expect(
        (splashImage.image as AssetImage).assetName,
        'assets/icon/app-icon.png',
      );
      expect(find.text('Flora'), findsNothing);
      expect(find.byType(app.MainScreen), findsNothing);

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();

      expect(find.byType(app.MainScreen), findsOneWidget);
      expect(find.text('今天'), findsWidgets);
    });
  });

  test('DiaryEntry.fromJson parses valid data', () {
    final json = {
      'date': '2026-06-06',
      'title': 'Test',
      'raw': 'Hello world',
      'sections': {
        'notes': ['note1', 'note2'],
      },
    };
    final entry = DiaryEntry.fromJson(json);
    expect(entry.date, '2026-06-06');
    expect(entry.title, 'Test');
    expect(entry.raw, 'Hello world');
    expect(entry.sections['notes'], ['note1', 'note2']);
  });

  test('DiaryEntry.fromJson handles empty data', () {
    final entry = DiaryEntry.fromJson({});
    expect(entry.date, '');
    expect(entry.title, '');
    expect(entry.raw, '');
    expect(entry.sections, {});
    expect(entry.isEmpty, isTrue);
  });
}
