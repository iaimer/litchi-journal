import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/services/backup_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(BackupDownloadService.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'passes authenticated export request to Android DownloadManager',
    () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            return 42;
          });
      final service = BackupDownloadService(channel: channel, isAndroid: true);

      final id = await service.enqueue(
        url: 'https://journal.example.test/api/v1/backups/export',
        authorization: 'Token private-value',
        fileName: 'litchi-journal-diary-20260916-220000.zip',
      );

      expect(id, 42);
      expect(captured?.method, 'enqueue');
      expect(captured?.arguments, {
        'url': 'https://journal.example.test/api/v1/backups/export',
        'authorization': 'Token private-value',
        'fileName': 'litchi-journal-diary-20260916-220000.zip',
      });
    },
  );

  test(
    'parses a terminal DownloadManager failure without exposing raw reason',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'queryLatest');
            return {
              'downloadId': 42,
              'state': 'failed',
              'error': '手机存储空间不足，备份未保存',
              'downloadedBytes': 1024,
              'totalBytes': 2048,
            };
          });
      final service = BackupDownloadService(channel: channel, isAndroid: true);

      final status = await service.queryLatest();

      expect(status?.isTerminal, isTrue);
      expect(status?.state, BackupDownloadState.failed);
      expect(status?.error, '手机存储空间不足，备份未保存');
      expect(status?.downloadedBytes, 1024);
      expect(status?.totalBytes, 2048);
    },
  );
}
