import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:litchi_journal_flutter/screens/quick_capture_screen.dart';
import 'package:litchi_journal_flutter/widgets/entry_type.dart';
import 'package:litchi_journal_flutter/models/default_tag_config.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/services/picker_cache_cleanup.dart';

void main() {
  test('仅清理选图器在指定缓存根目录内的普通 scaled 文件', () async {
    final root = await Directory.systemTemp.createTemp('litchi-picker-clean-');
    try {
      final owned = await File(
        '${root.path}/scaled_photo.jpg',
      ).writeAsString('temp');
      final original = await File(
        '${root.path}/photo.jpg',
      ).writeAsString('original');
      final nested = await Directory('${root.path}/other').create();
      final outside = await File(
        '${nested.path}/scaled_photo.jpg',
      ).writeAsString('keep');
      final link = await Link(
        '${root.path}/scaled_link.jpg',
      ).create(original.path);
      for (final path in [owned.path, original.path, outside.path, link.path]) {
        await deletePickerCacheFile(path, cacheDirectory: root);
      }
      expect(await owned.exists(), isFalse);
      expect(await original.readAsString(), 'original');
      expect(await outside.exists(), isTrue);
      expect(await link.exists(), isTrue);
    } finally {
      await root.delete(recursive: true);
    }
  });

  testWidgets('系统选图返回前离开页面仍清理本次缩放缓存', (tester) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('litchi-picker-lifecycle-'),
    ))!;
    final file = (await tester.runAsync(
      () => File('${root.path}/scaled_pending.jpg').writeAsString('temporary'),
    ))!;
    final api = ApiClient(
      ApiConfig(baseUrl: 'https://fixture.invalid', token: 'dummy-token'),
      httpClient: MockClient((_) async => http.Response('{}', 400)),
    );
    final pending = Completer<List<String>>();
    var called = false;
    FlutterSecureStorage.setMockInitialValues({});
    const picker = MethodChannel('plugins.flutter.io/image_picker');
    final originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FixturePathProvider(root.path);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(picker, (call) async {
      called = true;
      return pending.future;
    });

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: QuickCaptureScreen(
            entryType: EntryType.quickNote,
            openedAt: DateTime(2026, 10, 29),
            apiClient: api,
            tagConfig: DefaultTagConfig.value,
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_capture_add_photo')));
      await tester.pumpAndSettle();
      expect(called, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete([file.path]);
      await tester.pump();
      for (var i = 0; i < 50; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (await tester.runAsync(file.exists) == false) break;
      }
      expect(await tester.runAsync(file.exists), isFalse);
    } finally {
      api.dispose();
      messenger.setMockMethodCallHandler(picker, null);
      PathProviderPlatform.instance = originalPaths;
      await tester.runAsync(() => root.delete(recursive: true));
    }
  });
}

class _FixturePathProvider extends PathProviderPlatform {
  final String path;
  _FixturePathProvider(this.path);
  @override
  Future<String?> getTemporaryPath() async => path;
}
