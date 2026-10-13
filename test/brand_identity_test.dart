import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:litchi_journal_flutter/screens/about_page.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_brand_identity.dart';
import 'package:litchi_journal_flutter/widgets/flora_splash.dart';

void main() {
  test('品牌母版保留透明外部、浅色书页和抗锯齿边缘', () {
    final master = img.decodePng(
      File('docs/design-reference/brand-c-master.png').readAsBytesSync(),
    )!;
    expect(master.width, 517);
    expect(master.height, 373);
    expect(master.getPixel(0, 0).a, 0);
    expect(master.getPixel(100, 220).a, 255);
    // 批准图提取时书底外的阴影残留，不属于图形或轮廓抗锯齿。
    expect(master.getPixel(129, 330).a, 0);
    expect(master.getPixel(205, 350).a, 0);
    expect(master.any((pixel) => pixel.a > 0 && pixel.a < 255), isTrue);
    expect(
      File('assets/icon/app-icon.png').readAsBytesSync(),
      File('docs/design-reference/brand-c-master.png').readAsBytesSync(),
    );
  });

  for (final density in {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  }.entries) {
    test('Android ${density.key} 前景全部非透明像素落在安全圆内', () {
      final foreground = img.decodePng(
        File(
          'android/app/src/main/res/mipmap-${density.key}/'
          'ic_launcher_foreground_bitmap.png',
        ).readAsBytesSync(),
      )!;
      final side = (108 * density.value).round();
      expect(foreground.width, side);
      expect(foreground.height, side);
      var maxRadius = 0.0;
      for (final pixel in foreground) {
        if (pixel.a == 0) continue;
        final dx = pixel.x + 0.5 - side / 2;
        final dy = pixel.y + 0.5 - side / 2;
        maxRadius = math.max(
          maxRadius,
          math.sqrt(dx * dx + dy * dy) / density.value,
        );
      }
      expect(maxRadius, lessThanOrEqualTo(33));
    });
  }

  test('iOS 图标全尺寸有效且使用不透明浅白背景', () {
    const directory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final catalog =
        jsonDecode(File('$directory/Contents.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final item in catalog['images'] as List) {
      final size =
          (double.parse((item['size'] as String).split('x').first) *
                  double.parse((item['scale'] as String).replaceAll('x', '')))
              .round();
      final icon = img.decodePng(
        File('$directory/${item['filename']}').readAsBytesSync(),
      )!;
      expect(icon.width, size);
      expect(icon.height, size);
      expect(icon.numChannels, 3);
      expect(icon.getPixel(0, 0).r, 250);
    }
  });

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: '荔枝日记',
      packageName: 'com.example.litchi_journal_flutter',
      version: '1.9.0',
      buildNumber: '39',
      buildSignature: '',
    );
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3]) {
      for (final splash in [false, true]) {
        testWidgets('品牌图宽度与间距：dark=$dark scale=$scale splash=$splash', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: splash
                  ? FloraSplash(onDone: () {}, ready: false)
                  : const AboutPage(),
            ),
          );
          await tester.pumpAndSettle();
          final image = tester.getRect(
            find.byKey(const ValueKey('brand_identity_image')),
          );
          final title = tester.getRect(find.text('荔枝日记'));
          expect(image.width, closeTo(title.width * 0.95, 0.01));
          expect(image.height, greaterThan(0));
          expect(image.center.dx, closeTo(title.center.dx, 0.01));
          expect(title.top - image.bottom, closeTo(splash ? 24 : 20, 0.01));
          expect(image.left, greaterThanOrEqualTo(24));
          expect(image.right, lessThanOrEqualTo(296));
          expect(find.byType(FloraBrandIdentity), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets('启动等待最短展示和 ready，不重复完成', (tester) async {
    var completed = 0;
    Widget page(bool ready) => MaterialApp(
      home: FloraSplash(onDone: () => completed++, ready: ready),
    );
    await tester.pumpWidget(page(false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(completed, 0);
    await tester.pumpWidget(page(true));
    await tester.pump();
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(completed, 1);
  });
}
