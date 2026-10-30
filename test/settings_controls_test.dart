import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:litchi_journal_flutter/screens/image_compress_page.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_sheet.dart';

void main() {
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
