part of '../widget_test.dart';

void registerImagesTests() {
  group('ImageSettings', () {
    test('defaults are correct', () {
      final settings = ImageSettings.defaults();
      expect(settings.maxLongSidePx, 2000);
      expect(settings.targetSizeMb, 3);
      expect(settings.initialQuality, 70);
      expect(settings.minLongSidePx, 800);
      expect(settings.filenamePrefix, 'Image');
    });

    test('filename prefix validation accepts safe values', () {
      expect(ImageSettings.isValidFilenamePrefix('Image'), isTrue);
      expect(ImageSettings.isValidFilenamePrefix('Litchi_Img'), isTrue);
      expect(ImageSettings.isValidFilenamePrefix('Diary-Image_01'), isTrue);
    });

    test('filename prefix validation rejects unsafe values', () {
      expect(ImageSettings.isValidFilenamePrefix(''), isFalse);
      expect(ImageSettings.isValidFilenamePrefix('My Image'), isFalse);
      expect(ImageSettings.isValidFilenamePrefix('Image/2026'), isFalse);
      expect(ImageSettings.isValidFilenamePrefix('图片'), isFalse);
    });
  });

  group('ImageSettingsRepository', () {
    test('save and reload preserves settings', () async {
      final storage = _TestStorage();
      final repo = ImageSettingsRepository(storage: storage);

      await repo.save(
        ImageSettings(
          maxLongSidePx: 1600,
          targetSizeMb: 2,
          initialQuality: 80,
          minLongSidePx: 600,
          filenamePrefix: 'Litchi_Img',
        ),
      );

      final reloaded = await repo.load();
      expect(reloaded.maxLongSidePx, 1600);
      expect(reloaded.targetSizeMb, 2);
      expect(reloaded.initialQuality, 80);
      expect(reloaded.minLongSidePx, 600);
      expect(reloaded.filenamePrefix, 'Litchi_Img');
    });

    test('corrupted JSON falls back to defaults', () async {
      final repo = ImageSettingsRepository(
        storage: _TestStorage({'image_settings': 'broken'}),
      );

      final settings = await repo.load();
      expect(settings.filenamePrefix, 'Image');
      expect(settings.targetSizeMb, 3);
    });

    test('schema mismatch falls back to defaults', () async {
      final repo = ImageSettingsRepository(
        storage: _TestStorage({
          'image_settings': jsonEncode({
            'schemaVersion': 999,
            'filenamePrefix': 'Litchi',
            'targetSizeMb': 1,
          }),
        }),
      );

      final settings = await repo.load();
      expect(settings.filenamePrefix, 'Image');
      expect(settings.targetSizeMb, 3);
    });
  });

  group('ImageCompressService', () {
    const maxBytes = 3 * 1024 * 1024;

    test('compressToBase64 output includes data:image/jpeg;base64, prefix', () {
      final image = img.Image(width: 1, height: 1);
      image.setPixelRgba(0, 0, 255, 0, 0, 255);
      final bytes = img.encodeJpg(image, quality: 90);

      final service = const ImageCompressService();
      final result = service.compressToBase64(bytes);

      expect(result, startsWith('data:image/jpeg;base64,'));
      expect(result.length, greaterThan('data:image/jpeg;base64,'.length));
    });

    test('small image is not enlarged', () {
      final image = img.Image(width: 100, height: 100);
      final bytes = img.encodeJpg(image, quality: 90);

      final service = const ImageCompressService();
      final result = service.compressToBase64(bytes);

      final base64 = result.split(',').last;
      final decoded = img.decodeImage(base64Decode(base64));
      expect(decoded, isNotNull);
      expect(decoded!.width, 100);
      expect(decoded.height, 100);
    });

    test('image over 2000px long side is downsized', () {
      final image = img.Image(width: 4000, height: 3000);
      _fillSolidImage(image);
      final bytes = img.encodeJpg(image, quality: 90);

      final service = const ImageCompressService();
      final result = service.compressToBase64(bytes);

      final base64 = result.split(',').last;
      final decoded = img.decodeImage(base64Decode(base64));
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(2000));
      expect(decoded.height, lessThanOrEqualTo(2000));
    });

    test('uses max long side from image settings', () {
      final image = img.Image(width: 3000, height: 1200);
      _fillSolidImage(image);
      final bytes = img.encodeJpg(image, quality: 90);

      final service = ImageCompressService.fromSettings(
        ImageSettings(maxLongSidePx: 1280),
      );
      final result = service.compressToBase64(bytes);

      final decoded = img.decodeImage(base64Decode(result.split(',').last));
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(1280));
      expect(decoded.height, lessThanOrEqualTo(1280));
    });

    test('uses target size from image settings', () {
      final image = _makeNoisyImage(1200, 1200);
      final bytes = img.encodeJpg(image, quality: 100);

      final service = ImageCompressService.fromSettings(
        ImageSettings(targetSizeMb: 1, minLongSidePx: 600),
      );
      final result = service.compressToBase64(bytes);
      final outputBytes = base64Decode(result.split(',').last);

      expect(outputBytes.length, lessThanOrEqualTo(1 * 1024 * 1024));
    });

    test('uses initial quality from image settings', () {
      final image = _makeNoisyImage(700, 700);
      final bytes = img.encodeJpg(image, quality: 100);

      final lowQuality = ImageCompressService.fromSettings(
        ImageSettings(initialQuality: 50, targetSizeMb: 5),
      ).compressToBase64(bytes);
      final highQuality = ImageCompressService.fromSettings(
        ImageSettings(initialQuality: 90, targetSizeMb: 5),
      ).compressToBase64(bytes);

      expect(
        base64Decode(lowQuality.split(',').last).length,
        lessThan(base64Decode(highQuality.split(',').last).length),
      );
    });

    test('output fits under 3MB for a compressible large image', () {
      // Generate a 3000×2000 image with repeating pattern — highly compressible
      final image = img.Image(width: 3000, height: 2000);
      _fillSolidImage(image);
      final input = img.encodeJpg(image, quality: 95);

      final service = const ImageCompressService();
      final result = service.compressToBase64(input);
      final base64 = result.split(',').last;
      final outputBytes = base64Decode(base64);
      expect(outputBytes.length, lessThanOrEqualTo(maxBytes));
    });

    test('does not hang or crash on noisy incompressible image', () {
      final image = img.Image(width: 200, height: 200);
      final rng = Random(42);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixelRgba(
            x,
            y,
            rng.nextInt(256),
            rng.nextInt(256),
            rng.nextInt(256),
            255,
          );
        }
      }
      final inputBytes = img.encodeJpg(image, quality: 100);
      final service = const ImageCompressService();
      final result = service.compressToBase64(inputBytes);
      expect(result, startsWith('data:image/jpeg;base64,'));
    });

    test('output can be decoded back from base64', () {
      final image = img.Image(width: 500, height: 500);
      _fillSolidImage(image);
      final bytes = img.encodeJpg(image, quality: 90);

      final service = const ImageCompressService();
      final result = service.compressToBase64(bytes);

      final base64 = result.split(',').last;
      final decoded = img.decodeImage(base64Decode(base64));
      expect(decoded, isNotNull);
      expect(decoded!.width, greaterThan(0));
      expect(decoded.height, greaterThan(0));
    });

    test('large uncompressible image returns best-effort and stops', () {
      // Generate a 6000×4000 image filled with noise — nearly incompressible.
      final image = img.Image(width: 6000, height: 4000);
      final rng = Random(42);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixelRgba(
            x,
            y,
            rng.nextInt(256),
            rng.nextInt(256),
            rng.nextInt(256),
            255,
          );
        }
      }
      final inputBytes = img.encodeJpg(image, quality: 95);

      final service = const ImageCompressService();
      final result = service.compressToBase64(inputBytes);

      // Should complete without crash and produce valid output.
      expect(result, startsWith('data:image/jpeg;base64,'));

      final base64 = result.split(',').last;
      final decoded = img.decodeImage(base64Decode(base64));
      expect(decoded, isNotNull);
      // Long side is at most the initial 2000px after first resize.
      expect(decoded!.width, lessThanOrEqualTo(2000));
      expect(decoded.height, lessThanOrEqualTo(2000));
    });
  });

  group('ImageSectionCard', () {
    MediaSection mediaFromText(String text) => const MarkdownParser()
        .parse('## 📸 影像记录\n$text')
        .sections
        .whereType<MediaSection>()
        .single;

    List<String> imageNames(MediaSection section) =>
        section.photos.map((photo) => photo.filename).toList();

    test('Parser extracts single WikiLink', () {
      final filenames = imageNames(
        mediaFromText('![[Image-20260608-001.jpg]]'),
      );
      expect(filenames, ['Image-20260608-001.jpg']);
    });

    test('Parser extracts multiple WikiLinks', () {
      final filenames = imageNames(
        mediaFromText(
          '![[Image-20260608-001.jpg]]\n![[Image-20260608-002.jpg]]',
        ),
      );
      expect(filenames, ['Image-20260608-001.jpg', 'Image-20260608-002.jpg']);
    });

    test('Parser ignores non-wiki Markdown image format', () {
      final filenames = imageNames(mediaFromText('![](path/to/image.jpg)'));
      expect(filenames, isEmpty);
    });

    test('Parser only allows safe image extensions', () {
      final filenames = imageNames(
        mediaFromText(
          '![[safe.jpg]]\n![[unsafe.exe]]\n![[safe.png]]\n![[no-ext]]',
        ),
      );
      expect(filenames, ['safe.jpg', 'safe.png']);
    });

    test('Parser handles PNG, GIF, WebP, HEIC extensions', () {
      final filenames = imageNames(
        mediaFromText(
          '![[a.png]] ![[b.gif]] ![[c.webp]] ![[d.heic]] ![[e.heif]]',
        ),
      );
      expect(filenames, ['a.png', 'b.gif', 'c.webp', 'd.heic', 'e.heif']);
    });

    test('Parser returns empty for empty MediaSection', () {
      final section = MediaSection(title: '## 📸 影像记录', contents: []);
      final filenames = imageNames(section);
      expect(filenames, isEmpty);
    });

    testWidgets('shows empty state when no images', (tester) async {
      final section = MediaSection(title: '## 📸 影像记录', contents: []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: section,
              apiClient: ApiClient(
                ApiConfig(baseUrl: 'https://test.local', token: 'x'),
              ),
              date: DateTime(2026, 6, 8),
            ),
          ),
        ),
      );

      expect(find.text('暂无影像记录'), findsOneWidget);
      expect(find.text('影像记录'), findsOneWidget);
      expect(find.text('## 📸 影像记录'), findsNothing);
      expect(find.byType(JournalSection), findsOneWidget);
      expect(find.byType(SectionCard), findsNothing);
    });

    testWidgets(
      'hides media section when every photo is attached to an entry',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ImageSectionCard(
                section: const MarkdownParser()
                    .parse('''
## ✍️ 随手记 & 灵感
- **08:00** 正文
<!-- litchi-entry-id:11111111-1111-4111-8111-111111111111 -->
## 📸 影像记录
![[attached.jpg]]
<!-- litchi-photo-of:11111111-1111-4111-8111-111111111111;op:22222222-2222-4222-8222-222222222222 -->
''')
                    .sections
                    .whereType<MediaSection>()
                    .single,
                apiClient: ApiClient(
                  ApiConfig(baseUrl: 'https://test.local', token: 'x'),
                ),
                date: DateTime(2026, 6, 8),
              ),
            ),
          ),
        );

        expect(find.byType(JournalSection), findsNothing);
        expect(find.text('暂无影像记录'), findsNothing);
      },
    );

    ApiClient imageTestApiClient() {
      final response = img.encodePng(img.Image(width: 8, height: 8));
      return ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'x'),
        httpClient: MockClient(
          (request) async => http.Response.bytes(
            response,
            200,
            headers: {'content-type': 'image/png'},
          ),
        ),
      );
    }

    testWidgets('同名的独立照片仍显示在影像记录', (tester) async {
      const entryId = '11111111-1111-4111-8111-111111111111';
      const markdown =
          '''
## ✍️ 随手记 & 灵感
- **08:00** 一条记录
<!-- litchi-entry-id:$entryId -->

## 📸 影像记录
![[same.jpg]]
<!-- litchi-photo-of:$entryId;op:22222222-2222-4222-8222-222222222222 -->
![[same.jpg]]
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DiaryMarkdownView(
                markdown: markdown,
                readOnly: true,
                date: DateTime(2026, 6, 8),
                apiClient: imageTestApiClient(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiaryImageThumbnail), findsNWidgets(2));
    });

    testWidgets('小确幸关联照片可在阅读布局中显示', (tester) async {
      const entryId = '11111111-1111-4111-8111-111111111111';
      const markdown =
          '''
## ✨ 每日小确幸
> **09:00** 小确幸正文
<!-- litchi-entry-id:$entryId -->

## 📸 影像记录
![[joy.jpg]]
<!-- litchi-photo-of:$entryId;op:22222222-2222-4222-8222-222222222222 -->
''';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DiaryMarkdownView(
                markdown: markdown,
                readOnly: true,
                date: DateTime(2026, 6, 8),
                apiClient: imageTestApiClient(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiaryImageThumbnail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    MediaSection imageSection(List<String> filenames) {
      final links = filenames.map((f) => '![[$f]]').join('\n');
      return mediaFromText(links);
    }

    testWidgets('uses a two-column square image grid', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ImageSectionCard(
                section: imageSection([
                  'img-001.jpg',
                  'img-002.jpg',
                  'img-003.jpg',
                ]),
                apiClient: imageTestApiClient(),
                date: DateTime(2026, 6, 8),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final images = find.byType(Image);
      expect(images, findsNWidgets(3));
      final first = tester.getSize(images.at(0));
      final second = tester.getSize(images.at(1));
      final third = tester.getSize(images.at(2));
      expect(first.width, closeTo(second.width, 0.01));
      expect(first.height, closeTo(first.width, 0.01));
      expect(third.width, closeTo(first.width, 0.01));
      expect(third.height, closeTo(first.height, 0.01));
      expect(
        tester.getTopLeft(images.at(1)).dx,
        greaterThan(tester.getTopLeft(images.at(0)).dx),
      );
      expect(find.byType(JournalSection), findsOneWidget);
      expect(find.byType(SectionCard), findsNothing);
    });

    testWidgets('thumbnail shows delete menu', (tester) async {
      String? deleted;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
              onDeleteImage: (rawLine) async {
                deleted = rawLine;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip("更多操作"), findsOneWidget);
      expect(deleted, isNull);
    });

    testWidgets('delete shows confirm dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
              onDeleteImage: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip("更多操作"));
      await tester.pumpAndSettle();
      expect(find.byType(FloraGlassSurface), findsOneWidget);
      expect(
        tester.getSize(find.byType(FloraGlassSurface)).height,
        lessThan(140),
      );
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.text('删除照片'), findsOneWidget);
      expect(find.text('将从今日影像记录中删除这张图片'), findsOneWidget);
    });

    testWidgets('cancel delete does not fire callback', (tester) async {
      String? deleted;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
              onDeleteImage: (rawLine) async {
                deleted = rawLine;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip("更多操作"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(deleted, isNull);
    });

    testWidgets('confirm delete fires callback with correct rawLine', (
      tester,
    ) async {
      String? deleted;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['Image-20260608-001.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
              onDeleteImage: (rawLine) async {
                deleted = rawLine;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip("更多操作"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(deleted, '![[Image-20260608-001.jpg]]');
    });

    testWidgets('multi-image delete passes correct rawLine per image', (
      tester,
    ) async {
      String? deleted;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg', 'img-002.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
              onDeleteImage: (rawLine) async {
                deleted = rawLine;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Two thumbnails → two delete menus
      expect(find.byTooltip("更多操作"), findsNWidgets(2));

      // Delete the first image
      await tester.tap(find.byTooltip('更多操作').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(deleted, '![[img-001.jpg]]');
    });

    testWidgets('no delete menu when onDeleteImage is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip("更多操作"), findsNothing);
    });

    testWidgets('tap thumbnail opens preview with close gesture', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg', 'img-002.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final thumbnail = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '预览第 1 张图片',
      );
      final secondThumbnail = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '预览第 2 张图片',
      );
      expect(thumbnail, findsOneWidget);
      expect(secondThumbnail, findsOneWidget);
      expect(tester.getSemantics(thumbnail).flagsCollection.isButton, isTrue);
      expect(
        tester.getSemantics(secondThumbnail).flagsCollection.isButton,
        isTrue,
      );

      // Tap the thumbnail image
      await tester.tap(thumbnail);
      await tester.pumpAndSettle();

      // Should show the full-screen preview image
      expect(find.byType(InteractiveViewer), findsOneWidget);
      final closeButton = find.byTooltip('关闭预览');
      expect(closeButton, findsOneWidget);
      expect(tester.getSize(closeButton), const Size(48, 48));

      // Tap to close
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsNothing);

      // Tapping the dimmed background remains a second, discoverable close path.
      await tester.tap(thumbnail);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 300));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      semanticsHandle.dispose();
    });
  });

  group('Image upload status', () {
    testWidgets('preview distinguishes preparing, real progress, and failure', (
      tester,
    ) async {
      final image = img.Image(width: 8, height: 8);
      _fillSolidImage(image);
      final item = ImageUploadItem(
        id: 'preview',
        file: XFile.fromData(
          Uint8List.fromList(img.encodeJpg(image)),
          name: 'preview.jpg',
          mimeType: 'image/jpeg',
        ),
      );

      Widget buildPreview() {
        return MaterialApp(
          home: Scaffold(
            body: ImageUploadStrip(
              items: [item],
              onRetry: (_) {},
              onRemove: (_) {},
            ),
          ),
        );
      }

      await tester.pumpWidget(buildPreview());
      await tester.pump();
      expect(find.text('待上传'), findsOneWidget);

      item.status = ImageUploadStatus.preparing;
      await tester.pumpWidget(buildPreview());
      expect(find.text('准备中'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(
        find.byKey(const ValueKey('image_preparing_indicator')),
        findsOneWidget,
      );

      item.status = ImageUploadStatus.uploading;
      item.sentBytes = 25;
      item.totalBytes = 100;
      await tester.pumpWidget(buildPreview());
      expect(find.text('25%'), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byKey(const ValueKey('image_upload_progress_indicator')),
      );
      expect(indicator.value, 0.25);

      item.status = ImageUploadStatus.failed;
      await tester.pumpWidget(buildPreview());
      expect(find.text('上传失败\n点击重试'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('ApiClient image', () {
    ApiClient makeImageClient(_CapturingClient client) {
      return ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: client,
      );
    }

    test('uploadImage sends correct payload', () async {
      final client = _CapturingClient();
      final api = makeImageClient(client);

      await api.uploadImage(
        DateTime(2026, 6, 8),
        'data:image/jpeg;base64,abc123',
        imagePrefix: 'Litchi_Img',
      );

      expect(client.lastUrl, contains('/api/v1/diary/image/upload'));
      final body = jsonDecode(client.lastBody!) as Map<String, dynamic>;
      expect(body['date'], '2026-06-08');
      expect(body['imageData'], 'data:image/jpeg;base64,abc123');
      expect(body['imagePrefix'], 'Litchi_Img');
    });

    test(
      'uploadImage reports streamed request bytes as real progress',
      () async {
        final client = _CapturingHttpClient(body: '{"ok":true}');
        final api = ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
          httpClient: client,
        );
        final events = <(int, int)>[];

        await api.uploadImage(
          DateTime(2026, 6, 8),
          'data:image/jpeg;base64,${'a' * (150 * 1024)}',
          onProgress: (sentBytes, totalBytes) {
            events.add((sentBytes, totalBytes));
          },
        );

        expect(events.length, greaterThan(2));
        expect(events.first.$1, 0);
        expect(events.last.$1, events.last.$2);
        expect(events.every((event) => event.$2 == events.last.$2), isTrue);
        for (var index = 1; index < events.length; index++) {
          expect(events[index].$1, greaterThan(events[index - 1].$1));
        }
      },
    );

    test('uploadImage throws on non-200 response', () async {
      final failClient = _CapturingClient(statusCode: 500);
      final failApi = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: failClient,
      );

      expect(
        () => failApi.uploadImage(
          DateTime(2026, 6, 8),
          'data:image/jpeg;base64,test',
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('服务器错误'),
          ),
        ),
      );
    });

    test('testConnection returns readable timeout message', () async {
      final api = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _TimeoutHttpClient(),
      );

      final result = await api.testConnection(DateTime(2026, 6, 8));

      expect(result.success, isFalse);
      expect(result.message, contains('连接超时'));
    });

    test('fetchDiaryImage requests correct URL with month', () async {
      final client = _CapturingClient(
        responseBody: '{"data":"data:image/png;base64,aW1hZ2U="}',
      );
      final api = makeImageClient(client);

      await api.fetchDiaryImage(
        year: 2026,
        month: 6,
        imageName: 'Image-20260608-001.jpg',
      );

      expect(
        client.lastUrl,
        contains('/api/v1/diary/image/2026/Image-20260608-001.jpg'),
      );
      expect(client.lastUrl, contains('month=6'));
    });

    test('fetchDiaryImage returns parsed JSON', () async {
      final client = _CapturingClient(
        responseBody:
            '{"data":"data:image/jpeg;base64,test123","mimeType":"image/jpeg"}',
      );
      final api = makeImageClient(client);

      final result = await api.fetchDiaryImage(
        year: 2026,
        month: 6,
        imageName: 'Image-20260608-001.jpg',
      );

      expect(result['data'], 'data:image/jpeg;base64,test123');
      expect(result['mimeType'], 'image/jpeg');
    });
  });
}
