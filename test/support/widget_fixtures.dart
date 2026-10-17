part of '../widget_test.dart';

Finder _floraIcon(String name) => find.byWidgetPredicate(
  (widget) => widget is FloraIcon && widget.name == name,
);

Future<Uint8List> _encodeUploadBodyForTest(Map<String, dynamic> body) async {
  return Uint8List.fromList(utf8.encode(jsonEncode(body)));
}

TagConfig _testTagConfig() {
  return TagConfig(
    domains: [
      TagDomain(
        id: 'work',
        name: '工作',
        order: 0,
        topics: [TagTopic(id: 'work-task', name: '任务执行', order: 0)],
      ),
    ],
    methods: [TagMethod(id: 'reflect', name: '反思', order: 0)],
  );
}

TagConfig _polishTagConfig() {
  return TagConfig(
    domains: [
      TagDomain(
        id: 'parenting',
        name: '亲子',
        order: 0,
        topics: [
          TagTopic(id: 'p-bonding', name: '陪伴互动', order: 0),
          TagTopic(id: 'p-comm', name: '亲子沟通', order: 1),
          TagTopic(id: 'p-relation', name: '关系连接', order: 2),
        ],
      ),
      TagDomain(
        id: 'work',
        name: '工作',
        order: 1,
        topics: [TagTopic(id: 'work-task', name: '任务执行', order: 0)],
      ),
    ],
    methods: [TagMethod(id: 'reflect', name: '反思', order: 0)],
  );
}

class _TestStorage
    implements
        DraftStorage,
        AIConfigStorage,
        HabitSettingsStorage,
        ImageSettingsStorage {
  final Map<String, String> data;
  _TestStorage([Map<String, String>? data]) : data = data ?? {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

class _FakeHttpClient extends http.BaseClient {
  final int statusCode;
  final String body;

  _FakeHttpClient({this.statusCode = 200, this.body = ''});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _GalleryHttpClient extends http.BaseClient {
  final String galleryBody;
  final String? historyBody;
  final int imageStatusCode;
  Uint8List imageBytes;
  final List<Uri> requests = [];

  _GalleryHttpClient({
    required this.galleryBody,
    required this.imageBytes,
    this.historyBody,
    this.imageStatusCode = 200,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/v1/history/gallery') {
      return _response(galleryBody, 200, 'application/json');
    }
    if (request.method == 'GET' && path == '/api/v1/settings/tags') {
      return _response('{}', 500, 'application/json');
    }
    if (request.method == 'GET' &&
        path.startsWith('/api/v1/diary/image/render/')) {
      return http.StreamedResponse(
        Stream.value(imageBytes),
        imageStatusCode,
        headers: {'content-type': 'image/jpeg'},
      );
    }
    if (request.method == 'GET' && path.startsWith('/api/v1/diary/')) {
      return _response('{}', 404, 'application/json');
    }
    if (request.method == 'GET' && path.startsWith('/api/v1/history/')) {
      return _response(
        historyBody ??
            jsonEncode({
              'year': DateTime.now().year,
              'month': DateTime.now().month,
              'diaries': [],
            }),
        200,
        'application/json',
      );
    }
    return _response('{}', 404, 'application/json');
  }

  http.StreamedResponse _response(
    String body,
    int statusCode,
    String contentType,
  ) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {'content-type': contentType},
    );
  }
}

class _PastMemoryHttpClient extends http.BaseClient {
  final Uint8List imageBytes;

  _PastMemoryHttpClient({required this.imageBytes});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/v1/history/gallery') {
      return _response(
        jsonEncode({
          'months': [
            {
              'year': 2024,
              'month': 3,
              'totalDays': 1,
              'totalImages': 1,
              'days': [
                {
                  'date': '2024-03-08',
                  'images': ['memory.jpg'],
                  'hasContent': true,
                },
              ],
            },
          ],
          'nextCursor': null,
        }),
        200,
      );
    }
    if (request.method == 'GET' && path == '/api/v1/settings/tags') {
      return _response('{}', 500);
    }
    if (request.method == 'GET' &&
        path.startsWith('/api/v1/diary/image/render/')) {
      return http.StreamedResponse(
        Stream.value(imageBytes),
        200,
        headers: {'content-type': 'image/jpeg'},
      );
    }
    if (request.method == 'GET' && path.startsWith('/api/v1/diary/')) {
      final date = path.substring('/api/v1/diary/'.length);
      return _response(
        jsonEncode({
          'date': date,
          'title': '旧日记',
          'raw': '# 旧日记\n\n### 🖼️ 影像记录\n![[memory.jpg]]',
          'sections': <String, List<String>>{},
        }),
        200,
      );
    }
    if (request.method == 'GET' && path.startsWith('/api/v1/history/')) {
      return _response(
        jsonEncode({
          'year': DateTime.now().year,
          'month': DateTime.now().month,
          'diaries': [],
        }),
        200,
      );
    }
    return _response('{}', 404);
  }

  http.StreamedResponse _response(String body, int statusCode) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _CalendarRaceHttpClient extends http.BaseClient {
  final List<Completer<http.StreamedResponse>> historyResponses = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/v1/history/gallery') {
      return Future.value(_response('{"months":[],"nextCursor":null}', 200));
    }
    if (request.method == 'GET' && path.startsWith('/api/v1/diary/')) {
      return Future.value(_response('{}', 404));
    }
    if (request.method == 'GET' && path.startsWith('/api/v1/history/')) {
      final completer = Completer<http.StreamedResponse>();
      historyResponses.add(completer);
      return completer.future;
    }
    return Future.value(_response('{}', 404));
  }

  void completeHistory(int index, {required int statusCode}) {
    historyResponses[index].complete(
      _response(
        jsonEncode({
          'year': DateTime.now().year,
          'month': DateTime.now().month,
          'diaries': [],
        }),
        statusCode,
      ),
    );
  }

  http.StreamedResponse _response(String body, int statusCode) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _RecordingHttpClient extends _FakeHttpClient {
  final requestPaths = <String>[];

  _RecordingHttpClient({required super.body});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestPaths.add('${request.method} ${request.url.path}');
    return super.send(request);
  }
}

class _HistoricalBackfillHttpClient extends http.BaseClient {
  bool diaryCreated = false;
  int diaryGetCalls = 0;
  int createCalls = 0;
  int appendCalls = 0;
  int uploadCalls = 0;
  final uploadOperationIds = <String>[];
  final uploadEntryIds = <String?>[];
  String? lastAppendBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/v1/settings/tags') {
      return _response('{}', 500);
    }
    if (request.method == 'GET' && path.startsWith('/api/v1/diary/')) {
      diaryGetCalls++;
      if (!diaryCreated) return _response('{}', 404);
      return _response(
        jsonEncode({
          'date': path.split('/').last,
          'title': '历史日记',
          'raw': '# 历史日记\n\n### 🖼️ 影像记录\n![[image.jpg]]',
          'sections': {},
        }),
        200,
      );
    }
    if (request.method == 'POST' && path == '/api/v1/diary/create') {
      createCalls++;
      diaryCreated = true;
      return _response('{"ok":true}', 200);
    }
    if (request.method == 'POST' && path == '/api/v1/diary/quick-note') {
      appendCalls++;
      if (request is http.Request) lastAppendBody = request.body;
      return _response('{"ok":true}', diaryCreated ? 200 : 404);
    }
    if (request.method == 'POST' && path == '/api/v1/diary/image/upload') {
      final bodyBytes = await request.finalize().fold<List<int>>(
        [],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      final body = jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
      uploadOperationIds.add(body['operationId'] as String);
      uploadEntryIds.add(body['entryId'] as String?);
      uploadCalls++;
      return uploadCalls == 2
          ? _response('{"error":"upload failed"}', 500)
          : _response(
              jsonEncode({
                'success': true,
                'filename': 'backfill_$uploadCalls.jpg',
              }),
              200,
            );
    }
    return _response('{}', 404);
  }

  http.StreamedResponse _response(String body, int statusCode) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _TodayImageUploadHttpClient extends http.BaseClient {
  _TodayImageUploadHttpClient({
    this.failFirstUpload = true,
    this.diaryRaw = '# 今天\n',
  });

  final bool failFirstUpload;
  String diaryRaw;
  int diaryGetCalls = 0;
  int uploadCalls = 0;
  final uploadOperationIds = <String>[];
  final uploadEntryIds = <String?>[];
  String? lastAppendBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/v1/settings/tags') {
      return _response('{}', 500);
    }
    if (request.method == 'GET' && path.startsWith('/api/v1/diary/')) {
      diaryGetCalls++;
      return _response(
        jsonEncode({
          'date': path.split('/').last,
          'title': '今天',
          'raw': diaryRaw,
          'sections': {},
        }),
        200,
      );
    }
    if (request.method == 'POST' && path == '/api/v1/diary/quick-note') {
      if (request is http.Request) {
        lastAppendBody = request.body;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        diaryRaw +=
            '\n## ✍️ 随手记 & 灵感\n'
            '- **${body['time']}** ${body['content']}\n'
            '<!-- litchi-entry-id:${body['entryId']} -->\n'
            '\n## 📸 影像记录\n';
      }
      return _response('{"ok":true}', 200);
    }
    if (request.method == 'POST' && path == '/api/v1/diary/edit-entry') {
      if (request is http.Request) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        diaryRaw = diaryRaw.replaceFirst(
          body['target'] as String,
          '${body['replacement']}\n<!-- litchi-entry-id:${body['entryId']} -->',
        );
      }
      return _response('{"ok":true}', 200);
    }
    if (request.method == 'POST' && path == '/api/v1/diary/image/upload') {
      final bodyBytes = await request.finalize().fold<List<int>>(
        [],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      final body = jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
      uploadOperationIds.add(body['operationId'] as String);
      uploadEntryIds.add(body['entryId'] as String?);
      uploadCalls++;
      if (failFirstUpload && uploadCalls == 1) {
        return _response('{"error":"upload failed"}', 500);
      }
      final filename = 'today_$uploadCalls.jpg';
      diaryRaw +=
          '\n![[$filename]]\n'
          '<!-- litchi-photo-of:${body['entryId']};op:${body['operationId']} -->\n';
      return _response(
        jsonEncode({'success': true, 'filename': filename}),
        200,
      );
    }
    return _response('{"ok":true}', 200);
  }

  http.StreamedResponse _response(String body, int statusCode) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _HangingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }
}

class _TimeoutHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw TimeoutException('timeout');
  }
}

class _ClientExceptionHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw http.ClientException('connection closed');
  }
}

class _CapturingHttpClient extends _FakeHttpClient {
  String? lastRequestBody;

  _CapturingHttpClient({super.body});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().fold<List<int>>(
      [],
      (prev, chunk) => prev..addAll(chunk),
    );
    lastRequestBody = utf8.decode(bytes);
    return super.send(request);
  }
}

class _MultiResponseHttpClient extends http.BaseClient {
  final List<String> _bodies;
  int _callCount = 0;

  _MultiResponseHttpClient(this._bodies);

  int get callCount => _callCount;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final index = _callCount < _bodies.length ? _callCount : _bodies.length - 1;
    _callCount++;
    return http.StreamedResponse(
      Stream.value(utf8.encode(_bodies[index])),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _CapturingClient extends http.BaseClient {
  String? lastUrl;
  String? lastBody;
  final int statusCode;
  final String responseBody;

  _CapturingClient({this.statusCode = 200, this.responseBody = '{"ok": true}'});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUrl = request.url.toString();
    if (request is http.Request) {
      lastBody = request.body;
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      statusCode,
    );
  }
}

class _PastMemoryRetryClient extends http.BaseClient {
  int historyCalls = 0;
  final DateTime memoryDate;

  _PastMemoryRetryClient(this.memoryDate);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.contains('/api/v1/history/')) {
      historyCalls++;
      if (historyCalls <= 2) {
        return http.StreamedResponse(Stream.value(utf8.encode('error')), 500);
      }
      final body = jsonEncode({
        'year': memoryDate.year,
        'month': memoryDate.month,
        'diaries': [
          {
            'date': ApiClient.formatDate(memoryDate),
            'hasContent': true,
            'exists': true,
          },
        ],
      });
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    if (request.url.path.contains('/api/v1/diary/')) {
      final body = jsonEncode({
        'date': ApiClient.formatDate(memoryDate),
        'title': '旧日记',
        'raw': '# 今天\n\n## ✍️ 随手记 & 灵感\n- **09:30** 一段旧时光 #记录',
        'sections': {},
      });
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  }
}

class _HabitTestHttpClient extends http.BaseClient {
  final int year;
  final int month;
  final Map<int, int> waterByDay;
  final Map<int, int> stepsByDay;
  final Map<int, bool> readingByDay;
  final Map<int, bool> languageByDay;
  final Map<int, bool> supplementByDay;
  int historyRequestCount = 0;
  int diaryRequestCount = 0;

  _HabitTestHttpClient({
    required this.year,
    required this.month,
    required this.waterByDay,
    required this.stepsByDay,
    required this.readingByDay,
    required this.languageByDay,
    required this.supplementByDay,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();

    if (request.url.path == '/api/v1/stats/habit') {
      final uri = request.url;
      final from = DateTime.tryParse(uri.queryParameters['from'] ?? '');
      final to = DateTime.tryParse(uri.queryParameters['to'] ?? '');
      if (from == null || to == null || to.isBefore(from)) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error":"invalid range"}')),
          400,
        );
      }

      final rows = <Map<String, dynamic>>[];
      for (
        var date = DateTime(from.year, from.month, from.day);
        !date.isAfter(to);
        date = date.add(const Duration(days: 1))
      ) {
        final dataKey = _dataKeyForDate(date.year, date.month, date.day);
        final hasData =
            waterByDay.containsKey(dataKey) ||
            stepsByDay.containsKey(dataKey) ||
            readingByDay.containsKey(dataKey) ||
            languageByDay.containsKey(dataKey) ||
            supplementByDay.containsKey(dataKey);
        rows.add({
          'date': ApiClient.formatDate(date),
          'hasDiary': hasData,
          'water': waterByDay[dataKey] ?? 0,
          'steps': stepsByDay[dataKey] ?? 0,
          'reading': readingByDay[dataKey] ?? false,
          'language': languageByDay[dataKey] ?? false,
          'supplements': supplementByDay[dataKey] ?? false,
          'readingMinutes': readingByDay[dataKey] == true ? 30 : null,
          'languageMinutes': languageByDay[dataKey] == true ? 10 : null,
          'customCheckboxes': <String, bool>{},
          'customDurations': <String, int>{},
        });
      }

      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(rows))),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    if (url.contains('/api/v1/history/')) {
      historyRequestCount++;
      // Parse requested year/month from URL path
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final reqYear = int.tryParse(segments[segments.length - 2]) ?? year;
      final reqMonth = int.tryParse(segments.last) ?? month;

      final supportsRequestedMonth =
          _isConfiguredMonth(reqYear, reqMonth) ||
          _isPreviousConfiguredMonth(reqYear, reqMonth);

      if (!supportsRequestedMonth) {
        final body = jsonEncode({
          'year': reqYear,
          'month': reqMonth,
          'diaries': <Map<String, dynamic>>[],
        });
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      // Return all days that have any habit data
      final allDays = <int>{};
      allDays.addAll(waterByDay.keys);
      allDays.addAll(stepsByDay.keys);
      allDays.addAll(readingByDay.keys);
      allDays.addAll(languageByDay.keys);
      allDays.addAll(supplementByDay.keys);

      final diaries = allDays
          .map(_dateForDataKey)
          .where((date) => date.year == reqYear && date.month == reqMonth)
          .map((date) {
            return {
              'date': ApiClient.formatDate(date),
              'hasContent': true,
              'exists': true,
            };
          })
          .toList();

      final body = jsonEncode({
        'year': reqYear,
        'month': reqMonth,
        'diaries': diaries,
      });
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    if (url.contains('/api/v1/diary/')) {
      diaryRequestCount++;
      // Extract day from URL
      final parts = url.split('/');
      final dateStr = parts.last;
      final dateParts = dateStr.split('-');
      final reqYear = int.parse(dateParts[0]);
      final reqMonth = int.parse(dateParts[1]);
      final day = int.parse(dateParts.last);
      final dataKey = _dataKeyForDate(reqYear, reqMonth, day);

      final water = waterByDay[dataKey] ?? 0;
      final steps = stepsByDay[dataKey] ?? 0;
      final reading = readingByDay[dataKey] ?? false;
      final language = languageByDay[dataKey] ?? false;
      final supp = supplementByDay[dataKey] ?? false;

      final readingCheck = reading ? 'x' : ' ';
      final languageCheck = language ? 'x' : ' ';
      final suppCheck = supp ? 'x' : ' ';
      final readingMinutes = reading ? 30 : 0;
      final languageMinutes = language ? 10 : 0;

      final body = jsonEncode({
        'date': dateStr,
        'title': '今天',
        'raw':
            '# 今天\n\n### 📋 习惯打卡\n- [$readingCheck] 阅读 $readingMinutes 分钟\n- [$languageCheck] 学语言 $languageMinutes 分钟\n- [$suppCheck] 鱼油 / 植物甾醇\n- 饮水 $water mL\n- 运动 $steps 步',
        'sections': {},
      });
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  }

  bool _isConfiguredMonth(int reqYear, int reqMonth) {
    return reqYear == year && reqMonth == month;
  }

  bool _isPreviousConfiguredMonth(int reqYear, int reqMonth) {
    final previous = DateTime(year, month - 1);
    return reqYear == previous.year && reqMonth == previous.month;
  }

  DateTime _dateForDataKey(int dayKey) {
    if (dayKey >= 1) return DateTime(year, month, dayKey);
    final previous = DateTime(year, month - 1);
    final previousDays = DateTime(year, month, 0).day;
    return DateTime(previous.year, previous.month, previousDays + dayKey);
  }

  int _dataKeyForDate(int reqYear, int reqMonth, int day) {
    if (_isConfiguredMonth(reqYear, reqMonth)) return day;
    if (_isPreviousConfiguredMonth(reqYear, reqMonth)) {
      final previousDays = DateTime(year, month, 0).day;
      return day - previousDays;
    }
    return day;
  }
}

/// HTTP 客户端：模拟网络延迟。
class _DelayedHttpClient extends _HabitTestHttpClient {
  final Duration delay;

  _DelayedHttpClient({
    required super.year,
    required super.month,
    required super.waterByDay,
    required super.stepsByDay,
    required super.readingByDay,
    required super.languageByDay,
    required super.supplementByDay,
    required this.delay,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future.delayed(delay);
    return super.send(request);
  }
}

/// HTTP 客户端：所有请求都返回 500。
class _AlwaysFailHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('server error')),
      500,
    );
  }
}

void _fillSolidImage(img.Image image) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 100, 150, 200, 255);
    }
  }
}

img.Image _makeNoisyImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  final rng = Random(42);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(
        x,
        y,
        rng.nextInt(256),
        rng.nextInt(256),
        rng.nextInt(256),
        255,
      );
    }
  }
  return image;
}

TagConfig fullTagConfig() {
  return TagConfig(
    domains: [
      TagDomain(
        id: 'parenting',
        name: '亲子',
        order: 0,
        topics: [
          TagTopic(id: 'p-bonding', name: '陪伴互动', order: 0),
          TagTopic(id: 'p-talk', name: '亲子沟通', order: 1),
        ],
      ),
      TagDomain(
        id: 'work',
        name: '工作',
        order: 1,
        topics: [TagTopic(id: 'work-task', name: '任务执行', order: 0)],
      ),
    ],
    methods: [
      TagMethod(id: 'reflect', name: '反思', order: 0),
      TagMethod(id: 'methodology', name: '方法论', order: 1),
    ],
  );
}
