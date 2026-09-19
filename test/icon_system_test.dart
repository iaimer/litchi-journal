import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:litchi_journal_flutter/screens/about_page.dart';
import 'package:litchi_journal_flutter/widgets/flora_animated_icon.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/flora_success_snackbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lucide and Lordicon assets', () {
    test(
      'all registered non-brand icons resolve to bundled resources',
      () async {
        for (final name in FloraIcons.all) {
          if (_isBrandAsset(name)) continue;
          final path = FloraIcons.path(name);
          expect(path, isNotEmpty, reason: '$name must have a resource path');
          expect(
            await rootBundle.loadString(path),
            isNotEmpty,
            reason: '$name must load from the app bundle',
          );
        }
      },
    );

    test('product and habit logical names map to the approved Lucide set', () {
      const expected = <String, String>{
        'diary': 'notebook-pen',
        'history': 'images',
        'habits': 'sprout',
        'settings': 'settings',
        'coach': 'sparkles',
        'fab-write': 'pen-line',
        'fab-insight': 'eye',
        'fab-happy': 'sparkles',
        'fab-anxiety': 'cloud-rain',
        'fab-photo': 'image-plus',
        'setting-appearance': 'palette',
        'setting-habits': 'list-checks',
        'setting-tags': 'tags',
        'setting-cloud': 'server-cog',
        'setting-ai': 'bot',
        'setting-prompt': 'message-square-text',
        'setting-image': 'image',
        'setting-about': 'info',
        'habit-water': 'glass-water',
        'habit-walk': 'footprints',
        'habit-read': 'book-open',
        'habit-language': 'languages',
        'habit-pill': 'pill',
        'candidate-run': 'activity',
        'candidate-sprout': 'sprout',
        'candidate-star': 'star',
        'candidate-sun': 'sunrise',
        'candidate-moon': 'moon',
        'candidate-meditate': 'flower-2',
        'candidate-lift': 'dumbbell',
        'candidate-apple': 'apple',
        'candidate-books': 'library',
        'pin': 'pin',
        'warning': 'triangle-alert',
        'chat-feedback': 'message-circle-heart',
        'question': 'message-circle-question',
        'reward': 'award',
        'target': 'target',
      };

      for (final entry in expected.entries) {
        expect(
          FloraIcons.path(entry.key),
          'assets/icons/lucide/${entry.value}.svg',
          reason: '${entry.key} must retain its logical name',
        );
      }
    });

    test('Lucide resources keep the official 24px stroke geometry', () async {
      final paths = FloraIcons.all
          .map(FloraIcons.path)
          .where((path) => path.startsWith('assets/icons/lucide/'))
          .toSet();

      expect(paths, isNotEmpty);
      for (final path in paths) {
        final svg = await rootBundle.loadString(path);
        expect(svg, contains('width="24"'), reason: path);
        expect(svg, contains('height="24"'), reason: path);
        expect(svg, contains('viewBox="0 0 24 24"'), reason: path);
        expect(svg, contains('fill="none"'), reason: path);
        expect(svg, contains('stroke="currentColor"'), reason: path);
        expect(svg, contains('stroke-width="2"'), reason: path);
        expect(svg, contains('stroke-linecap="round"'), reason: path);
        expect(svg, contains('stroke-linejoin="round"'), reason: path);
      }
    });

    test('brand icon and splash assets remain unchanged', () {
      expect(FloraIcons.path(FloraIcons.brandIcon), 'assets/icon/app-icon.png');
      expect(
        FloraIcons.path(FloraIcons.brandSplash),
        'assets/icon/brand-splash-reference.png',
      );
      expect(
        FloraIcons.path(FloraIcons.brandSplashDark),
        'assets/icon/brand-splash-dark.png',
      );
    });

    test(
      'Lordicon Lottie files contain only the downloaded in-reveal state',
      () async {
        for (final asset in [
          'assets/icons/lordicon/system-outline-4092-book.json',
          'assets/icons/lordicon/system-outline-37-check.json',
        ]) {
          final document = jsonDecode(await rootBundle.loadString(asset));
          final markers = (document as Map<String, dynamic>)['markers'] as List;
          expect(markers, hasLength(1), reason: asset);
          expect(markers.single['cm'], 'default:in-reveal', reason: asset);
        }
      },
    );

    test('both animations parse with the bundled Lottie engine', () async {
      for (final asset in [
        'assets/icons/lordicon/system-outline-4092-book.json',
        'assets/icons/lordicon/system-outline-37-check.json',
      ]) {
        final composition = await AssetLottie(asset).load();
        expect(composition.getMarker('default:in-reveal'), isNotNull);
      }
    });
  });

  group('Lordicon playback', () {
    testWidgets('reduced motion uses the static SVG without a player', (
      tester,
    ) async {
      final bundle = _RecordingAssetBundle();
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: bundle,
            child: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: FloraAnimatedIcon(
                name: FloraAnimatedIconName.emptyBook,
                color: Colors.teal,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Lottie), findsNothing);
      expect(find.byType(FloraIcon), findsOneWidget);
      expect(
        bundle.requestedAssets.where((asset) => asset.endsWith('.json')),
        isEmpty,
      );
    });

    testWidgets('both local animations load through Lottie', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloraAnimatedIcon(name: FloraAnimatedIconName.emptyBook),
              FloraAnimatedIcon(name: FloraAnimatedIconName.successCheck),
            ],
          ),
        ),
      );
      await _pumpUntilLotties(tester, 2);
      expect(find.byType(Lottie), findsNWidgets(2));
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('animation plays once and its ticker disposes cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FloraAnimatedIcon(
            name: FloraAnimatedIconName.successCheck,
            color: Colors.teal,
          ),
        ),
      );
      await _pumpUntilLotties(tester, 1);
      final animation = tester.widget<Lottie>(find.byType(Lottie));
      expect(animation.animate, isTrue);
      expect(animation.repeat, isFalse);
      expect(animation.reverse, isFalse);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed local animation load falls back to its SVG', (
      tester,
    ) async {
      final bundle = _FailingAssetBundle(
        'assets/icons/lordicon/system-outline-37-check.json',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: bundle,
            child: const FloraAnimatedIcon(
              name: FloraAnimatedIconName.successCheck,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Lottie), findsNothing);
      expect(find.byType(FloraIcon), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('success SnackBar keeps its original message and check icon', (
      tester,
    ) async {
      const message = '已保存';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showFloraSuccessSnackBar(context, message),
                child: const Text('触发'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('触发'));
      await _pumpUntilLotties(tester, 1);
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.byType(FloraAnimatedIcon), findsOneWidget);
      expect(find.byType(Lottie), findsOneWidget);
    });
  });

  group('FloraIcon theme inheritance', () {
    testWidgets('uses inherited color and size unless explicitly overridden', (
      tester,
    ) async {
      expect(const FloraIcon(FloraIcons.settings).size, 24);
      expect(const FloraIcon(FloraIcons.settings, size: 20).size, 20);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IconTheme(
              data: IconThemeData(color: Colors.teal, size: 18),
              child: FloraIcon(FloraIcons.settings),
            ),
          ),
        ),
      );

      var svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, 18);
      expect(
        svg.colorFilter,
        const ColorFilter.mode(Colors.teal, BlendMode.srcIn),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IconTheme(
              data: IconThemeData(color: Colors.teal, size: 18),
              child: FloraIcon(
                FloraIcons.settings,
                size: 20,
                color: Colors.deepOrange,
              ),
            ),
          ),
        ),
      );

      svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, 20);
      expect(
        svg.colorFilter,
        const ColorFilter.mode(Colors.deepOrange, BlendMode.srcIn),
      );
    });

    testWidgets('follows enabled and disabled button foreground colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.white,
                    iconSize: 18,
                  ),
                  icon: const FloraIcon(FloraIcons.check),
                  label: const Text('完成'),
                ),
                FilledButton.icon(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    disabledForegroundColor: Colors.orange,
                    iconSize: 16,
                  ),
                  icon: const FloraIcon(FloraIcons.check),
                  label: const Text('不可用'),
                ),
              ],
            ),
          ),
        ),
      );

      final icons = find.byType(SvgPicture);
      final enabled = tester.widget<SvgPicture>(icons.at(0));
      final disabled = tester.widget<SvgPicture>(icons.at(1));
      expect(enabled.width, 18);
      expect(
        enabled.colorFilter,
        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
      expect(disabled.width, 16);
      expect(
        disabled.colorFilter,
        const ColorFilter.mode(Colors.orange, BlendMode.srcIn),
      );
    });
  });

  testWidgets(
    'About page links Lordicon attribution and reports open failures',
    (tester) async {
      const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, (call) async => false);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(launcherChannel, null),
      );

      await tester.pumpWidget(const MaterialApp(home: AboutPage()));
      await tester.pump();

      expect(find.text('图标来源'), findsNothing);

      final aboutList = tester.widget<ListView>(find.byType(ListView).first);
      final childrenDelegate = aboutList.childrenDelegate;
      expect(childrenDelegate, isA<SliverChildListDelegate>());
      expect(
        (childrenDelegate as SliverChildListDelegate).children.last.key,
        const Key('about_icon_attribution_footer'),
      );

      await tester.scrollUntilVisible(
        find.text('Static icons: Lucide Icons'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Static icons: Lucide Icons'), findsOneWidget);
      expect(find.text('Animated icons by Lordicon.com'), findsOneWidget);

      final staticAttribution = tester.widget<Text>(
        find.text('Static icons: Lucide Icons'),
      );
      final lordiconAttribution = tester.widget<Text>(
        find.text('Animated icons by Lordicon.com'),
      );
      for (final attribution in [staticAttribution, lordiconAttribution]) {
        expect(attribution.style?.fontSize, 12);
        expect(attribution.style?.color?.a, closeTo(0.82, 0.01));
      }

      await tester.ensureVisible(find.text('Animated icons by Lordicon.com'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Animated icons by Lordicon.com'));
      await tester.pumpAndSettle();

      expect(find.text('暂时无法打开链接'), findsOneWidget);
    },
  );

  group('migration completeness', () {
    test('app source no longer selects Material or legacy SVG icons', () async {
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      final violations = <String>[];
      for (final file in dartFiles) {
        final source = await file.readAsString();
        if (RegExp(r'(?<![A-Za-z0-9_])Icons\.[A-Za-z0-9_]+').hasMatch(source)) {
          violations.add('${file.path}: Material Icons reference');
        }
        if (source.contains('assets/svg/') ||
            source.contains('svgrepo-com') ||
            RegExp(r'flora-[a-z-]+\.svg').hasMatch(source)) {
          violations.add('${file.path}: legacy SVG reference');
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}

bool _isBrandAsset(String name) =>
    name.startsWith('brand-') || name == 'brand-icon';

Future<void> _pumpUntilLotties(WidgetTester tester, int count) async {
  final animation = find.byType(Lottie);
  for (var attempt = 0; attempt < 40; attempt++) {
    if (animation.evaluate().length >= count) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _RecordingAssetBundle extends CachingAssetBundle {
  final requestedAssets = <String>[];

  @override
  Future<ByteData> load(String key) {
    requestedAssets.add(key);
    return rootBundle.load(key);
  }
}

class _FailingAssetBundle extends _RecordingAssetBundle {
  _FailingAssetBundle(this.failedAsset);

  final String failedAsset;

  @override
  Future<ByteData> load(String key) {
    if (key == failedAsset) {
      requestedAssets.add(key);
      return Future<ByteData>.error(const FormatException('asset unavailable'));
    }
    return super.load(key);
  }
}
