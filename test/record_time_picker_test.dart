import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/models/quick_capture_submission.dart';
import 'package:litchi_journal_flutter/screens/quick_capture_screen.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/entry_type.dart';

Widget _buildCapture({
  DateTime? recordDate,
  DateTime? openedAt,
  String? initialTime = '17:24',
  String? initialContent,
  Future<void> Function(QuickCaptureSubmission)? onSave,
  ThemeData? theme,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: QuickCaptureScreen(
          entryType: EntryType.quickNote,
          openedAt: openedAt ?? DateTime(2026, 7, 31, 8, 5),
          recordDate: recordDate,
          initialTime: initialTime,
          initialContent: initialContent,
          onSave: onSave ?? (_) async {},
        ),
      ),
    ),
  );
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('quick_capture_time_metadata')));
  await tester.pumpAndSettle();
}

Future<void> _scrollWheel(WidgetTester tester, Key key) async {
  await tester.drag(find.byKey(key), const Offset(0, -48));
  await tester.pumpAndSettle();
}

String _semanticsValue(WidgetTester tester, Key key) {
  return tester.getSemantics(find.byKey(key)).value;
}

void main() {
  testWidgets(
    'new today entry starts at its captured time and unfocuses editor',
    (tester) async {
      await tester.pumpWidget(
        _buildCapture(
          recordDate: null,
          openedAt: DateTime(2026, 9, 26, 8, 5),
          initialTime: null,
        ),
      );
      await tester.pumpAndSettle();
      final editorFocusNode = tester
          .widget<TextField>(find.byType(TextField))
          .focusNode!;
      expect(editorFocusNode.hasFocus, isTrue);

      await _openPicker(tester);

      expect(
        _semanticsValue(tester, const Key('record_time_hour_value')),
        '08点',
      );
      expect(
        _semanticsValue(tester, const Key('record_time_minute_value')),
        '05分',
      );
      expect(find.text('2026年9月26日'), findsOneWidget);
      expect(editorFocusNode.hasFocus, isFalse);
      await tester.tap(find.byKey(const Key('record_time_cancel')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('opens the wheel picker with the fixed target date', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCapture(recordDate: DateTime(2026, 7, 10)));

    await _openPicker(tester);

    expect(find.text('选择发生时间'), findsOneWidget);
    expect(find.text('2026年7月10日'), findsOneWidget);
    expect(find.byKey(const Key('record_time_hour_wheel')), findsOneWidget);
    expect(find.byKey(const Key('record_time_minute_wheel')), findsOneWidget);
    expect(find.byKey(const Key('record_time_cancel')), findsOneWidget);
    expect(find.byKey(const Key('record_time_confirm')), findsOneWidget);
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.showDragHandle, isTrue);
    expect(
      tester.getCenter(find.text('选择发生时间')).dx,
      closeTo(tester.getCenter(find.text('2026年7月10日')).dx, 1),
    );
    for (final picker in tester.widgetList<CupertinoPicker>(
      find.byType(CupertinoPicker),
    )) {
      expect(picker.useMagnifier, isTrue);
      expect(picker.magnification, greaterThan(1));
    }
  });

  testWidgets('editing a record preselects its stored time and target date', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _buildCapture(
        recordDate: DateTime(2026, 3, 7),
        initialTime: '09:30',
        initialContent: '已有记录',
      ),
    );
    await _openPicker(tester);

    expect(find.text('2026年3月7日'), findsOneWidget);
    expect(_semanticsValue(tester, const Key('record_time_hour_value')), '09点');
    expect(
      _semanticsValue(tester, const Key('record_time_minute_value')),
      '30分',
    );

    await tester.tap(find.byKey(const Key('record_time_cancel')));
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('cancel keeps the existing time after staged wheel changes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_buildCapture(recordDate: DateTime(2026, 7, 10)));

    await _openPicker(tester);

    expect(_semanticsValue(tester, const Key('record_time_hour_value')), '17点');
    expect(
      _semanticsValue(tester, const Key('record_time_minute_value')),
      '24分',
    );

    await _scrollWheel(tester, const Key('record_time_hour_wheel'));
    await _scrollWheel(tester, const Key('record_time_minute_wheel'));

    expect(_semanticsValue(tester, const Key('record_time_hour_value')), '18点');
    expect(
      _semanticsValue(tester, const Key('record_time_minute_value')),
      '25分',
    );

    await tester.tap(find.byKey(const Key('record_time_cancel')));
    await tester.pumpAndSettle();

    expect(find.text('2026年7月10日 17:24'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'confirmed wheel time is saved without changing the target date',
    (tester) async {
      String? savedTime;
      await tester.pumpWidget(
        _buildCapture(
          recordDate: DateTime(2026, 7, 10),
          onSave: (submission) async => savedTime = submission.time,
        ),
      );

      await _openPicker(tester);
      expect(find.text('2026年7月10日'), findsOneWidget);

      await _scrollWheel(tester, const Key('record_time_hour_wheel'));
      await _scrollWheel(tester, const Key('record_time_minute_wheel'));
      await tester.tap(find.byKey(const Key('record_time_confirm')));
      await tester.pumpAndSettle();

      expect(find.text('2026年7月10日 18:25'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '历史补录');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();

      expect(savedTime, '18:25');
    },
  );

  testWidgets('wheel keeps midnight in 24-hour format', (tester) async {
    await tester.pumpWidget(
      _buildCapture(recordDate: DateTime(2026, 7, 10), initialTime: '00:00'),
    );
    await _openPicker(tester);
    expect(find.byKey(const Key('record_time_hour_wheel')), findsOneWidget);
    expect(find.byKey(const Key('record_time_minute_wheel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('record_time_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('2026年7月10日 00:00'), findsOneWidget);
  });

  testWidgets('wheel keeps end-of-day time in 24-hour format', (tester) async {
    await tester.pumpWidget(
      _buildCapture(recordDate: DateTime(2026, 7, 10), initialTime: '23:59'),
    );
    await _openPicker(tester);
    expect(find.byKey(const Key('record_time_hour_wheel')), findsOneWidget);
    expect(find.byKey(const Key('record_time_minute_wheel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('record_time_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('2026年7月10日 23:59'), findsOneWidget);
  });

  testWidgets('tapping outside dismisses without applying a staged time', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCapture(recordDate: DateTime(2026, 7, 10)));
    await _openPicker(tester);
    await _scrollWheel(tester, const Key('record_time_hour_wheel'));

    await tester.tapAt(const Offset(16, 16));
    await tester.pumpAndSettle();

    expect(find.text('选择发生时间'), findsNothing);
    expect(find.text('2026年7月10日 17:24'), findsOneWidget);
  });

  testWidgets('system back dismisses without applying a staged time', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCapture(recordDate: DateTime(2026, 7, 10)));
    await _openPicker(tester);
    await _scrollWheel(tester, const Key('record_time_minute_wheel'));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('选择发生时间'), findsNothing);
    expect(find.text('2026年7月10日 17:24'), findsOneWidget);
  });

  testWidgets(
    'dark theme and large text keep picker actions visible on narrow screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildCapture(
          recordDate: DateTime(2026, 7, 10),
          theme: AppTheme.dark,
          textScale: 1.6,
        ),
      );
      await _openPicker(tester);

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, AppColors.darkSurface);
      expect(tester.getSize(find.byType(BottomSheet)).height, greaterThan(500));
      expect(find.byKey(const Key('record_time_cancel')), findsOneWidget);
      expect(find.byKey(const Key('record_time_confirm')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('record_time_confirm'))).bottom,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
