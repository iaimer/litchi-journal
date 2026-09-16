import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:litchi_journal_flutter/models/backup_settings.dart';
import 'package:litchi_journal_flutter/screens/backup_settings_page.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/screens/webdav_settings_page.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';

class _BackupHttpClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  BackupSettingsSnapshot snapshot = BackupSettingsSnapshot.defaults();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/v1/settings/backup') {
      return _json(snapshotJson(snapshot));
    }
    if (request.method == 'POST' && path == '/api/v1/settings/backup/test') {
      return _json({'success': true});
    }
    if (request.method == 'PUT' && path == '/api/v1/settings/backup') {
      final body =
          jsonDecode((request as http.Request).body) as Map<String, dynamic>;
      snapshot = snapshot.copyWith(
        enabled: body['enabled'] as bool?,
        weekday: body['weekday'] as int?,
        time: body['time'] as String?,
        webdavUrl: body['webdavUrl'] as String?,
        username: body['username'] as String?,
        remotePath: body['remotePath'] as String?,
        passwordConfigured:
            body['password'] != null || snapshot.passwordConfigured,
      );
      return _json(snapshotJson(snapshot));
    }
    if (request.method == 'POST' && path == '/api/v1/backups/webdav') {
      return _json({'accepted': true}, statusCode: 202);
    }
    return _json({}, statusCode: 404);
  }

  http.StreamedResponse _json(Object body, {int statusCode = 200}) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );
  }
}

Map<String, dynamic> snapshotJson(BackupSettingsSnapshot value) {
  return {
    'enabled': value.enabled,
    'weekday': value.weekday,
    'time': value.time,
    'timezone': value.timezone,
    'webdav': {
      'url': value.webdavUrl,
      'username': value.username,
      'remotePath': value.remotePath,
      'passwordConfigured': value.passwordConfigured,
    },
    'retention': {
      'recentWeeks': value.recentWeeks,
      'monthlyMonths': value.monthlyMonths,
    },
    'status': {
      'state': switch (value.status.state) {
        BackupState.running => 'running',
        BackupState.success => 'success',
        BackupState.failed => 'failed',
        BackupState.idle => 'idle',
      },
    },
  };
}

void main() {
  test(
    'BackupSettingsSnapshot parses redacted DTO and preserves password semantics',
    () {
      final value = BackupSettingsSnapshot.fromJson({
        'enabled': false,
        'weekday': 0,
        'time': '03:00',
        'timezone': 'Asia/Shanghai',
        'webdav': {
          'url': 'https://dav.example.test/dav',
          'username': 'alice',
          'remotePath': '/荔枝日记备份',
          'passwordConfigured': true,
        },
        'retention': {'recentWeeks': 8, 'monthlyMonths': 12},
        'status': {'state': 'success'},
      });
      expect(value.passwordConfigured, isTrue);
      expect(value.toUpdateJson().containsKey('password'), isFalse);
      expect(
        value.toUpdateJson(password: 'new-secret')['password'],
        'new-secret',
      );
    },
  );

  testWidgets(
    'backup overview uses v2 sections and opens a full-screen WebDAV page',
    (tester) async {
      final client = _BackupHttpClient();
      final apiClient = ApiClient(
        ApiConfig(baseUrl: 'https://api.example.test', token: 'token'),
        httpClient: client,
      );
      addTearDown(apiClient.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BackupSettingsPage(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('备份状态'), findsOneWidget);
      expect(find.text('自动备份'), findsNWidgets(2));
      expect(find.text('近 8 周 + 12 个月'), findsOneWidget);
      expect(find.byKey(const ValueKey('backup_auto_switch')), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('backup_webdav_settings')));
      await tester.pumpAndSettle();
      expect(find.byType(WebDavSettingsPage), findsOneWidget);
      expect(find.text('连接信息'), findsOneWidget);
      expect(find.text('连接测试'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    },
  );
}
