import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:litchi_journal_flutter/screens/home_screen.dart';
import 'package:litchi_journal_flutter/screens/past_screen.dart';
import 'package:litchi_journal_flutter/screens/read_only_diary_screen.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/habit_settings_repository.dart';
import 'package:litchi_journal_flutter/widgets/gallery_image_tile.dart';

void main() {
  testWidgets('首页刷新期间保留旧内容，成功后替换内容', (tester) async {
    final client = _RefreshHttpClient();
    client.enqueueJson('diary', _diaryBody('旧内容'));
    final pending = Completer<http.StreamedResponse>();
    client.enqueue('diary', pending.future);

    await tester.pumpWidget(_buildHome(client));
    await tester.pumpAndSettle();
    expect(find.textContaining('旧内容'), findsOneWidget);

    final refreshFuture = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    expect(find.textContaining('旧内容'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    pending.complete(_RefreshHttpClient.jsonResponse(_diaryBody('新内容')));
    await refreshFuture;
    await tester.pumpAndSettle();
    expect(find.textContaining('新内容'), findsOneWidget);
    expect(find.textContaining('旧内容'), findsNothing);
  });

  testWidgets('首页刷新失败时保留旧内容并显示非阻塞错误', (tester) async {
    final client = _RefreshHttpClient();
    client.enqueueJson('diary', _diaryBody('旧内容'));
    client.enqueueJson('diary', '', statusCode: 500);

    await tester.pumpWidget(_buildHome(client));
    await tester.pumpAndSettle();

    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();

    expect(find.textContaining('旧内容'), findsOneWidget);
    expect(find.text('加载失败'), findsOneWidget);
  });

  testWidgets('过往画廊刷新期间保留旧照片日期', (tester) async {
    final client = _RefreshHttpClient();
    client.enqueueJson('gallery', _galleryBody('2026-09-12', 'old.jpg'));
    final pending = Completer<http.StreamedResponse>();
    client.enqueue('gallery', pending.future);

    await tester.pumpWidget(
      MaterialApp(home: PastScreen(apiClient: _apiClient(client))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GalleryImageTile), findsOneWidget);
    expect(find.text('2026年9月'), findsWidgets);

    final refreshFuture = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    expect(find.byType(GalleryImageTile), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    pending.complete(
      _RefreshHttpClient.jsonResponse(_galleryBody('2026-09-13', 'new.jpg')),
    );
    await refreshFuture;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('2026-09-13-new.jpg')), findsOneWidget);
    expect(find.byKey(const ValueKey('2026-09-12-old.jpg')), findsNothing);
  });

  testWidgets('过往画廊刷新失败时保留旧照片并提供重试提示', (tester) async {
    final client = _RefreshHttpClient();
    client.enqueueJson('gallery', _galleryBody('2026-09-12', 'old.jpg'));
    client.enqueueJson('gallery', '', statusCode: 500);

    await tester.pumpWidget(
      MaterialApp(home: PastScreen(apiClient: _apiClient(client))),
    );
    await tester.pumpAndSettle();

    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();

    expect(find.byType(GalleryImageTile), findsOneWidget);
    expect(find.textContaining('更多回忆加载失败'), findsOneWidget);
  });

  testWidgets('历史详情刷新期间保留旧正文', (tester) async {
    final client = _RefreshHttpClient();
    client.enqueueJson('diary', _diaryBody('历史旧内容', date: '2026-09-12'));
    final pending = Completer<http.StreamedResponse>();
    client.enqueue('diary', pending.future);

    await tester.pumpWidget(
      MaterialApp(
        home: ReadOnlyDiaryScreen(
          date: DateTime(2026, 9, 12),
          apiClient: _apiClient(client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('历史旧内容'), findsOneWidget);

    final refreshFuture = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    expect(find.textContaining('历史旧内容'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    pending.complete(
      _RefreshHttpClient.jsonResponse(_diaryBody('历史新内容', date: '2026-09-12')),
    );
    await refreshFuture;
    await tester.pumpAndSettle();
    expect(find.textContaining('历史新内容'), findsOneWidget);
    expect(find.textContaining('历史旧内容'), findsNothing);
  });

  testWidgets('历史详情刷新失败时保留旧正文并显示内联错误', (tester) async {
    final client = _RefreshHttpClient();
    client.enqueueJson('diary', _diaryBody('历史旧内容', date: '2026-09-12'));
    client.enqueueJson('diary', '', statusCode: 500);

    await tester.pumpWidget(
      MaterialApp(
        home: ReadOnlyDiaryScreen(
          date: DateTime(2026, 9, 12),
          apiClient: _apiClient(client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();

    expect(find.textContaining('历史旧内容'), findsOneWidget);
    expect(find.text('加载失败，请检查网络后重试'), findsOneWidget);
  });
}

Widget _buildHome(_RefreshHttpClient client) {
  return MaterialApp(
    home: HomeScreen(
      apiClient: _apiClient(client),
      habitSettingsRepo: HabitSettingsRepository(storage: _MemoryStorage()),
    ),
  );
}

ApiClient _apiClient(_RefreshHttpClient client) {
  return ApiClient(
    ApiConfig(baseUrl: 'https://test.local', token: 'test'),
    httpClient: client,
  );
}

String _diaryBody(String content, {String? date}) {
  final diaryDate = date ?? ApiClient.formatDate(DateTime.now());
  return jsonEncode({
    'date': diaryDate,
    'title': '今天',
    'raw': '# 今天\n\n## ✍️ 随手记 & 灵感\n- **08:25** $content',
    'sections': <String, dynamic>{},
  });
}

String _galleryBody(String date, String image) {
  final parsed = DateTime.parse(date);
  return jsonEncode({
    'months': [
      {
        'year': parsed.year,
        'month': parsed.month,
        'totalDays': 1,
        'totalImages': 1,
        'days': [
          {
            'date': date,
            'images': [image],
            'hasContent': true,
          },
        ],
      },
    ],
    'nextCursor': null,
  });
}

class _RefreshHttpClient extends http.BaseClient {
  final _queues = <String, Queue<Future<http.StreamedResponse>>>{
    'diary': Queue(),
    'gallery': Queue(),
  };

  void enqueue(String key, Future<http.StreamedResponse> response) {
    _queues[key]!.add(response);
  }

  void enqueueJson(String key, String body, {int statusCode = 200}) {
    enqueue(key, Future.value(jsonResponse(body, statusCode: statusCode)));
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/v1/settings/tags') {
      return Future.value(jsonResponse('{}', statusCode: 500));
    }
    if (request.method == 'GET' &&
        path.startsWith('/api/v1/diary/image/render/')) {
      return Future.value(
        http.StreamedResponse(
          Stream.value(Uint8List.fromList([1, 2, 3])),
          200,
          headers: {'content-type': 'image/jpeg'},
        ),
      );
    }
    if (request.method == 'GET' && path == '/api/v1/history/gallery') {
      return _next(
        'gallery',
        fallback: Future.value(jsonResponse('{}', statusCode: 500)),
      );
    }
    if (request.method == 'GET' && path.startsWith('/api/v1/diary/')) {
      return _next(
        'diary',
        fallback: Future.value(jsonResponse('{}', statusCode: 404)),
      );
    }
    if (request.method == 'GET' && path.startsWith('/api/v1/history/')) {
      return Future.value(
        jsonResponse(
          jsonEncode({
            'year': DateTime.now().year,
            'month': DateTime.now().month,
            'diaries': [],
          }),
        ),
      );
    }
    return Future.value(jsonResponse('{}', statusCode: 404));
  }

  Future<http.StreamedResponse> _next(
    String key, {
    required Future<http.StreamedResponse> fallback,
  }) {
    final queue = _queues[key]!;
    return queue.isEmpty ? fallback : queue.removeFirst();
  }

  static http.StreamedResponse jsonResponse(
    String body, {
    int statusCode = 200,
  }) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _MemoryStorage implements HabitSettingsStorage {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
