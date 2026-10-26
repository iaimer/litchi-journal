import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/main.dart' as app;
import 'package:litchi_journal_flutter/screens/read_only_diary_screen.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/journal_section.dart';

import 'support/consistent_entry_diary.dart';

const _export = bool.fromEnvironment('WRITE_TIMELINE_PREVIEW');
const _fontPath = String.fromEnvironment('TIMELINE_PREVIEW_FONT');
const _previewKey = Key('timeline_page_preview');

ApiClient _client() => ApiClient(
  ApiConfig(baseUrl: 'http://example.invalid', token: 'timeline-test'),
  httpClient: MockClient((request) async {
    expect(request.method, 'GET');
    if (request.url.path.startsWith('/api/v1/diary/')) {
      return http.Response(
        jsonEncode({
          'date': request.url.path.split('/').last,
          'raw': consistentEntryDiary,
          'sections': {},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('{}', 404);
  }),
);

Future<void> _mountPage(WidgetTester tester, bool historical, bool dark) async {
  FlutterSecureStorage.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final client = _client();
  addTearDown(client.dispose);
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await tester.pumpWidget(
    MaterialApp(
      theme: _export
          ? theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'TimelinePreview'),
            )
          : theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: const Size(390, 844),
          padding: const EdgeInsets.only(top: 24, bottom: 24),
        ),
        child: RepaintBoundary(key: _previewKey, child: child!),
      ),
      home: historical
          ? ReadOnlyDiaryScreen(date: DateTime(2026, 10, 20), apiClient: client)
          : app.MainScreen(apiClient: client, onApiConfigChanged: (_) {}),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _savePreview(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  final frame = await boundary.toImage(pixelRatio: 2);
  try {
    final bytes = (await frame.toByteData(format: ui.ImageByteFormat.png))!;
    final folder = await Directory(
      'build/consistent-entry-timeline-preview',
    ).create(recursive: true);
    await File(
      '${folder.path}/$name.png',
    ).writeAsBytes(bytes.buffer.asUint8List());
  } finally {
    frame.dispose();
  }
}

void main() {
  if (_export) {
    setUpAll(() async {
      if (_fontPath.isEmpty) throw StateError('请提供 TIMELINE_PREVIEW_FONT');
      final font = FontLoader('TimelinePreview')
        ..addFont(
          Future.value(
            ByteData.sublistView(await File(_fontPath).readAsBytes()),
          ),
        );
      await font.load();
    });
  }
  for (final historical in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('实际页面历史=$historical dark=$dark 三模块时间一致', (tester) async {
        await _mountPage(tester, historical, dark);
        expect(find.byType(JournalTimelineRow), findsNWidgets(3));
        for (final time in ['08:10', '09:20', '10:30']) {
          expect(find.text(time), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        if (_export) {
          await tester.runAsync(
            () => _savePreview(
              tester,
              '${historical ? 'history' : 'today'}-${dark ? 'dark' : 'light'}',
            ),
          );
        }
      });
    }
  }
}
