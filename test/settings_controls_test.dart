import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:litchi_journal_flutter/screens/image_compress_page.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_sheet.dart';
import 'package:litchi_journal_flutter/screens/reading_cache_page.dart';
import 'package:litchi_journal_flutter/services/reading_cache_repository.dart';

class _Cache extends ReadingCacheRepository {
  @override
  Future<ReadingCacheUsage> usage() async => const ReadingCacheUsage(0, 0);
}

void main() {
  for (final scale in [1.0, 2.0, 4.0]) {
    testWidgets('缓存按钮320dp大字$scale保持同行等宽等高', (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ReadingCachePage(repository: _Cache()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, '清除图片缓存'),
        300,
      );
      await tester.pumpAndSettle();
      final left = tester.getRect(
        find.widgetWithText(OutlinedButton, '清除图片缓存'),
      );
      final right = tester.getRect(
        find.widgetWithText(OutlinedButton, '清除全部阅读缓存'),
      );
      expect(left.top, right.top);
      expect(left.size, right.size);
      expect(right.left - left.right, 12);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('底部抽屉从下方滑入并向下关闭', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showFloraSheet<void>(
                context: context,
                slideFromBottom: true,
                builder: (_) => const SizedBox(
                  key: Key('sheet-content'),
                  width: 300,
                  height: 200,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final entering = tester
        .getTopLeft(find.byKey(const Key('sheet-content')))
        .dy;
    await tester.pumpAndSettle();
    final settled = tester
        .getTopLeft(find.byKey(const Key('sheet-content')))
        .dy;
    expect(entering, greaterThan(settled));
    Navigator.of(tester.element(find.byKey(const Key('sheet-content')))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.getTopLeft(find.byKey(const Key('sheet-content'))).dy,
      greaterThan(settled),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sheet-content')), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets('图片设置原位展开与圆角按钮 ${dark ? "深色" : "浅色"}', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: const ImageCompressPage(),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, '恢复默认');
      final context = tester.element(button);
      final shape =
          Theme.of(context).outlinedButtonTheme.style!.shape!.resolve({})
              as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      await tester.tap(find.text('2000 px'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile).hitTestable(), findsWidgets);
      await tester.tap(find.text('2000 px').last);
      await tester.pumpAndSettle();
      expect(find.byType(ListTile).hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
