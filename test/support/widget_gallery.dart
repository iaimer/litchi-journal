part of '../widget_test.dart';

void registerGalleryTests() {
  group('Gallery data layer', () {
    test('Gallery models preserve month stats and all image names', () {
      final page = GalleryPage.fromJson({
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
                'hasContent': false,
              },
            ],
          },
        ],
        'nextCursor': '2024-02',
      });

      expect(page.nextCursor, '2024-02');
      expect(page.months.single.totalDays, 1);
      expect(page.months.single.totalImages, 2);
      expect(page.months.single.days.single.images, [
        'first.jpg',
        'second.jpg',
      ]);
      expect(page.months.single.days.single.hasContent, isFalse);
    });

    test('Gallery API client sends cursor and rendered image width', () async {
      final fake = _GalleryHttpClient(
        galleryBody: '{"months":[],"nextCursor":null}',
        imageBytes: Uint8List.fromList([1, 2, 3]),
      );
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: fake,
      );

      final page = await client.fetchGallery(cursor: '2024-03', limit: 2);
      final bytes = await client.fetchRenderedDiaryImage(
        year: 2024,
        month: 3,
        imageName: 'first photo.jpg',
        maxWidth: 1600,
      );

      expect(page.months, isEmpty);
      expect(bytes, [1, 2, 3]);
      expect(fake.requests[0].queryParameters, {
        'limit': '2',
        'cursor': '2024-03',
      });
      expect(
        fake.requests[1].path,
        contains('/image/render/2024/first%20photo.jpg'),
      );
      expect(fake.requests[1].queryParameters, {
        'month': '3',
        'maxWidth': '1600',
      });
    });

    test(
      'Gallery image cache evicts the oldest thumbnail after 60 entries',
      () async {
        final fake = _GalleryHttpClient(
          galleryBody: '{"months":[],"nextCursor":null}',
          imageBytes: Uint8List.fromList([1, 2, 3]),
        );
        final service = GalleryService(
          ApiClient(
            ApiConfig(baseUrl: 'https://test.local', token: 'test'),
            httpClient: fake,
          ),
        );
        final day = GalleryDay(
          date: '2024-03-08',
          images: const ['first.jpg'],
          hasContent: false,
        );

        for (var index = 0; index < 61; index++) {
          await service.loadImage(
            day: day,
            imageName: 'image-$index.jpg',
            maxWidth: 480,
          );
        }
        expect(fake.requests, hasLength(61));

        await service.loadImage(
          day: day,
          imageName: 'image-0.jpg',
          maxWidth: 480,
        );
        expect(fake.requests, hasLength(62));

        await service.loadImage(
          day: day,
          imageName: 'preview.jpg',
          maxWidth: 1600,
        );
        await service.loadImage(
          day: day,
          imageName: 'preview.jpg',
          maxWidth: 1600,
        );
        expect(fake.requests, hasLength(64));
      },
    );

    test(
      'forcing a thumbnail reload evicts the previous cached bytes',
      () async {
        final fake = _GalleryHttpClient(
          galleryBody: '{"months":[],"nextCursor":null}',
          imageBytes: Uint8List.fromList([1, 2, 3]),
        );
        final service = GalleryService(
          ApiClient(
            ApiConfig(baseUrl: 'https://test.local', token: 'test'),
            httpClient: fake,
          ),
        );
        const day = GalleryDay(
          date: '2024-03-08',
          images: ['first.jpg'],
          hasContent: false,
        );

        expect(
          await service.loadImage(
            day: day,
            imageName: 'first.jpg',
            maxWidth: 480,
          ),
          [1, 2, 3],
        );
        fake.imageBytes = Uint8List.fromList([4, 5, 6]);

        expect(
          await service.loadImage(
            day: day,
            imageName: 'first.jpg',
            maxWidth: 480,
            forceRefresh: true,
          ),
          [4, 5, 6],
        );
        expect(
          await service.loadImage(
            day: day,
            imageName: 'first.jpg',
            maxWidth: 480,
          ),
          [4, 5, 6],
        );
        expect(
          fake.requests.where(
            (request) => request.path.startsWith('/api/v1/diary/image/render/'),
          ),
          hasLength(2),
        );
      },
    );

    testWidgets('failed gallery thumbnails can be retried from the network', (
      tester,
    ) async {
      final image = img.Image(width: 2, height: 2);
      final fake = _GalleryHttpClient(
        galleryBody: '{"months":[],"nextCursor":null}',
        imageBytes: Uint8List.fromList([1, 2, 3]),
      );
      final service = GalleryService(
        ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
          httpClient: fake,
        ),
      );
      const day = GalleryDay(
        date: '2024-03-08',
        images: ['first.jpg'],
        hasContent: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GalleryImageTile(
              day: day,
              galleryService: service,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('点击重试'), findsOneWidget);

      fake.imageBytes = Uint8List.fromList(img.encodeJpg(image));
      await tester.tap(find.text('点击重试'));
      await tester.pumpAndSettle();

      expect(find.text('点击重试'), findsNothing);
      expect(
        fake.requests.where(
          (request) => request.path.startsWith('/api/v1/diary/image/render/'),
        ),
        hasLength(2),
      );
    });

    testWidgets('404 gallery thumbnails show unavailable state without retry', (
      tester,
    ) async {
      final service = GalleryService(
        ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
          httpClient: _GalleryHttpClient(
            galleryBody: '{"months":[],"nextCursor":null}',
            imageBytes: Uint8List.fromList([1, 2, 3]),
            imageStatusCode: 404,
          ),
        ),
      );
      const day = GalleryDay(
        date: '2024-03-08',
        images: ['first.jpg'],
        hasContent: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GalleryImageTile(
              day: day,
              galleryService: service,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('图片不可用'), findsOneWidget);
      expect(find.text('点击重试'), findsNothing);
    });

    testWidgets('gallery date badge does not cover the whole tile width', (
      tester,
    ) async {
      final image = img.Image(width: 2, height: 2);
      final service = GalleryService(
        ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
          httpClient: _GalleryHttpClient(
            galleryBody: '{"months":[],"nextCursor":null}',
            imageBytes: Uint8List.fromList(img.encodeJpg(image)),
          ),
        ),
      );
      const day = GalleryDay(
        date: '2024-03-08',
        images: ['first.jpg'],
        hasContent: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GalleryImageTile(
              day: day,
              galleryService: service,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badge = find.byKey(const ValueKey('gallery_day_badge_2024-03-08'));
      expect(badge, findsOneWidget);
      expect(tester.getSize(badge).height, lessThan(32));
      expect(tester.getSize(badge).width, lessThan(80));
    });
  });
}
