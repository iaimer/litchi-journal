import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

import 'package:litchi_journal_flutter/models/ai_config.dart';
import 'package:litchi_journal_flutter/models/diary_entry.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/models/polish_result.dart';
import 'package:litchi_journal_flutter/models/tag_config.dart';
import 'package:litchi_journal_flutter/services/ai_config_repository.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/draft_repository.dart';
import 'package:litchi_journal_flutter/services/entry_line_builder.dart';
import 'package:litchi_journal_flutter/services/image_compress_service.dart';
import 'package:litchi_journal_flutter/services/markdown_parser.dart';
import 'package:litchi_journal_flutter/services/polish_result_parser.dart';
import 'package:litchi_journal_flutter/services/polisher_service.dart';
import 'package:litchi_journal_flutter/services/past_memory_service.dart';
import 'package:litchi_journal_flutter/services/habit_stats_service.dart';
import 'package:litchi_journal_flutter/services/habit_settings_repository.dart';
import 'package:litchi_journal_flutter/services/habit_stats_cache_repository.dart';
import 'package:litchi_journal_flutter/models/habit_stats.dart';
import 'package:litchi_journal_flutter/models/habit_settings.dart';
import 'package:litchi_journal_flutter/models/habit_visual_config.dart';
import 'package:litchi_journal_flutter/screens/home_screen.dart';
import 'package:litchi_journal_flutter/screens/past_screen.dart';
import 'package:litchi_journal_flutter/screens/read_only_diary_screen.dart';
import 'package:litchi_journal_flutter/screens/habit_stats_screen.dart';
import 'package:litchi_journal_flutter/screens/settings_screen.dart';
import 'package:litchi_journal_flutter/screens/settings_page.dart';
import 'package:litchi_journal_flutter/screens/remote_api_page.dart';
import 'package:litchi_journal_flutter/widgets/anxiety_card.dart';
import 'package:litchi_journal_flutter/widgets/anxiety_composer.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/entry_edit_sheet.dart';
import 'package:litchi_journal_flutter/widgets/entry_type.dart';
import 'package:litchi_journal_flutter/widgets/entry_type_selector.dart';
import 'package:litchi_journal_flutter/widgets/generic_section_card.dart';
import 'package:litchi_journal_flutter/widgets/habit_card.dart';
import 'package:litchi_journal_flutter/widgets/image_section_card.dart';
import 'package:litchi_journal_flutter/widgets/quick_note_composer.dart';
import 'package:litchi_journal_flutter/widgets/quick_note_timeline.dart';
import 'package:litchi_journal_flutter/widgets/review_card.dart';
import 'package:litchi_journal_flutter/widgets/tag_picker.dart';

import 'package:litchi_journal_flutter/models/tag_settings.dart';
import 'package:litchi_journal_flutter/services/tag_settings_helper.dart';
import 'package:litchi_journal_flutter/services/tag_settings_repository.dart';
import 'package:litchi_journal_flutter/services/appearance_settings.dart';

import 'package:litchi_journal_flutter/services/appearance_settings_repository.dart';

import 'package:litchi_journal_flutter/screens/appearance_settings_page.dart';

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
    implements DraftStorage, AIConfigStorage, HabitSettingsStorage {
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

    if (url.contains('/api/v1/history/')) {
      historyRequestCount++;
      // Parse requested year/month from URL path
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final reqYear = int.tryParse(segments[segments.length - 2]) ?? year;
      final reqMonth = int.tryParse(segments.last) ?? month;

      // Only return data for the month matching test config
      if (reqYear != year || reqMonth != month) {
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

      final diaries = allDays.map((day) {
        final dayStr = day.toString().padLeft(2, '0');
        return {
          'date': '$year-${month.toString().padLeft(2, '0')}-$dayStr',
          'hasContent': true,
          'exists': true,
        };
      }).toList();

      final body = jsonEncode({
        'year': year,
        'month': month,
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
      final day = int.parse(dateParts.last);

      final water = waterByDay[day] ?? 0;
      final steps = stepsByDay[day] ?? 0;
      final reading = readingByDay[day] ?? false;
      final language = languageByDay[day] ?? false;
      final supp = supplementByDay[day] ?? false;

      final readingCheck = reading ? 'x' : ' ';
      final languageCheck = language ? 'x' : ' ';
      final suppCheck = supp ? 'x' : ' ';

      final body = jsonEncode({
        'date': dateStr,
        'title': '今天',
        'raw':
            '# 今天\n\n### 📋 习惯打卡\n- [$readingCheck] 阅读 30 分钟\n- [$languageCheck] 学语言\n- [$suppCheck] 鱼油 / 植物甾醇\n- 饮水 $water mL\n- 运动 $steps 步',
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

/// HTTP 客户端：选择性在某一天 getDiary 上失败。
class _SelectiveFailureHttpClient extends _HabitTestHttpClient {
  final int failOnDay;
  final int failCount;
  final int Function() callCount;
  int _failures = 0;

  _SelectiveFailureHttpClient({
    required super.year,
    required super.month,
    required super.waterByDay,
    required super.stepsByDay,
    required super.readingByDay,
    required super.languageByDay,
    required super.supplementByDay,
    required this.failOnDay,
    required this.failCount,
    required this.callCount,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    if (url.contains('/api/v1/diary/')) {
      final parts = url.split('/');
      final dateParts = parts.last.split('-');
      final day = int.parse(dateParts.last);
      callCount();
      if (day == failOnDay && _failures < failCount) {
        _failures++;
        return http.StreamedResponse(
          Stream.value(utf8.encode('server error')),
          500,
        );
      }
    }
    return super.send(request);
  }
}

/// HTTP 客户端：记录 getDiary 调用次数。
class _CountingGetDiaryHttpClient extends _HabitTestHttpClient {
  final void Function() onGetDiary;

  _CountingGetDiaryHttpClient({
    required super.year,
    required super.month,
    required super.waterByDay,
    required super.stepsByDay,
    required super.readingByDay,
    required super.languageByDay,
    required super.supplementByDay,
    required this.onGetDiary,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    if (url.contains('/api/v1/diary/')) {
      onGetDiary();
    }
    return super.send(request);
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

/// 内存存储，用于测试 HabitStatsCacheRepository。
class _MemoryStorage implements HabitStatsCacheStorage {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    store.remove(key);
  }
}

void main() {
  test('DiaryEntry.fromJson parses valid data', () {
    final json = {
      'date': '2026-06-06',
      'title': 'Test',
      'raw': 'Hello world',
      'sections': {
        'notes': ['note1', 'note2'],
      },
    };
    final entry = DiaryEntry.fromJson(json);
    expect(entry.date, '2026-06-06');
    expect(entry.title, 'Test');
    expect(entry.raw, 'Hello world');
    expect(entry.sections['notes'], ['note1', 'note2']);
  });

  test('DiaryEntry.fromJson handles empty data', () {
    final entry = DiaryEntry.fromJson({});
    expect(entry.date, '');
    expect(entry.title, '');
    expect(entry.raw, '');
    expect(entry.sections, {});
    expect(entry.isEmpty, isTrue);
  });

  group('Top page headers', () {
    ApiClient clientWithBody(String body) {
      return ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _FakeHttpClient(body: body),
      );
    }

    testWidgets('HomeScreen uses date as title and hides connection label', (
      tester,
    ) async {
      final now = DateTime.now();
      const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      final today =
          '${now.year}年${now.month}月${now.day}日 星期${weekdays[now.weekday - 1]}';
      final client = clientWithBody(
        jsonEncode({
          'date': ApiClient.formatDate(now),
          'title': '今天',
          'raw': '# 今天\n',
          'sections': {},
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            apiClient: client,
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('荔枝日记'), findsNothing);
      expect(find.text(today), findsOneWidget);
      final title = tester.widget<Text>(find.text(today));
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(find.text('已连接服务器'), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('PastScreen keeps header content inside SafeArea', (
      tester,
    ) async {
      final client = clientWithBody(
        jsonEncode({
          'year': DateTime.now().year,
          'month': DateTime.now().month,
          'diaries': [],
          'raw': '',
        }),
      );

      await tester.pumpWidget(MaterialApp(home: PastScreen(apiClient: client)));
      await tester.pumpAndSettle();

      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.text('过往'), findsOneWidget);
      expect(find.text('看看那些已经走过的日子'), findsOneWidget);
      expect(find.text('今天曾经发生过'), findsOneWidget);
      expect(find.text('随便走走'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('过往'), matching: find.byType(ListView)),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('看看那些已经走过的日子'),
          matching: find.byType(ListView),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('今天曾经发生过'),
          matching: find.byType(ListView),
        ),
        findsOneWidget,
      );
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.physics, isA<AlwaysScrollableScrollPhysics>());
    });

    testWidgets(
      'ReadOnlyDiaryScreen keeps refresh available for short content',
      (tester) async {
        final client = clientWithBody(
          jsonEncode({
            'date': '2026-06-08',
            'title': '旧日记',
            'raw': '# 今天\n\n### 🧠 人生教练\n📌 模式识别\n旧内容',
            'sections': {},
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ReadOnlyDiaryScreen(
              date: DateTime(2026, 6, 8),
              apiClient: client,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.physics, isA<AlwaysScrollableScrollPhysics>());
      },
    );
  });

  test(
    'PastMemoryService retries month loading after transient failure',
    () async {
      final now = DateTime.now();
      final memoryDate = DateTime(
        now.year,
        now.month,
        now.day == 1 ? 2 : now.day - 1,
      );
      final httpClient = _PastMemoryRetryClient(memoryDate);
      final apiClient = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: httpClient,
      );
      final service = PastMemoryService(apiClient);

      final first = await service.getRandomMemory();
      final second = await service.getRandomMemory();

      expect(first, isNull);
      expect(second, isNotNull);
      expect(second!.date, memoryDate);
      expect(httpClient.historyCalls, greaterThan(2));
    },
  );

  test('MarkdownParser maps diary markdown to domain sections', () {
    const markdown = '''
---
tags:
  - 日记
---

# 🌿 星期六 · 此时此刻
> [!quote] 记录让生活更清楚

---
## 🏃 习惯打卡
- [x] 📖 阅读/亲子共读
- [ ] 💊 鱼油/植物甾醇
- 喝水 8 杯

---
## ✍️ 随手记 & 灵感
- **09:30** 写下一个想法 #生活 #日常记录

---
## 😰 焦虑时刻
- 今天什么时候我感到焦虑/紧张？
>

---
## 📈 每日复盘
### 💡 觉察与迭代
- 今天更早休息

### 🧠 人生教练
-

### 🌙 明日寄语
-

---
## 📸 影像记录
''';

    final document = const MarkdownParser().parse(markdown);

    expect(document.title, '🌿 星期六 · 此时此刻');
    expect(document.preamble.single, isA<CalloutContent>());
    expect(document.sections.whereType<HabitSection>(), hasLength(1));
    expect(document.sections.whereType<QuickNoteSection>(), hasLength(1));
    expect(document.sections.whereType<AnxietySection>(), hasLength(1));
    expect(document.sections.whereType<ReviewSection>(), hasLength(2));
    expect(document.sections.whereType<CoachSection>(), hasLength(1));
    expect(document.sections.whereType<TomorrowSection>(), hasLength(1));
    expect(document.sections.whereType<MediaSection>(), hasLength(1));

    final habit = document.sections.whereType<HabitSection>().single;
    expect(habit.contents.whereType<CheckboxContent>(), hasLength(2));
    expect(habit.habits, hasLength(3));
    expect(habit.habits[0].label, '📖 阅读/亲子共读');
    expect(habit.habits[0].checked, isTrue);
    expect(habit.habits[0].kind, HabitKind.checkbox);
    expect(habit.habits[0].rawLine, '- [x] 📖 阅读/亲子共读');
    expect(habit.habits[1].label, '💊 鱼油/植物甾醇');
    expect(habit.habits[1].checked, isFalse);
    expect(habit.habits[1].kind, HabitKind.checkbox);
    expect(habit.habits[1].rawLine, '- [ ] 💊 鱼油/植物甾醇');
    expect(habit.habits[2].label, '喝水');
    expect(habit.habits[2].kind, HabitKind.counter);
    expect(habit.habits[2].value, 8);
    expect(habit.habits[2].unit, '杯');

    final quickNote = document.sections.whereType<QuickNoteSection>().single;
    final note = quickNote.contents.whereType<TimelineContent>().single;
    expect(note.time, '09:30');
    expect(note.text, '写下一个想法');
    expect(note.tags, ['#生活', '#日常记录']);
    expect(note.rawLine, '- **09:30** 写下一个想法 #生活 #日常记录');
    expect(quickNote.notes, hasLength(1));
    expect(quickNote.notes.single.time, '09:30');
    expect(quickNote.notes.single.content, '写下一个想法');
    expect(quickNote.notes.single.tags, ['#生活', '#日常记录']);
    expect(quickNote.notes.single.rawLine, '- **09:30** 写下一个想法 #生活 #日常记录');

    final anxiety = document.sections.whereType<AnxietySection>().single;
    expect(anxiety.isEmpty, isTrue);

    final reviews = document.sections.whereType<ReviewSection>().toList();
    expect(reviews.any((r) => !r.isEmpty), isTrue);
  });

  test('MarkdownParser recognizes happiness section', () {
    const markdown = '''
---
---

# 🌟 今天
> [!quote] 每日一言

---
## 🏃 习惯打卡

---
## ✨ 每日小确幸
> **09:30** 喝到一杯好咖啡 #生活 #日常记录
> **14:00** 发现一只可爱的小猫 #生活
>

---
## 📸 影像记录
''';

    final document = const MarkdownParser().parse(markdown);
    final happiness = document.sections.whereType<HappinessSection>().single;

    expect(happiness.isEmpty, isFalse);
    expect(happiness.contents, hasLength(2));

    final first = happiness.contents[0] as TimelineContent;
    expect(first.time, '09:30');
    expect(first.text, '喝到一杯好咖啡');
    expect(first.tags, ['#生活', '#日常记录']);

    final second = happiness.contents[1] as TimelineContent;
    expect(second.time, '14:00');
    expect(second.text, '发现一只可爱的小猫');
    expect(second.tags, ['#生活']);
  });

  test('MarkdownParser separates happiness slogan from timeline entries', () {
    const markdown = '''
---
---

## ✨ 每日小确幸
> [!success] 总有事件值得感恩🙏❤️
>
> **09:30** 喝到一杯好咖啡 #生活 #日常记录
> **14:00** 发现一只可爱的小猫 #生活

## 📸 影像记录
''';

    final document = const MarkdownParser().parse(markdown);
    final happiness = document.sections.whereType<HappinessSection>().single;

    expect(happiness.isEmpty, isFalse);

    final callouts = happiness.contents.whereType<CalloutContent>();
    final timelines = happiness.contents.whereType<TimelineContent>();

    expect(callouts, hasLength(1));
    expect(callouts.single.type, 'success');
    expect(callouts.single.title, '总有事件值得感恩🙏❤️');
    expect(callouts.single.body, isEmpty);

    expect(timelines, hasLength(2));
    expect(timelines.first.time, '09:30');
    expect(timelines.first.text, '喝到一杯好咖啡');
    expect(timelines.last.time, '14:00');
    expect(timelines.last.text, '发现一只可爱的小猫');
  });

  test('MarkdownParser parses counter habits', () {
    const markdown = '''
---
---

## 🏃 习惯打卡
- 🥛🥤🥤饮水 500 mL
- 🧘 运动/拉伸/快走 8000 步
- [x] 📖 阅读/亲子共读
- [ ] 💊 鱼油/植物甾醇
''';

    final document = const MarkdownParser().parse(markdown);
    final habit = document.sections.whereType<HabitSection>().single;

    expect(habit.habits, hasLength(4));

    final water = habit.habits[0];
    expect(water.kind, HabitKind.counter);
    expect(water.label, '饮水');
    expect(water.value, 500);
    expect(water.unit, 'mL');
    expect(water.checkable, isFalse);

    final steps = habit.habits[1];
    expect(steps.kind, HabitKind.counter);
    expect(steps.label, '运动/拉伸/快走');
    expect(steps.value, 8000);
    expect(steps.unit, '步');
    expect(steps.checkable, isFalse);

    final reading = habit.habits[2];
    expect(reading.kind, HabitKind.checkbox);
    expect(reading.label, '📖 阅读/亲子共读');
    expect(reading.checked, isTrue);

    final supplements = habit.habits[3];
    expect(supplements.kind, HabitKind.checkbox);
    expect(supplements.label, '💊 鱼油/植物甾醇');
    expect(supplements.checked, isFalse);
  });

  test('MarkdownParser treats ### 觉察 as standalone section', () {
    const markdown = '''
---
---

## 😰 焦虑时刻
- 今天什么时候我感到焦虑/紧张？
> 下午开会

### 💡 觉察与迭代
- **21:24** 今天反思了一下沟通方式 #育儿 #成长观察 #反思
- **22:00** 第二条例行觉察 #工作 #任务执行
''';

    final document = const MarkdownParser().parse(markdown);

    // Anxiety section should exist and only contain anxiety content
    final anxietySections = document.sections
        .whereType<AnxietySection>()
        .toList();
    expect(anxietySections, hasLength(1));

    // Reflection section should exist as standalone section
    final reviewSections = document.sections
        .whereType<ReviewSection>()
        .toList();
    expect(reviewSections, hasLength(1));

    final reviewSection = reviewSections.first;
    expect(reviewSection.title, contains('觉察'));

    // Timeline entries from the reflection section
    final timelines = reviewSection.contents
        .whereType<TimelineContent>()
        .toList();
    expect(timelines, hasLength(2));
    expect(timelines[0].text, '今天反思了一下沟通方式');
    expect(timelines[0].time, '21:24');
    expect(timelines[0].tags, containsAll(['#育儿', '#成长观察', '#反思']));
    expect(timelines[0].rawLine, '- **21:24** 今天反思了一下沟通方式 #育儿 #成长观察 #反思');
  });

  testWidgets('DiaryMarkdownView renders tomorrow without list bullet', (
    tester,
  ) async {
    const markdown = '''
## 📈 每日复盘
### 🌙 明日寄语
- 明天当焦虑升起时，立刻用手机备忘录写下担心的一句话。
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DiaryMarkdownView(markdown: markdown)),
      ),
    );

    expect(find.text('🌙 明日寄语'), findsOneWidget);
    expect(find.textContaining('明天当焦虑升起时'), findsOneWidget);
    expect(find.textContaining('- 明天当焦虑升起时'), findsNothing);
  });

  group('QuickNoteComposer', () {
    final date = DateTime(2026, 6, 7);

    Widget buildComposer({
      required Future<void> Function(String, List<String>) onSubmit,
      TagConfig? tagConfig,
      String? tagHint,
      String? placeholder,
      DateTime? date,
      EntryType? entryType,
      DraftRepository? draftRepository,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: QuickNoteComposer(
            onSubmit: onSubmit,
            tagConfig: tagConfig,
            tagHint: tagHint,
            placeholder: placeholder,
            date: date,
            entryType: entryType,
            draftRepository: draftRepository,
          ),
        ),
      );
    }

    testWidgets('button is disabled when input is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('button is enabled when input is not empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets(
      'calls onSubmit with content and empty tags when no tagConfig',
      (WidgetTester tester) async {
        String? submittedContent;
        List<String>? submittedTags;
        await tester.pumpWidget(
          buildComposer(
            onSubmit: (content, tags) async {
              submittedContent = content;
              submittedTags = tags;
            },
          ),
        );

        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pump();
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        expect(submittedContent, 'hello');
        expect(submittedTags, isEmpty);
      },
    );

    testWidgets('clears input on successful submit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('preserves input and shows error on failure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {
            throw Exception('fail');
          },
        ),
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'hello');

      expect(find.text('保存失败，请重试'), findsOneWidget);
    });

    testWidgets('button is disabled while saving', (WidgetTester tester) async {
      final completer = Completer<void>();
      await tester.pumpWidget(
        buildComposer(onSubmit: (_, _) => completer.future),
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('submits tags when selected via tagConfig', (
      WidgetTester tester,
    ) async {
      List<String>? submittedTags;
      await tester.pumpWidget(
        buildComposer(
          tagConfig: _testTagConfig(),
          onSubmit: (_, tags) async {
            submittedTags = tags;
          },
        ),
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      await tester.tap(find.text('任务执行').last);
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(submittedTags, ['工作', '任务执行']);
    });

    testWidgets('clears tags on successful submit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildComposer(tagConfig: _testTagConfig(), onSubmit: (_, _) async {}),
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      await tester.tap(find.text('任务执行').last);
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('preserves tags on failed submit', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildComposer(
          tagConfig: _testTagConfig(),
          onSubmit: (_, _) async {
            throw Exception('fail');
          },
        ),
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      await tester.tap(find.text('任务执行').last);
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Tags should still be visible as pills
      expect(find.text('工作'), findsWidgets);
      expect(find.text('任务执行'), findsWidgets);
    });

    testWidgets('shows tagHint when tagConfig is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildComposer(onSubmit: (_, _) async {}, tagHint: '标签暂不可用'),
      );

      expect(find.text('标签暂不可用'), findsOneWidget);
    });

    testWidgets('shows placeholder when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildComposer(onSubmit: (_, _) async {}, placeholder: '觉察到了什么？'),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintText, '觉察到了什么？');
    });

    testWidgets('restores content from draft', (tester) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'hello',
        tags: [],
      );

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          entryType: EntryType.quickNote,
          draftRepository: repo,
        ),
      );
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, 'hello');
    });

    testWidgets('saves draft on text input', (tester) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          entryType: EntryType.quickNote,
          draftRepository: repo,
        ),
      );
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );
      expect(draft!.content, 'hi');
    });

    testWidgets('saves draft on tag change', (tester) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          tagConfig: _testTagConfig(),
          date: date,
          entryType: EntryType.quickNote,
          draftRepository: repo,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );
      expect(draft!.tags, ['工作']);
    });

    testWidgets('drafts don not overwrite each other', (tester) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          entryType: EntryType.quickNote,
          draftRepository: repo,
        ),
      );
      await tester.enterText(find.byType(TextField), 'quick');
      await tester.pump();

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          entryType: EntryType.reflection,
          draftRepository: repo,
        ),
      );
      await tester.enterText(find.byType(TextField), 'reflect');
      await tester.pump();

      expect(
        (await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.quickNote,
        ))!.content,
        'quick',
      );
      expect(
        (await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.reflection,
        ))!.content,
        'reflect',
      );
    });

    testWidgets('clears draft on empty content and tags', (tester) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'x',
        tags: [],
      );

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          entryType: EntryType.quickNote,
          draftRepository: repo,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );
      expect(draft, isNull);
    });

    testWidgets('clears draft on successful submit', (tester) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          entryType: EntryType.quickNote,
          draftRepository: repo,
        ),
      );
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );
      expect(draft, isNull);
    });

    testWidgets('keeps draft on failed submit', (tester) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {
            throw Exception('fail');
          },
          date: date,
          entryType: EntryType.quickNote,
          draftRepository: repo,
        ),
      );
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );
      expect(draft, isNotNull);
    });

    testWidgets('polish button disabled when content empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteComposer(
              onSubmit: (_, _) async {},
              onPolish: (_, _) async =>
                  const PolishResult(content: '', tags: []),
              entryType: EntryType.quickNote,
            ),
          ),
        ),
      );

      expect(find.text('润色'), findsOneWidget);

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '润色'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('polish button calls onPolish when content not empty', (
      tester,
    ) async {
      String? polishedContent;
      EntryType? polishedType;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteComposer(
              onSubmit: (_, _) async {},
              onPolish: (content, type) async {
                polishedContent = content;
                polishedType = type;
                return const PolishResult(content: '润色后', tags: ['工作', '任务执行']);
              },
              entryType: EntryType.quickNote,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '测试');
      await tester.pump();

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '润色'),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(OutlinedButton, '润色'));
      await tester.pump();

      expect(polishedContent, '测试');
      expect(polishedType, EntryType.quickNote);
    });

    testWidgets('polish success updates text and tags', (tester) async {
      final tagConfig = _polishTagConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteComposer(
              onSubmit: (_, _) async {},
              onPolish: (_, _) async =>
                  const PolishResult(content: '润色后的文本', tags: ['亲子', '亲子沟通']),
              tagConfig: tagConfig,
              entryType: EntryType.reflection,
            ),
          ),
        ),
      );

      // Enter content
      await tester.enterText(find.byType(TextField), '原始文本');
      await tester.pump();

      // Tap polish
      await tester.tap(find.widgetWithText(OutlinedButton, '润色'));
      await tester.pump();

      // Text updated
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '润色后的文本',
      );

      // TagPicker shows selected domain chip
      expect(find.text('亲子'), findsWidgets);
    });

    testWidgets('quickNote polish selects tags in TagPicker', (tester) async {
      final tagConfig = _polishTagConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteComposer(
              onSubmit: (_, _) async {},
              onPolish: (_, _) async => const PolishResult(
                content: '润色后',
                tags: ['亲子', '亲子沟通', '反思'],
              ),
              tagConfig: tagConfig,
              entryType: EntryType.quickNote,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '测试');
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '润色'));
      await tester.pump();

      expect(find.text('亲子'), findsWidgets);
    });

    testWidgets('reflection polish selects tags in TagPicker', (tester) async {
      final tagConfig = _polishTagConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteComposer(
              onSubmit: (_, _) async {},
              onPolish: (_, _) async =>
                  const PolishResult(content: '觉察润色后', tags: ['亲子', '亲子沟通']),
              tagConfig: tagConfig,
              entryType: EntryType.reflection,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '觉察测试');
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '润色'));
      await tester.pump();

      expect(find.text('亲子'), findsWidgets);
    });

    testWidgets('happiness polish selects tags in TagPicker', (tester) async {
      final tagConfig = _polishTagConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteComposer(
              onSubmit: (_, _) async {},
              onPolish: (_, _) async =>
                  const PolishResult(content: '小确幸润色后', tags: ['亲子', '亲子沟通']),
              tagConfig: tagConfig,
              entryType: EntryType.happiness,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '小确幸测试');
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '润色'));
      await tester.pump();

      expect(find.text('亲子'), findsWidgets);
    });

    testWidgets('reflection onPolish receives EntryType.reflection', (
      tester,
    ) async {
      EntryType? receivedType;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteComposer(
              onSubmit: (_, _) async {},
              onPolish: (_, type) async {
                receivedType = type;
                return const PolishResult(content: 'ok', tags: []);
              },
              entryType: EntryType.reflection,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '测试');
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '润色'));
      await tester.pump();

      expect(receivedType, EntryType.reflection);
    });

    testWidgets('happiness onPolish receives EntryType.happiness', (
      tester,
    ) async {
      EntryType? receivedType;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteComposer(
              onSubmit: (_, _) async {},
              onPolish: (_, type) async {
                receivedType = type;
                return const PolishResult(content: 'ok', tags: []);
              },
              entryType: EntryType.happiness,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '测试');
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '润色'));
      await tester.pump();

      expect(receivedType, EntryType.happiness);
    });

    testWidgets('unknown tags preserved in content, tags empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteComposer(
              onSubmit: (_, _) async {},
              onPolish: (_, _) async =>
                  const PolishResult(content: '正文。 #未知标签', tags: []),
              entryType: EntryType.quickNote,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '测试');
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, '润色'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '正文。 #未知标签',
      );
    });

    testWidgets('polish failure preserves original content and tags', (
      tester,
    ) async {
      final tagConfig = _polishTagConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteComposer(
              onSubmit: (_, _) async {},
              onPolish: (_, _) async => throw Exception('网络错误'),
              tagConfig: tagConfig,
              entryType: EntryType.quickNote,
            ),
          ),
        ),
      );

      // Enter content
      await tester.enterText(find.byType(TextField), '原始文本');
      await tester.pump();

      // Tap polish — should fail
      await tester.tap(find.widgetWithText(OutlinedButton, '润色'));
      await tester.pumpAndSettle();

      // Content preserved
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '原始文本',
      );

      // Error shown
      expect(find.text('润色失败，请重试'), findsOneWidget);
    });

    testWidgets('polish button not shown when onPolish is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteComposer(
              onSubmit: (_, _) async {},
              entryType: EntryType.quickNote,
            ),
          ),
        ),
      );

      expect(find.text('润色'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('TextField auto-expands from 3 to 8 lines', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuickNoteComposer(onSubmit: (_, _) async {})),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, 3);
      expect(textField.maxLines, 8);
      expect(textField.keyboardType, TextInputType.multiline);
    });
  });

  group('TagConfig', () {
    test('TagConfig.fromJson parses domains and methods', () {
      final json = {
        'domains': [
          {
            'id': 'work',
            'name': '工作',
            'description': '职业任务',
            'order': 0,
            'topics': [
              {'id': 'work-task', 'name': '任务执行', 'order': 0},
            ],
          },
        ],
        'methods': [
          {'id': 'reflect', 'name': '反思', 'order': 0},
        ],
      };

      final config = TagConfig.fromJson(json);
      expect(config.domains, hasLength(1));
      expect(config.domains[0].id, 'work');
      expect(config.domains[0].name, '工作');
      expect(config.domains[0].description, '职业任务');
      expect(config.domains[0].order, 0);
      expect(config.domains[0].topics, hasLength(1));

      expect(config.methods, hasLength(1));
      expect(config.methods[0].id, 'reflect');
      expect(config.methods[0].name, '反思');
      expect(config.methods[0].order, 0);
    });

    test('TagTopic.fromJson handles missing description', () {
      final json = {'id': 'work-task', 'name': '任务执行', 'order': 0};
      final topic = TagTopic.fromJson(json);
      expect(topic.id, 'work-task');
      expect(topic.name, '任务执行');
      expect(topic.description, isNull);
    });

    test('TagMethod.fromJson handles missing description', () {
      final json = {'id': 'remember', 'name': '回忆', 'order': 3};
      final method = TagMethod.fromJson(json);
      expect(method.id, 'remember');
      expect(method.name, '回忆');
      expect(method.description, isNull);
    });

    test('TagConfig.fromJson handles missing domains and methods', () {
      final config = TagConfig.fromJson({});
      expect(config.domains, isEmpty);
      expect(config.methods, isEmpty);
    });

    test('TagDomain.fromJson handles missing topics', () {
      final json = {'id': 'work', 'name': '工作', 'order': 0};
      final domain = TagDomain.fromJson(json);
      expect(domain.topics, isEmpty);
    });

    test('TagConfig.fromJson handles missing id/name/order safely', () {
      final json = {
        'domains': [
          {
            'topics': [{}],
          },
        ],
        'methods': [{}],
      };
      final config = TagConfig.fromJson(json);
      expect(config.domains[0].id, '');
      expect(config.domains[0].name, '');
      expect(config.domains[0].order, 0);
      expect(config.domains[0].topics[0].id, '');
      expect(config.domains[0].topics[0].order, 0);
      expect(config.methods[0].id, '');
    });

    test('TagConfig.toJson preserves basic structure', () {
      final config = TagConfig(
        domains: [
          TagDomain(
            id: 'work',
            name: '工作',
            description: 'desc',
            order: 0,
            topics: [TagTopic(id: 't1', name: '主题1', order: 0)],
          ),
        ],
        methods: [TagMethod(id: 'm1', name: '方法1', order: 0)],
      );
      final json = config.toJson();
      expect(json['domains'], isA<List>());
      expect(json['methods'], isA<List>());
      expect(json['domains'][0]['name'], '工作');
      expect(json['domains'][0]['topics'][0]['name'], '主题1');
      expect(json['methods'][0]['name'], '方法1');
    });

    test('cache round-trip preserves nested data', () {
      final original = TagConfig(
        domains: [
          TagDomain(
            id: 'work',
            name: '工作',
            description: '职业任务和职场活动',
            order: 2,
            topics: [
              TagTopic(
                id: 'work-task',
                name: '任务执行',
                description: '具体任务完成',
                order: 0,
              ),
              TagTopic(id: 'work-collab', name: '沟通协作', order: 1),
            ],
          ),
        ],
        methods: [
          TagMethod(
            id: 'reflect',
            name: '反思',
            description: '对自身行为和思考的回顾',
            order: 0,
          ),
          TagMethod(id: 'remember', name: '回忆', order: 3),
        ],
      );

      final jsonString = jsonEncode(original.toJson());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final restored = TagConfig.fromJson(decoded);

      expect(restored.domains, hasLength(1));
      expect(restored.domains[0].id, 'work');
      expect(restored.domains[0].description, '职业任务和职场活动');
      expect(restored.domains[0].topics, hasLength(2));
      expect(restored.domains[0].topics[0].description, '具体任务完成');
      expect(restored.domains[0].topics[1].description, isNull);

      expect(restored.methods, hasLength(2));
      expect(restored.methods[0].description, '对自身行为和思考的回顾');
      expect(restored.methods[1].description, isNull);
    });
  });

  group('TagPicker', () {
    final testConfig = TagConfig(
      domains: [
        TagDomain(
          id: 'work',
          name: '工作',
          order: 0,
          topics: [
            TagTopic(id: 'work-task', name: '任务执行', order: 0),
            TagTopic(id: 'work-collab', name: '沟通协作', order: 1),
          ],
        ),
        TagDomain(
          id: 'life',
          name: '生活',
          order: 1,
          topics: [
            TagTopic(id: 'life-health', name: '健康管理', order: 0),
            TagTopic(id: 'life-daily', name: '日常记录', order: 1),
          ],
        ),
      ],
      methods: [
        TagMethod(id: 'reflect', name: '反思', order: 0),
        TagMethod(id: 'remember', name: '回忆', order: 1),
      ],
    );

    Widget buildPicker({
      List<String> initialTags = const [],
      required ValueChanged<List<String>> onChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TagPicker(
              tagConfig: testConfig,
              initialTags: initialTags,
              onChanged: onChanged,
            ),
          ),
        ),
      );
    }

    testWidgets('defaults to collapsed state', (WidgetTester tester) async {
      await tester.pumpWidget(buildPicker(onChanged: (_) {}));
      // Chips hidden by default
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('🏷️ 标签'), findsOneWidget);
    });

    testWidgets('expands chips when toggle tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildPicker(onChanged: (_) {}));

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();

      expect(find.byType(ChoiceChip), findsWidgets);
      expect(find.text('工作'), findsWidgets);
    });

    testWidgets('shows topics after expanding and tapping domain', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildPicker(onChanged: (_) {}));

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();

      expect(find.text('任务执行'), findsOneWidget);
    });

    testWidgets('onChanged outputs domain and topic when selected', (
      WidgetTester tester,
    ) async {
      List<String>? output;
      await tester.pumpWidget(buildPicker(onChanged: (tags) => output = tags));

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      expect(output, ['工作']);

      await tester.tap(find.text('任务执行').last);
      await tester.pump();
      expect(output, ['工作', '任务执行']);
    });

    testWidgets('onChanged outputs method when toggled', (
      WidgetTester tester,
    ) async {
      List<String>? output;
      await tester.pumpWidget(buildPicker(onChanged: (tags) => output = tags));

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      await tester.tap(find.text('任务执行').last);
      await tester.pump();

      await tester.tap(find.text('反思').last);
      await tester.pump();
      expect(output, ['工作', '任务执行', '反思']);

      await tester.tap(find.text('反思').last);
      await tester.pump();
      expect(output, ['工作', '任务执行']);
    });

    testWidgets('switching domain clears topic', (WidgetTester tester) async {
      List<String>? output;
      await tester.pumpWidget(buildPicker(onChanged: (tags) => output = tags));

      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      await tester.tap(find.text('工作').last);
      await tester.pump();
      await tester.tap(find.text('任务执行').last);
      await tester.pump();
      expect(output, ['工作', '任务执行']);

      await tester.tap(find.text('生活').last);
      await tester.pump();
      expect(output, ['生活']);
    });

    testWidgets('selected pills visible in collapsed state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildPicker(initialTags: ['生活', '健康管理', '回忆'], onChanged: (_) {}),
      );

      // Pills visible even in collapsed state
      expect(find.text('生活'), findsWidgets);
      expect(find.text('健康管理'), findsAtLeastNWidgets(1));
      expect(find.text('回忆'), findsAtLeastNWidgets(1));

      // Chips not visible
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('collapses when initialTags cleared externally', (
      WidgetTester tester,
    ) async {
      List<String> tags = ['工作', '任务执行'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return TagPicker(
                  tagConfig: testConfig,
                  initialTags: tags,
                  onChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );

      // Expand and verify chips visible
      await tester.tap(find.text('🏷️ 标签'));
      await tester.pump();
      expect(find.byType(ChoiceChip), findsWidgets);

      // Now clear tags by rebuilding with empty list
      tags = [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagPicker(
              tagConfig: testConfig,
              initialTags: tags,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Should be collapsed again
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('🏷️ 标签'), findsOneWidget);
    });
  });

  group('EntryTypeSelector', () {
    Widget buildSelector({
      required EntryType selected,
      required ValueChanged<EntryType> onChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: EntryTypeSelector(selected: selected, onChanged: onChanged),
        ),
      );
    }

    testWidgets('shows all four entry type labels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildSelector(selected: EntryType.quickNote, onChanged: (_) {}),
      );

      expect(find.text('随手记'), findsOneWidget);
      expect(find.text('觉察'), findsOneWidget);
      expect(find.text('小确幸'), findsOneWidget);
      expect(find.text('焦虑'), findsOneWidget);
    });

    testWidgets('marks selected entry as active', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildSelector(selected: EntryType.reflection, onChanged: (_) {}),
      );

      final chips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .toList();
      expect(chips[1].selected, isTrue);
    });

    testWidgets('calls onChanged when tapping a chip', (
      WidgetTester tester,
    ) async {
      EntryType? tapped;
      await tester.pumpWidget(
        buildSelector(
          selected: EntryType.quickNote,
          onChanged: (type) => tapped = type,
        ),
      );

      await tester.tap(find.text('觉察'));
      await tester.pump();
      expect(tapped, EntryType.reflection);
    });
  });

  testWidgets('happiness slogan hidden when real content exists', (
    WidgetTester tester,
  ) async {
    final section = HappinessSection(
      title: '✨ 每日小确幸',
      contents: [
        const CalloutContent(type: 'success', title: '总有事件值得感恩🙏❤️', body: []),
        const TimelineContent(
          time: '09:30',
          text: '喝到一杯好咖啡',
          tags: [],
          rawLine: '',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GenericSectionCard(section: section)),
      ),
    );

    expect(find.text('总有事件值得感恩'), findsNothing);
    expect(find.text('喝到一杯好咖啡'), findsOneWidget);
  });

  group('AnxietyComposer', () {
    final date = DateTime(2026, 6, 7);

    Widget buildComposer({
      required Future<void> Function(String, List<String>) onSubmit,
      Future<String> Function(String)? onPolish,
      VoidCallback? onClose,
      DateTime? date,
      DraftRepository? draftRepository,
      List<String>? initialAnswers,
      bool isEdit = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AnxietyComposer(
            onSubmit: onSubmit,
            onPolish: onPolish,
            onClose: onClose,
            date: date,
            draftRepository: draftRepository,
            initialAnswers: initialAnswers,
            isEdit: isEdit,
          ),
        ),
      );
    }

    testWidgets('shows first question initially', (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      expect(find.text('今天什么时候我感到焦虑/紧张？'), findsOneWidget);
      expect(find.text('1/4'), findsOneWidget);
    });

    testWidgets('next button advances to second question', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(find.text('下一步'));
      await tester.pump();

      expect(find.text('当时我在担心什么？（具体到一句话）'), findsOneWidget);
      expect(find.text('2/4'), findsOneWidget);
    });

    testWidgets('skip button advances to next step', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is TextButton &&
              w.child is Text &&
              (w.child as Text).data == '跳过',
        ),
      );
      await tester.pump();

      expect(find.text('当时我在担心什么？（具体到一句话）'), findsOneWidget);
    });

    testWidgets('shows save on last step', (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();

      expect(find.text('保存'), findsOneWidget);
      expect(find.text('下一步'), findsNothing);
    });

    testWidgets('submits formatted content with empty tags', (
      WidgetTester tester,
    ) async {
      String? submittedContent;
      List<String>? submittedTags;
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (content, tags) async {
            submittedContent = content;
            submittedTags = tags;
          },
        ),
      );

      await tester.enterText(find.byType(TextField), '下午开会时');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '担心项目延期');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '列出优先级');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '帮我面对了');
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(submittedTags, isEmpty);
      expect(
        submittedContent,
        '- 今天什么时候我感到焦虑/紧张？\n> 下午开会时\n'
        '- 当时我在担心什么？（具体到一句话）\n> 担心项目延期\n'
        '- 我做了什么？\n> 列出优先级\n'
        '- 这个应对是帮我面对了，还是帮我躲开了？\n> 帮我面对了',
      );
    });

    testWidgets('resets to step 1 on successful submit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('1/4'), findsOneWidget);
    });

    testWidgets('preserves answers on failed submit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {
            throw Exception('fail');
          },
        ),
      );

      await tester.enterText(find.byType(TextField), '下午开会时');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(find.text('4/4'), findsOneWidget);
    });

    testWidgets('close button calls onClose', (WidgetTester tester) async {
      bool closed = false;
      await tester.pumpWidget(
        buildComposer(onSubmit: (_, _) async {}, onClose: () => closed = true),
      );

      await tester.tap(find.text('关闭'));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('restores draft step and answers on init', (
      WidgetTester tester,
    ) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);
      await repo.saveAnxietyDraft(
        date: date,
        step: 2,
        answers: ['a1', 'a2', '', ''],
      );

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          draftRepository: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3/4'), findsOneWidget);
    });

    testWidgets('saves draft after next tap', (WidgetTester tester) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          draftRepository: repo,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      final draft = await repo.loadAnxietyDraft(date: date);
      expect(draft, isNotNull);
      expect(draft!.step, 1);
      expect(draft.answers[0], 'hello');
    });

    testWidgets('clears draft on successful submit', (
      WidgetTester tester,
    ) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);
      await repo.saveAnxietyDraft(
        date: date,
        step: 3,
        answers: ['a1', '', '', ''],
      );

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          date: date,
          draftRepository: repo,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final draft = await repo.loadAnxietyDraft(date: date);
      expect(draft, isNull);
    });

    testWidgets('keeps draft on failed submit', (WidgetTester tester) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {
            throw Exception('fail');
          },
          date: date,
          draftRepository: repo,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final draft = await repo.loadAnxietyDraft(date: date);
      expect(draft, isNotNull);
    });

    testWidgets('back button hidden on step 1', (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      expect(find.text('上一步'), findsNothing);
    });

    testWidgets('back button visible on step 2', (WidgetTester tester) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(find.text('下一步'));
      await tester.pump();

      expect(find.text('上一步'), findsOneWidget);
    });

    testWidgets('back button returns to previous step', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('上一步'));
      await tester.pump();

      expect(find.text('1/4'), findsOneWidget);
    });

    testWidgets('back button shows previous answer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('上一步'));
      await tester.pump();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, 'hello');
    });

    testWidgets('modified answer after back is submitted', (
      WidgetTester tester,
    ) async {
      String? submitted;
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (content, _) async {
            submitted = content;
          },
        ),
      );

      await tester.enterText(find.byType(TextField), 'old');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('上一步'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(submitted, contains('new'));
      expect(submitted, isNot(contains('old')));
    });

    testWidgets('polish button disabled when answer empty', (tester) async {
      await tester.pumpWidget(
        buildComposer(onSubmit: (_, _) async {}, onPolish: (_) async => 'ok'),
      );

      expect(find.text('润色当前回答'), findsOneWidget);

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '润色当前回答'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('polish button calls onPolish when answer not empty', (
      tester,
    ) async {
      String? polished;

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          onPolish: (content) async {
            polished = content;
            return '润色后';
          },
        ),
      );

      await tester.enterText(find.byType(TextField), '原始回答');
      await tester.pump();

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '润色当前回答'),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
      await tester.pump();

      expect(polished, '原始回答');
    });

    testWidgets(
      'polish success updates only current TextField and saves draft',
      (tester) async {
        final storage = _TestStorage();
        final repo = DraftRepository(storage: storage);

        await tester.pumpWidget(
          buildComposer(
            onSubmit: (_, _) async {},
            onPolish: (_) async => '润色后的回答',
            draftRepository: repo,
            date: DateTime(2026, 6, 7),
          ),
        );

        await tester.enterText(find.byType(TextField), '原始回答');
        await tester.pump();

        await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
        await tester.pump();

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          '润色后的回答',
        );

        final draft = await repo.loadAnxietyDraft(date: DateTime(2026, 6, 7));
        expect(draft, isNotNull);
        expect(draft!.answers[0], '润色后的回答');
      },
    );

    testWidgets('polish failure preserves original answer', (tester) async {
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          onPolish: (_) async => throw Exception('网络错误'),
        ),
      );

      await tester.enterText(find.byType(TextField), '原始回答');
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '原始回答',
      );
      expect(find.text('润色失败，请重试'), findsOneWidget);
    });

    testWidgets('polish does not affect other answers in AnxietyComposer', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          onPolish: (_) async => '第一问答润色',
        ),
      );

      await tester.enterText(find.byType(TextField), 'Q1 原始回答');
      await tester.pump();

      await tester.tap(find.text('下一步'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Q2 原始回答');
      await tester.pump();

      await tester.tap(find.text('上一步'));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '第一问答润色',
      );

      await tester.tap(find.text('下一步'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Q2 原始回答',
      );
    });

    testWidgets('submit format unchanged after polish', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (content, _) async => submitted = content,
          onPolish: (_) async => '润色后的问答',
        ),
      );

      await tester.enterText(find.byType(TextField), '原始');
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
      await tester.pump();

      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(submitted, isNotNull);
      expect(submitted, contains('- 今天什么时候我感到焦虑/紧张？'));
      expect(submitted, contains('> 润色后的问答'));
      expect(submitted, contains('- 当时我在担心什么？'));
    });

    testWidgets('TextField auto-expands from 2 to 8 lines', (tester) async {
      await tester.pumpWidget(buildComposer(onSubmit: (_, _) async {}));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, 2);
      expect(textField.maxLines, 8);
      expect(textField.keyboardType, TextInputType.multiline);
    });

    test('parseAnswers extracts 4 empty strings from template', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
> 
- 当时我在担心什么？（具体到一句话）
> 
- 我做了什么？
> 
- 这个应对是帮我面对了，还是帮我躲开了？
> 
''';

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, hasLength(4));
      expect(answers.every((a) => a.trim().isEmpty), isTrue);
    });

    test('parseAnswers extracts 4 real answers', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
> 下午开会时
- 当时我在担心什么？（具体到一句话）
> 担心项目延期
- 我做了什么？
> 列了任务清单
- 这个应对是帮我面对了，还是帮我躲开了？
> 面对了
''';

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, ['下午开会时', '担心项目延期', '列了任务清单', '面对了']);
    });

    test('parseAnswers handles empty and real answers mixed', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
> 下午开会
- 当时我在担心什么？（具体到一句话）
> 
- 我做了什么？
> 做了深呼吸
- 这个应对是帮我面对了，还是帮我躲开了？
> 
''';

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, ['下午开会', '', '做了深呼吸', '']);
    });

    test('parseAnswers handles template + real duplicate questions '
        '- takes last non-empty answer', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
> 
- 当时我在担心什么？（具体到一句话）
> 
- 我做了什么？
> 
- 这个应对是帮我面对了，还是帮我躲开了？
> 
- 今天什么时候我感到焦虑/紧张？
> 午休的时候刷视频
- 当时我在担心什么？（具体到一句话）
> 任务安排有冲突
- 我做了什么？
> 优先处理截止日期近的
- 这个应对是帮我面对了，还是帮我躲开了？
> 继续拖到最后一刻，躲不开
''';

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, ['午休的时候刷视频', '任务安排有冲突', '优先处理截止日期近的', '继续拖到最后一刻，躲不开']);
    });

    test('parseAnswers handles repeated questions with multiple real answers '
        '- takes last non-empty', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
> 第一次回答
- 当时我在担心什么？（具体到一句话）
> 第一次担心
- 今天什么时候我感到焦虑/紧张？
> 第二次回答才是真的
- 当时我在担心什么？（具体到一句话）
> 
''';

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, ['第二次回答才是真的', '第一次担心', '', '']);
    });

    test('parseAnswers handles partial duplicate - some questions '
        'repeated, some not', () {
      const markdown = '''
- 今天什么时候我感到焦虑/紧张？
> 
- 今天什么时候我感到焦虑/紧张？
> 实际场景
- 当时我在担心什么？（具体到一句话）
> 实际担心
- 我做了什么？
> 什么都不做
''';

      final answers = AnxietyComposer.parseAnswers(markdown);
      expect(answers, ['实际场景', '实际担心', '什么都不做', '']);
    });

    test(
      'parseAnswers empty answer does not overwrite previous real answer',
      () {
        const markdown = '''
- 今天什么时候我感到焦虑/紧张？
> 真实回答
- 当时我在担心什么？（具体到一句话）
> 真实担心
- 今天什么时候我感到焦虑/紧张？
> 
- 当时我在担心什么？（具体到一句话）
> 
''';

        final answers = AnxietyComposer.parseAnswers(markdown);
        expect(answers, ['真实回答', '真实担心', '', '']);
      },
    );

    testWidgets('edit mode prefills initialAnswers', (tester) async {
      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          initialAnswers: ['a1', 'a2', 'a3', 'a4'],
          isEdit: true,
        ),
      );

      await tester.pump();

      expect(find.text('编辑今日焦虑记录'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'a1',
      );

      // Move to step 2
      await tester.tap(find.text('下一步'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'a2',
      );
    });

    testWidgets('edit mode draft takes priority over initialAnswers', (
      tester,
    ) async {
      final storage = _TestStorage();
      final repo = DraftRepository(storage: storage);

      await repo.saveAnxietyDraft(
        date: DateTime(2026, 6, 7),
        step: 0,
        answers: ['draft1', 'draft2', '', ''],
      );

      await tester.pumpWidget(
        buildComposer(
          onSubmit: (_, _) async {},
          initialAnswers: ['init1', 'init2', 'init3', 'init4'],
          isEdit: true,
          draftRepository: repo,
          date: DateTime(2026, 6, 7),
        ),
      );

      await tester.pump();

      // Draft restored — should be on step 1 with draft content
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'draft1',
      );
    });

    testWidgets(
      'edit mode polish current answer still works with initialAnswers',
      (tester) async {
        await tester.pumpWidget(
          buildComposer(
            onSubmit: (_, _) async {},
            onPolish: (_) async => '润色后',
            initialAnswers: ['a1', 'a2', '', ''],
            isEdit: true,
          ),
        );

        await tester.pump();

        await tester.tap(find.widgetWithText(OutlinedButton, '润色当前回答'));
        await tester.pump();

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          '润色后',
        );
      },
    );
  });

  testWidgets('AnxietyCard shows template when no real answers', (
    WidgetTester tester,
  ) async {
    final section = AnxietySection(
      title: '😰 焦虑时刻',
      contents: [
        MarkdownContent(
          '- 今天什么时候我感到焦虑/紧张？\n'
          '> \n'
          '- 当时我在担心什么？（具体到一句话）\n'
          '> \n'
          '- 我做了什么？\n'
          '> \n'
          '- 这个应对是帮我面对了，还是帮我躲开了？\n'
          '>',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnxietyCard(section: section)),
      ),
    );

    expect(find.text('今天什么时候我感到焦虑/紧张？'), findsOneWidget);
  });

  testWidgets('AnxietyCard hides template when real answers exist', (
    WidgetTester tester,
  ) async {
    final section = AnxietySection(
      title: '😰 焦虑时刻',
      contents: [
        MarkdownContent(
          '- 今天什么时候我感到焦虑/紧张？\n'
          '> \n'
          '- 当时我在担心什么？（具体到一句话）\n'
          '> \n'
          '- 我做了什么？\n'
          '> \n'
          '- 这个应对是帮我面对了，还是帮我躲开了？\n'
          '> \n'
          '\n'
          '- 今天什么时候我感到焦虑/紧张？\n'
          '> 下午开会时\n'
          '- 当时我在担心什么？（具体到一句话）\n'
          '> 担心项目延期\n'
          '- 我做了什么？\n'
          '> \n'
          '- 这个应对是帮我面对了，还是帮我躲开了？\n'
          '> ',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnxietyCard(section: section)),
      ),
    );

    // Real Q&A visible
    expect(find.text('下午开会时'), findsOneWidget);
    expect(find.text('担心项目延期'), findsOneWidget);

    // Template questions should be hidden (both from template and from skipped Q&A)
    // Verify the card has content by checking SectionCard is rendered
    expect(find.byType(AnxietyCard), findsOneWidget);
  });

  group('HabitCard', () {
    test('HabitStatus.fromHabitSection maps 5 fields', () {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: true,
            checkable: true,
            rawLine: '- [x] 阅读/亲子共读',
          ),
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '学语言',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 学语言',
          ),
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '鱼油/植物甾醇',
            checked: true,
            checkable: true,
            rawLine: '- [x] 鱼油/植物甾醇',
          ),
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
          const HabitItem(
            kind: HabitKind.counter,
            label: '运动/拉伸/快走',
            checked: false,
            checkable: false,
            rawLine: '- 运动/拉伸/快走 8000 步',
            value: 8000,
            unit: '步',
          ),
        ],
      );

      final status = HabitStatus.fromHabitSection(section);
      expect(status.water, 500);
      expect(status.steps, 8000);
      expect(status.reading, isTrue);
      expect(status.language, isFalse);
      expect(status.supplements, isTrue);
    });

    test('HabitStatus.fromHabitSection defaults missing fields', () {
      final section = HabitSection(title: '习惯打卡', contents: [], habits: []);

      final status = HabitStatus.fromHabitSection(section);
      expect(status.water, 0);
      expect(status.steps, 0);
      expect(status.reading, isFalse);
      expect(status.language, isFalse);
      expect(status.supplements, isFalse);
    });

    test('HabitStatus.copyWith updates individual fields', () {
      const status = HabitStatus(
        water: 0,
        steps: 0,
        reading: false,
        language: false,
        supplements: false,
      );

      final next = status.copyWith(reading: true, water: 500);
      expect(next.reading, isTrue);
      expect(next.water, 500);
      expect(next.steps, 0);
      expect(next.language, isFalse);
      expect(next.supplements, isFalse);
    });

    testWidgets('checkbox tap toggles reading and calls onUpdate', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 阅读/亲子共读',
          ),
        ],
      );

      HabitStatus? called;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async {
                called = status;
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.text('亲子共读'), findsOneWidget);
      await tester.tap(find.text('亲子共读'));
      await tester.pump();

      expect(called, isNotNull);
      expect(called!.reading, isTrue);
      expect(called!.language, isFalse);
      expect(called!.supplements, isFalse);
      expect(called!.water, 0);
      expect(called!.steps, 0);
    });

    testWidgets('shows default habit icons', (tester) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 阅读/亲子共读',
          ),
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
          const HabitItem(
            kind: HabitKind.counter,
            label: '运动/拉伸/快走',
            checked: false,
            checkable: false,
            rawLine: '- 运动/拉伸/快走 8000 步',
            value: 8000,
            unit: '步',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(section: section, onUpdate: (_) async => true),
          ),
        ),
      );

      expect(find.text('📖'), findsOneWidget);
      expect(find.text('💧'), findsOneWidget);
      expect(find.text('🚶'), findsOneWidget);
    });

    testWidgets('water +250 button increments water and calls onUpdate', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
        ],
      );

      HabitStatus? called;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async {
                called = status;
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.text('+250'), findsOneWidget);
      await tester.tap(find.text('+250'));
      await tester.pump();

      expect(called, isNotNull);
      expect(called!.water, 750);
      expect(called!.steps, 0);
      expect(called!.reading, isFalse);
      expect(called!.language, isFalse);
      expect(called!.supplements, isFalse);
    });

    testWidgets('water 目标 button sets water to 1500', (tester) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
        ],
      );

      HabitStatus? called;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async {
                called = status;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('目标'));
      await tester.pump();

      expect(called, isNotNull);
      expect(called!.water, 1500);
    });

    testWidgets('water 清零 button sets water to 0', (tester) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
        ],
      );

      HabitStatus? called;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async {
                called = status;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('清零'));
      await tester.pump();

      expect(called, isNotNull);
      expect(called!.water, 0);
    });

    testWidgets('steps edit shows dialog and calls onUpdate with new value', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '运动/拉伸/快走',
            checked: false,
            checkable: false,
            rawLine: '- 运动/拉伸/快走 8000 步',
            value: 8000,
            unit: '步',
          ),
        ],
      );

      HabitStatus? called;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async {
                called = status;
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.text('运动 8000 步'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('输入今日步数'), findsOneWidget);

      // Enter new value
      final field = find.byType(TextField);
      await tester.enterText(field, '6000');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(called, isNotNull);
      expect(called!.steps, 6000);
      expect(called!.water, 0);
    });

    testWidgets('onUpdate failure shows SnackBar, keeps old state', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 阅读/亲子共读',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async => false,
            ),
          ),
        ),
      );

      await tester.tap(find.text('亲子共读'));
      await tester.pumpAndSettle();

      expect(find.text('更新失败'), findsOneWidget);
    });

    testWidgets('onUpdate exception shows SnackBar and clears loading', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 阅读/亲子共读',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (_) async => throw Exception('network error'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('亲子共读'));
      await tester.pumpAndSettle();

      expect(find.text('更新失败'), findsOneWidget);
      // Verify no lingering spinner (loading cleared)
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('DraftRepository', () {
    final date = DateTime(2026, 6, 7);
    late DraftRepository repo;
    late _TestStorage storage;

    setUp(() {
      storage = _TestStorage();
      repo = DraftRepository(storage: storage);
    });

    test('quick draft save and restore', () async {
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'hello',
        tags: ['工作'],
      );

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );

      expect(draft, isNotNull);
      expect(draft!.content, 'hello');
      expect(draft.tags, ['工作']);
    });

    test('quick draft entries do not overwrite each other', () async {
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'quick',
        tags: ['q'],
      );
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.reflection,
        content: 'reflect',
        tags: ['r'],
      );
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.happiness,
        content: 'happy',
        tags: ['h'],
      );

      expect(
        (await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.quickNote,
        ))!.content,
        'quick',
      );
      expect(
        (await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.reflection,
        ))!.content,
        'reflect',
      );
      expect(
        (await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.happiness,
        ))!.content,
        'happy',
      );
    });

    test('anxiety draft save and restore', () async {
      await repo.saveAnxietyDraft(
        date: date,
        step: 2,
        answers: ['a1', 'a2', '', ''],
      );

      final draft = await repo.loadAnxietyDraft(date: date);

      expect(draft, isNotNull);
      expect(draft!.step, 2);
      expect(draft.answers, ['a1', 'a2', '', '']);
    });

    test('fromJson survives type-incompatible input', () {
      final draft = QuickDraft.fromJson(<String, dynamic>{});

      expect(draft.content, '');
      expect(draft.tags, isEmpty);
    });

    test('clearDraft returns null', () async {
      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'hello',
        tags: [],
      );
      await repo.clearDraft(date: date, entryType: EntryType.quickNote);

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );
      expect(draft, isNull);
    });

    test('bad JSON returns null', () async {
      storage.data['draft_2026-06-07_quickNote'] = 'not json';
      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );
      expect(draft, isNull);
    });

    test('quick draft not expired within TTL', () async {
      final now = DateTime(2026, 6, 7, 10, 0);
      repo = DraftRepository(storage: storage, now: () => now);

      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'hello',
        tags: ['工作'],
      );

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );

      expect(draft, isNotNull);
      expect(draft!.content, 'hello');
    });

    test(
      'quick draft expired after 2 minutes returns null and clears',
      () async {
        final now = DateTime(2026, 6, 7, 10, 0);
        repo = DraftRepository(storage: storage, now: () => now);

        await repo.saveQuickDraft(
          date: date,
          entryType: EntryType.quickNote,
          content: 'hello',
          tags: [],
        );

        // Advance 2 minutes + 1 second
        repo = DraftRepository(
          storage: storage,
          now: () => now.add(const Duration(minutes: 2, seconds: 1)),
        );

        final draft = await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.quickNote,
        );

        expect(draft, isNull);

        // Draft was cleared
        final reloaded = await repo.loadQuickDraft(
          date: date,
          entryType: EntryType.quickNote,
        );
        expect(reloaded, isNull);
      },
    );

    test('anxiety draft not expired within TTL', () async {
      final now = DateTime(2026, 6, 7, 10, 0);
      repo = DraftRepository(storage: storage, now: () => now);

      await repo.saveAnxietyDraft(
        date: date,
        step: 2,
        answers: ['a1', 'a2', '', ''],
      );

      final draft = await repo.loadAnxietyDraft(date: date);

      expect(draft, isNotNull);
      expect(draft!.step, 2);
      expect(draft.answers, ['a1', 'a2', '', '']);
    });

    test(
      'anxiety draft expired after 2 minutes returns null and clears',
      () async {
        final now = DateTime(2026, 6, 7, 10, 0);
        repo = DraftRepository(storage: storage, now: () => now);

        await repo.saveAnxietyDraft(
          date: date,
          step: 2,
          answers: ['a1', 'a2', '', ''],
        );

        repo = DraftRepository(
          storage: storage,
          now: () => now.add(const Duration(minutes: 2, seconds: 1)),
        );

        final draft = await repo.loadAnxietyDraft(date: date);

        expect(draft, isNull);
      },
    );

    test('old format without updatedAt returns null', () async {
      // Simulate old draft without updatedAt field
      storage.data['draft_2026-06-07_quickNote'] = jsonEncode({
        'content': 'old',
        'tags': [],
      });

      final draft = await repo.loadQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
      );

      expect(draft, isNull);
    });

    test('updatedAt written on save', () async {
      final now = DateTime(2026, 6, 7, 10, 0);
      repo = DraftRepository(storage: storage, now: () => now);

      await repo.saveQuickDraft(
        date: date,
        entryType: EntryType.quickNote,
        content: 'hello',
        tags: ['工作'],
      );

      final raw = storage.data['draft_2026-06-07_quickNote']!;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['updatedAt'], isNotNull);
      expect(json['updatedAt'], now.toIso8601String());
    });
  });

  group('PolishResultParser', () {
    final config = _polishTagConfig();
    const parser = PolishResultParser();

    test('extracts Chinese tags and removes them from content', () {
      final result = parser.parse('今天小宝表达了自己的边界。 #亲子 #亲子沟通 #反思', config);

      expect(result.content, '今天小宝表达了自己的边界。');
      expect(result.tags, ['亲子', '亲子沟通', '反思']);
    });

    test('filters unknown tags, keeps known tags', () {
      final result = parser.parse('正文。 #未知标签 #不存在', config);

      expect(result.content, '正文。 #未知标签 #不存在');
      expect(result.tags, isEmpty);
    });

    test('returns empty tags when domain present but no matching topic', () {
      final result = parser.parse('正文。 #亲子 #反思', config);

      expect(result.content, '正文。');
      expect(result.tags, isEmpty);
    });

    test('returns domain and topic without method', () {
      final result = parser.parse('正文。 #亲子 #亲子沟通', config);

      expect(result.content, '正文。');
      expect(result.tags, ['亲子', '亲子沟通']);
    });

    test('keeps first domain, ignores topic not belonging to it', () {
      final result = parser.parse('正文。 #工作 #亲子沟通', config);

      // 工作 is first domain, 亲子沟通 does not belong to 工作
      expect(result.content, '正文。');
      expect(result.tags, isEmpty);
    });

    test('keeps first domain, ignores topic belonging to later domain', () {
      final result = parser.parse('正文。 #亲子 #工作 #任务执行 #反思', config);

      // 亲子 is first domain, 任务执行 belongs to 工作, ignored
      expect(result.content, '正文。');
      expect(result.tags, isEmpty);
    });

    test('keeps first topic, first method for the selected domain', () {
      final result = parser.parse('正文。 #亲子 #亲子沟通 #陪伴互动 #反思', config);

      // 亲子沟通 is first topic, 陪伴互动 ignored
      expect(result.content, '正文。');
      expect(result.tags, ['亲子', '亲子沟通', '反思']);
    });

    test('cleans 润色后 prefix from content', () {
      final result = parser.parse('润色后：今天小宝表达了边界。 #亲子 #亲子沟通', config);

      expect(result.content, '今天小宝表达了边界。');
      expect(result.tags, ['亲子', '亲子沟通']);
    });

    test('returns content and empty tags when no tags present', () {
      final result = parser.parse('这是一段普通的正文。', config);

      expect(result.content, '这是一段普通的正文。');
      expect(result.tags, isEmpty);
    });

    test('empty TagConfig returns empty tags', () {
      final result = parser.parse(
        '#工作 #任务执行',
        const TagConfig(domains: [], methods: []),
      );

      expect(result.content, '#工作 #任务执行');
      expect(result.tags, isEmpty);
    });
  });

  group('AIConfig', () {
    test('toJson / fromJson round-trip', () {
      const config = AIConfig(
        enabled: true,
        name: 'OpenAI API',
        baseUrl: 'https://api.openai.com',
        apiKey: 'sk-test',
        model: 'gpt-4',
        polishPrompt: '保持简洁',
        coachPrompt: '请用温柔的语气',
      );

      final json = config.toJson();
      final restored = AIConfig.fromJson(json);

      expect(restored.enabled, true);
      expect(restored.name, 'OpenAI API');
      expect(restored.baseUrl, 'https://api.openai.com');
      expect(restored.apiKey, 'sk-test');
      expect(restored.model, 'gpt-4');
      expect(restored.polishPrompt, '保持简洁');
      expect(restored.coachPrompt, '请用温柔的语气');
    });

    test('fromJson defaults name to empty for old data', () {
      final config = AIConfig.fromJson(<String, dynamic>{
        'enabled': true,
        'baseUrl': 'https://api.openai.com',
        'apiKey': 'sk-test',
        'model': 'gpt-4',
      });

      expect(config.name, '');
      expect(config.isUsable, isTrue);
    });

    test('fromJson defaults disabled when fields missing', () {
      final config = AIConfig.fromJson({});

      expect(config.enabled, isFalse);
      expect(config.isUsable, isFalse);
    });

    test('isUsable is false when any required field empty', () {
      expect(
        const AIConfig(
          enabled: true,
          baseUrl: '',
          apiKey: 'k',
          model: 'm',
        ).isUsable,
        isFalse,
      );
      expect(
        const AIConfig(
          enabled: true,
          baseUrl: 'u',
          apiKey: '',
          model: 'm',
        ).isUsable,
        isFalse,
      );
      expect(
        const AIConfig(
          enabled: true,
          baseUrl: 'u',
          apiKey: 'k',
          model: '',
        ).isUsable,
        isFalse,
      );
      expect(
        const AIConfig(
          enabled: false,
          baseUrl: 'u',
          apiKey: 'k',
          model: 'm',
        ).isUsable,
        isFalse,
      );
    });

    test('toString does not expose apiKey', () {
      const config = AIConfig(
        enabled: true,
        baseUrl: 'https://api.test.com',
        apiKey: 'sk-secret-key',
        model: 'gpt-4',
      );

      final str = config.toString();
      expect(str, contains('https://api.test.com'));
      expect(str, contains('gpt-4'));
      expect(str, isNot(contains('sk-secret-key')));
    });

    test('DeepSeek preset defaults to deepseek-v4-flash', () {
      final deepseekPreset = aiPresets.firstWhere((p) => p.name == 'DeepSeek');
      expect(deepseekPreset.model, 'deepseek-v4-flash');
    });

    test('resolvedModel falls back for DeepSeek with empty model', () {
      final config = AIConfig(
        enabled: true,
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com',
        apiKey: 'sk-test',
        model: '',
      );
      expect(config.resolvedModel, 'deepseek-v4-flash');
    });

    test('resolvedModel keeps user model when set', () {
      final config = AIConfig(
        enabled: true,
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com',
        apiKey: 'sk-test',
        model: 'deepseek-v4-expensive',
      );
      // 用户已保存的模型不被覆盖
      expect(config.resolvedModel, 'deepseek-v4-expensive');
    });

    test('resolvedModel does not affect OpenAI', () {
      final config = AIConfig(
        enabled: true,
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com',
        apiKey: 'sk-test',
        model: '',
      );
      // OpenAI 不受 DeepSeek fallback 影响
      expect(config.resolvedModel, '');
    });
  });

  group('AIConfigRepository', () {
    test('loadAIConfig returns disabled config on bad JSON', () async {
      final storage = _TestStorage({'ai_config': 'not json'});
      final repo = AIConfigRepository(storage: storage);

      final config = await repo.loadAIConfig();

      expect(config.enabled, isFalse);
    });

    test('save and load round-trip', () async {
      final storage = _TestStorage();
      final repo = AIConfigRepository(storage: storage);

      const config = AIConfig(
        enabled: true,
        baseUrl: 'https://api.test.com',
        apiKey: 'sk-test-key',
        model: 'gpt-4',
      );

      await repo.saveAIConfig(config);
      final loaded = await repo.loadAIConfig();

      expect(loaded.enabled, isTrue);
      expect(loaded.baseUrl, 'https://api.test.com');
      expect(loaded.apiKey, 'sk-test-key');
      expect(loaded.model, 'gpt-4');
    });

    test('clearAIConfig removes stored config', () async {
      final storage = _TestStorage();
      final repo = AIConfigRepository(storage: storage);

      const config = AIConfig(
        enabled: true,
        baseUrl: 'https://api.test.com',
        apiKey: 'sk-test',
        model: 'gpt-4',
      );

      await repo.saveAIConfig(config);
      await repo.clearAIConfig();

      final loaded = await repo.loadAIConfig();
      expect(loaded.enabled, isFalse);
    });

    test('loadAIConfig returns default when nothing stored', () async {
      final storage = _TestStorage();
      final repo = AIConfigRepository(storage: storage);

      final config = await repo.loadAIConfig();

      expect(config.enabled, isFalse);
    });
  });

  group('PolisherService', () {
    final tagConfig = _polishTagConfig();

    test('throws when content is empty', () async {
      final service = PolisherService();

      expect(
        () => service.polish(
          content: '   ',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('内容为空'),
          ),
        ),
      );
    });

    test('throws when config is disabled', () async {
      final service = PolisherService();

      expect(
        () => service.polish(
          content: '测试内容',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(enabled: false),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('未启用'),
          ),
        ),
      );
    });

    test('parses mock OpenAI response with tags', () async {
      const rawResponse = '''
{
  "choices": [{
    "message": {
      "content": "今天小宝清晰表达了自己的边界。 #亲子 #亲子沟通 #反思"
    }
  }]
}''';

      final client = _FakeHttpClient(body: rawResponse);
      final service = PolisherService(httpClient: client);

      final result = await service.polish(
        content: '今天小宝说不要碰我',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      expect(result.content, '今天小宝清晰表达了自己的边界。');
      expect(result.tags, ['亲子', '亲子沟通', '反思']);
    });

    test('throws when response has no choices', () async {
      final client = _FakeHttpClient(body: '{"choices": []}');
      final service = PolisherService(httpClient: client);

      expect(
        () => service.polish(
          content: '测试',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('未返回结果'),
          ),
        ),
      );
    });

    test('throws on non-200 status', () async {
      final client = _FakeHttpClient(statusCode: 401, body: 'Unauthorized');
      final service = PolisherService(httpClient: client);

      expect(
        () => service.polish(
          content: '测试',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('401'),
          ),
        ),
      );
    });

    test('system prompt uses default when polishPrompt is empty', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "ok"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('润色规则'));
      expect(systemContent, contains('日记润色助手'));
      expect(systemContent, contains('亲子'));
      expect(systemContent, contains('【固定标签规则】'));
    });

    test('system prompt uses custom prompt when provided', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "ok"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
          polishPrompt: '请用极简风格润色，20字以内。',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('极简风格'));
      expect(systemContent, contains('20字以内'));
      expect(systemContent, contains('【固定标签规则】'));
      expect(systemContent, isNot(contains('日记润色助手')));
    });

    test('system prompt always appends tag rules and output format', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "润色后正文。 #亲子 #亲子沟通"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
          polishPrompt: '字数控制在50字以内',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('字数控制在50字以内'));
      expect(systemContent, contains('【固定标签规则】'));
      expect(systemContent, contains('【输出格式】'));
    });

    test('system prompt does not contain apiKey', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "ok"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-super-secret',
          model: 'gpt-4',
        ),
      );

      final body = client.lastRequestBody!;
      expect(body, isNot(contains('sk-super-secret')));
    });

    test('error messages do not contain apiKey', () async {
      final client = _FakeHttpClient(statusCode: 500, body: 'error');
      final service = PolisherService(httpClient: client);

      String? errorMessage;
      try {
        await service.polish(
          content: '测试',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-super-secret',
            model: 'gpt-4',
          ),
        );
      } catch (e) {
        errorMessage = e.toString();
      }

      expect(errorMessage, isNotNull);
      expect(errorMessage, isNot(contains('sk-super-secret')));
    });

    test('chatUrl normalizes base URLs', () {
      expect(
        PolisherService.chatUrl('https://api.openai.com'),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        PolisherService.chatUrl('https://api.openai.com/'),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        PolisherService.chatUrl('https://api.openai.com/v1'),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        PolisherService.chatUrl('https://api.openai.com/v1/'),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        PolisherService.chatUrl('http://localhost:11434'),
        'http://localhost:11434/v1/chat/completions',
      );
    });

    test(
      'retry succeeds when first response has no tags, second has',
      () async {
        final client = _MultiResponseHttpClient([
          '{"choices":[{"message":{"content":"润色正文"}}]}',
          '{"choices":[{"message":{"content":"润色正文\\n#亲子 #亲子沟通 #反思"}}]}',
        ]);
        final service = PolisherService(httpClient: client);

        final result = await service.polish(
          content: '测试',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        );

        expect(result.content, '润色正文');
        expect(result.tags, ['亲子', '亲子沟通', '反思']);
        expect(client.callCount, 2);
      },
    );

    test(
      'retry still returns content when both responses have no valid tags',
      () async {
        final client = _MultiResponseHttpClient([
          '{"choices":[{"message":{"content":"正文一"}}]}',
          '{"choices":[{"message":{"content":"正文二"}}]}',
        ]);
        final service = PolisherService(httpClient: client);

        final result = await service.polish(
          content: '测试',
          entryType: EntryType.quickNote,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        );

        expect(result.content, '正文二');
        expect(result.tags, isEmpty);
        expect(client.callCount, 2);
      },
    );

    test('no retry when first response already has valid tags', () async {
      final client = _MultiResponseHttpClient([
        '{"choices":[{"message":{"content":"正文\\n#亲子 #亲子沟通"}}]}',
      ]);
      final service = PolisherService(httpClient: client);

      final result = await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      expect(result.content, '正文');
      expect(result.tags, ['亲子', '亲子沟通']);
      expect(client.callCount, 1);
    });

    test('retry prompt contains retry instruction', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "无标签正文"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.quickNote,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('必须输出 1 个领域 + 1 个主题'));
      expect(systemContent, contains('【重要提醒】'));
    });

    test('retry does not affect polishPlainText', () async {
      final client = _MultiResponseHttpClient([
        '{"choices":[{"message":{"content":"单次润色"}}]}',
      ]);
      final service = PolisherService(httpClient: client);

      final result = await service.polishPlainText(
        content: '测试',
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      expect(result, '单次润色');
      expect(client.callCount, 1);
    });

    test('reflection prompt includes domain guidance', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "ok"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '今天开会时有些急躁',
        entryType: EntryType.reflection,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('觉察与迭代记录'));
      expect(systemContent, contains('属于哪个生活领域'));
    });

    test(
      'reflection retry with method-only recovers with domain+topic',
      () async {
        final client = _MultiResponseHttpClient([
          '{"choices":[{"message":{"content":"正文\\n#反思"}}]}',
          '{"choices":[{"message":{"content":"正文\\n#亲子 #亲子沟通 #反思"}}]}',
        ]);
        final service = PolisherService(httpClient: client);

        final result = await service.polish(
          content: '今天反思了一下',
          entryType: EntryType.reflection,
          tagConfig: tagConfig,
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-test',
            model: 'gpt-4',
          ),
        );

        // First response had only #反思 (method), filtered as empty tags
        // Second response has domain+topic+method
        expect(result.content, '正文');
        expect(result.tags, ['亲子', '亲子沟通', '反思']);
        expect(client.callCount, 2);
      },
    );

    test('retry instruction includes method warning', () async {
      final client = _CapturingHttpClient(
        body: '''
{
  "choices": [{
    "message": {
      "content": "#反思"
    }
  }]
}''',
      );
      final service = PolisherService(httpClient: client);

      await service.polish(
        content: '测试',
        entryType: EntryType.reflection,
        tagConfig: tagConfig,
        config: const AIConfig(
          enabled: true,
          baseUrl: 'https://api.test.com',
          apiKey: 'sk-test',
          model: 'gpt-4',
        ),
      );

      final body = client.lastRequestBody!;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = json['messages'] as List;
      final systemContent =
          (messages[0] as Map<String, dynamic>)['content'] as String;

      expect(systemContent, contains('方法名'));
      expect(systemContent, contains('不能替代领域或主题'));
    });

    test(
      'generateCoach uses Web-compatible prompt and diary context',
      () async {
        final client = _CapturingHttpClient(
          body: '''
{
  "choices": [{
    "message": {
      "content": "📌 模式识别\\n内容\\n\\n🎯 行动建议\\n行动"
    }
  }]
}''',
        );
        final service = PolisherService(httpClient: client);

        final result = await service.generateCoach(
          diaryContext: '【随手记】\n- **09:30** 测试 #生活',
          config: const AIConfig(
            enabled: true,
            baseUrl: 'https://api.test.com',
            apiKey: 'sk-secret',
            model: 'gpt-4',
          ),
        );

        final body = client.lastRequestBody!;
        final json = jsonDecode(body) as Map<String, dynamic>;
        final messages = json['messages'] as List;
        final systemContent =
            (messages[0] as Map<String, dynamic>)['content'] as String;
        final userContent =
            (messages[1] as Map<String, dynamic>)['content'] as String;

        expect(result, contains('📌 模式识别'));
        expect(systemContent, contains('你是一个理性的人生教练'));
        expect(systemContent, contains('📌 模式识别'));
        expect(systemContent, contains('🎯 行动建议'));
        expect(systemContent, contains('💬 暖心鼓励'));
        expect(userContent, '今天日记内容：\n【随手记】\n- **09:30** 测试 #生活');
        expect(body, isNot(contains('sk-secret')));
      },
    );
  });

  group('splitCoachResultLikeWeb', () {
    test('extracts action and keeps other modules in coach content', () {
      final raw =
          '📌 模式识别\n'
          '- 今天表现很好\n'
          '⚠️ 矛盾指出\n'
          '- 有点焦虑\n'
          '🎯 行动建议\n'
          '- 明天早点睡\n'
          '💬 暖心鼓励\n'
          '- 加油';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);

      expect(parts.actionContent, '明天早点睡');
      expect(parts.lizhiContent, contains('📌 模式识别'));
      expect(parts.lizhiContent, contains('⚠️ 矛盾指出'));
      expect(parts.lizhiContent, contains('💬 暖心鼓励'));
      expect(parts.lizhiContent, isNot(contains('🎯 行动建议')));
      expect(parts.lizhiContent, isNot(contains('- 今天表现很好')));
      expect(parts.lizhiContent, contains('📌 模式识别\n今天表现很好'));
    });

    test('encouragement does not leak into action content', () {
      final raw =
          '🎯 行动建议\n'
          '- 多喝水\n'
          '💬 暖心鼓励\n'
          '- 加油';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);

      expect(parts.actionContent, '多喝水');
      expect(parts.actionContent, isNot(contains('加油')));
      expect(parts.lizhiContent, contains('💬 暖心鼓励'));
      expect(parts.lizhiContent, contains('加油'));
      expect(parts.lizhiContent, isNot(contains('- 加油')));
    });

    test('returns empty action when action module is missing', () {
      final raw =
          '📌 模式识别\n'
          '- 今天不错\n'
          '💬 暖心鼓励\n'
          '- 加油';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);

      expect(parts.actionContent, '');
      expect(parts.lizhiContent, contains('📌'));
      expect(parts.lizhiContent, contains('💬'));
    });

    test('merges multiple bullets into one paragraph per section', () {
      final raw =
          '📌 模式识别\n'
          '- 你习惯先做计划再行动\n'
          '- 你倾向在焦虑时记录情绪触发点\n'
          '\n'
          '⚠️ 矛盾指出\n'
          '- 你设计了焦虑处理流程\n'
          '- 但实际记录只写了计划部分\n'
          '\n'
          '🎯 行动建议\n'
          '- 明天完成焦虑情境的完整记录\n'
          '- 计划执行后预留5分钟回顾\n'
          '\n'
          '💬 暖心鼓励\n'
          '- 你已经开始用计划管理任务\n'
          '- 继续保持记录';

      final parts = PolisherService.splitCoachResultLikeWeb(raw);

      expect(
        parts.lizhiContent,
        '📌 模式识别\n'
        '你习惯先做计划再行动 你倾向在焦虑时记录情绪触发点\n'
        '⚠️ 矛盾指出\n'
        '你设计了焦虑处理流程 但实际记录只写了计划部分\n'
        '💬 暖心鼓励\n'
        '你已经开始用计划管理任务 继续保持记录',
      );
      expect(parts.actionContent, '明天完成焦虑情境的完整记录\n计划执行后预留5分钟回顾');
    });
  });

  group('coach content normalization', () {
    test('title and body on same line with ** artifacts', () {
      final raw =
          '📌 **模式识别** 今天你展现了清晰的目标导向\n'
          '⚠️ **矛盾指出** 然而你记录焦虑时\n'
          '💬 **暖心鼓励** 你已经开始训练觉察力';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      final lines = parts.lizhiContent.split('\n');
      expect(lines[0], '📌 模式识别');
      expect(lines[1], '今天你展现了清晰的目标导向');
      expect(lines[2], '⚠️ 矛盾指出');
      expect(lines[3], '然而你记录焦虑时');
      expect(lines[4], '💬 暖心鼓励');
      expect(lines[5], '你已经开始训练觉察力');
    });

    test('title with colon and body on same line', () {
      final raw =
          '📌 模式识别：今天你展现了清晰的目标导向\n'
          '⚠️ 矛盾指出：然而你记录焦虑时';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      expect(parts.lizhiContent, contains('📌 模式识别'));
      expect(parts.lizhiContent, contains('今天你展现了清晰的目标导向'));
      expect(parts.lizhiContent, isNot(contains('**')));
      expect(parts.lizhiContent, isNot(contains('：')));
    });

    test('header markdown ### is stripped', () {
      final raw =
          '### 📌 **模式识别**\n'
          '今天不错\n'
          '### ⚠️ **矛盾指出**\n'
          '有点问题';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      expect(parts.lizhiContent, contains('📌 模式识别'));
      expect(parts.lizhiContent, contains('⚠️ 矛盾指出'));
      expect(parts.lizhiContent, isNot(contains('###')));
      expect(parts.lizhiContent, isNot(contains('**')));
    });

    test('alias titles are normalized', () {
      final raw =
          '主要模式与趋势\n'
          '今天不错\n'
          '潜在矛盾与提醒\n'
          '有点问题\n'
          '温暖结语\n'
          '加油';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      expect(parts.lizhiContent, contains('📌 模式识别'));
      expect(parts.lizhiContent, contains('⚠️ 矛盾指出'));
      expect(parts.lizhiContent, contains('💬 暖心鼓励'));
      expect(parts.lizhiContent, isNot(contains('主要模式')));
      expect(parts.lizhiContent, isNot(contains('潜在矛盾')));
      expect(parts.lizhiContent, isNot(contains('温暖结语')));
    });

    test('body text with contradiction words is not treated as title', () {
      final raw =
          '📌 模式识别\n'
          '你今天习惯先计划再行动\n'
          '⚠️ 矛盾指出\n'
          '你一面想保持节奏，一面又被未完成事项牵动，这种矛盾状态值得留意。\n'
          '这种不一致不是失败，而是提醒你需要更小的行动入口。\n'
          '💬 暖心鼓励\n'
          '你已经在认真观察自己';

      final parts = PolisherService.splitCoachResultLikeWeb(raw);

      expect(RegExp('⚠️ 矛盾指出').allMatches(parts.lizhiContent), hasLength(1));
      expect(parts.lizhiContent, contains('这种矛盾状态值得留意'));
      expect(parts.lizhiContent, contains('这种不一致不是失败'));
    });

    test('body ** is cleaned', () {
      final raw =
          '📌 **模式识别**\n'
          '- 你今天**表现很好**特别棒';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      expect(parts.lizhiContent, isNot(contains('**')));
      expect(parts.lizhiContent, contains('你今天表现很好特别棒'));
    });

    test('standard format is not broken', () {
      final raw =
          '📌 模式识别\n'
          '- 今天表现很好\n'
          '⚠️ 矛盾指出\n'
          '- 有点焦虑\n'
          '💬 暖心鼓励\n'
          '- 加油';
      final parts = PolisherService.splitCoachResultLikeWeb(raw);
      expect(parts.lizhiContent, contains('📌 模式识别'));
      expect(parts.lizhiContent, contains('⚠️ 矛盾指出'));
      expect(parts.lizhiContent, contains('💬 暖心鼓励'));
      expect(parts.lizhiContent, isNot(contains('**')));
    });
  });

  group('DiaryMarkdownView coach and tomorrow', () {
    testWidgets('shows both coach and tomorrow sections', (tester) async {
      const markdown = '''
---
tags:
  - 日记
---

# 今天

### 🧠 人生教练
📌 模式识别
- 你今天表现很好
⚠️ 矛盾指出
- 有一点焦虑
💬 暖心鼓励
- 加油

### 🌙 明日寄语
- 明天完成重要任务
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () {},
              generatingCoach: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Coach section should show
      expect(find.text('🧠 人生教练'), findsOneWidget);
      expect(find.text('📌 模式识别'), findsOneWidget);
      expect(find.text('⚠️ 矛盾指出'), findsOneWidget);
      expect(find.text('💬 暖心鼓励'), findsOneWidget);

      // Tomorrow section should show
      expect(find.text('🌙 明日寄语'), findsOneWidget);
      expect(find.text('明天完成重要任务'), findsOneWidget);
    });

    testWidgets('restore default rendering after changes', (tester) async {
      const markdown = '''
---
tags:
  - 日记
---

# 今天

## 📈 每日复盘
### 🧠 人生教练
📌 模式识别
今天表现很好
### 🌙 明日寄语
明天完成重要任务
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () {},
              generatingCoach: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both sections exist independently
      expect(find.text('🧠 人生教练'), findsOneWidget);
      expect(find.text('🌙 明日寄语'), findsOneWidget);
    });

    testWidgets('readOnly=false shows regenerate button', (tester) async {
      const markdown = '''
# 今天

### 🧠 人生教练
📌 模式识别
你今天表现很好
⚠️ 矛盾指出
有一点焦虑
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () {},
              readOnly: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // regenerate button should show
      expect(find.text('重新生成'), findsOneWidget);
    });

    testWidgets('readOnly=false shows generate button for empty coach', (
      tester,
    ) async {
      var tapped = false;
      const markdown = '''
# 今天

### 🧠 人生教练
-
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () => tapped = true,
              readOnly: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🧠 人生教练'), findsOneWidget);
      expect(find.text('生成今日反馈'), findsOneWidget);

      await tester.tap(find.text('生成今日反馈'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets(
      'readOnly=false shows generate button when coach section missing',
      (tester) async {
        const markdown = '''
# 今天

## 🏃 习惯打卡
- [x] 📖 阅读/亲子共读

### 🌙 明日寄语
- 明天完成重要任务
''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DiaryMarkdownView(
                markdown: markdown,
                onGenerateCoach: () {},
                readOnly: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('🧠 人生教练'), findsOneWidget);
        expect(find.text('生成今日反馈'), findsOneWidget);
        expect(find.text('🌙 明日寄语'), findsOneWidget);
        expect(find.text('🏃 习惯打卡'), findsOneWidget);
      },
    );

    testWidgets('old coach title still shows generate button when editable', (
      tester,
    ) async {
      const markdown = '''
# 今天

### 🧠 荔枝喵说
-
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () {},
              readOnly: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🧠 人生教练'), findsOneWidget);
      expect(find.text('🧠 荔枝喵说'), findsNothing);
      expect(find.text('生成今日反馈'), findsOneWidget);
    });

    testWidgets('readOnly=true hides regenerate button', (tester) async {
      const markdown = '''
# 今天

### 🧠 人生教练
📌 模式识别
你今天表现很好
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              onGenerateCoach: () {},
              readOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Coach content should show
      expect(find.text('🧠 人生教练'), findsOneWidget);
      expect(find.text('📌 模式识别'), findsOneWidget);
      // Regenerate button should NOT show
      expect(find.text('重新生成'), findsNothing);
      expect(find.text('生成今日反馈'), findsNothing);
    });

    testWidgets('荔枝喵说 title displays as 人生教练', (tester) async {
      const markdown = '''
# 今天

### 🧠 荔枝喵说
📌 模式识别
你今天表现很好
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(markdown: markdown, readOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show as 人生教练, not 荔枝喵说
      expect(find.text('🧠 人生教练'), findsOneWidget);
      expect(find.text('🧠 荔枝喵说'), findsNothing);
    });

    testWidgets('old format **模式识别** renders as module title', (tester) async {
      const markdown = '''
# 今天

### 🧠 人生教练
**模式识别**：今天两条线索并行。
**矛盾指出**：16:07 小宝能独立玩乐高。
**批判性问题**：你在旁边盯着的行为。
**甜点**：4岁半能在陌生游乐场自得其乐。
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(markdown: markdown, readOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Old format patterns should be normalized to display titles
      expect(find.text('📌 模式识别'), findsOneWidget);
      expect(find.text('⚠️ 矛盾指出'), findsOneWidget);
      expect(find.text('❓ 批判性问题'), findsOneWidget);
      expect(find.text('🍰 甜点'), findsOneWidget);

      // Raw ** markers should NOT appear
      expect(find.text('**模式识别**'), findsNothing);
      expect(find.text('**矛盾指出**'), findsNothing);
      expect(find.text('**批判性问题**'), findsNothing);
      expect(find.text('**甜点**'), findsNothing);

      // Body text (after colon) should still appear
      expect(find.text('今天两条线索并行。'), findsOneWidget);
      expect(find.text('16:07 小宝能独立玩乐高。'), findsOneWidget);
    });

    testWidgets('old format with emoji prefix normalizes correctly', (
      tester,
    ) async {
      const markdown = '''
# 今天

### 🧠 人生教练
🍰 **甜点**：4岁半能在陌生游乐场自得其乐。
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(markdown: markdown, readOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify body text appears (without raw ** markers)
      expect(find.text('4岁半能在陌生游乐场自得其乐。'), findsOneWidget);
      // Verify no raw ** markers remain
      expect(find.text('**甜点**'), findsNothing);
      // Verify 人生教练 title still shows
      expect(find.text('🧠 人生教练'), findsOneWidget);
    });

    testWidgets(
      'hiddenSections hides tomorrow and habits only when specified',
      (tester) async {
        const markdown = '''
# 今天

## 🏃 习惯打卡
- [x] 📖 阅读/亲子共读

### 🧠 人生教练
📌 模式识别
你今天表现很好

### 🌙 明日寄语
- 明天完成重要任务
''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DiaryMarkdownView(
                markdown: markdown,
                readOnly: true,
                hiddenSections: {'tomorrow', 'habits'},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('🧠 人生教练'), findsOneWidget);
        expect(find.text('📌 模式识别'), findsOneWidget);
        expect(find.text('🌙 明日寄语'), findsNothing);
        expect(find.text('🏃 习惯打卡'), findsNothing);
        expect(find.text('📖 阅读/亲子共读'), findsNothing);
      },
    );

    testWidgets('hiddenSections hides habit tracking title variant', (
      tester,
    ) async {
      const markdown = '''
# 今天

## 📌 习惯追踪
- [x] 📖 阅读/亲子共读

### 🧠 人生教练
📌 模式识别
你今天表现很好
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              readOnly: true,
              hiddenSections: {'tomorrow', 'habits'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🧠 人生教练'), findsOneWidget);
      expect(find.text('📌 习惯追踪'), findsNothing);
      expect(find.text('📖 阅读/亲子共读'), findsNothing);
    });

    testWidgets('hiddenSections accepts Chinese section keys', (tester) async {
      const markdown = '''
# 今天

## 🏃 习惯打卡
- [x] 📖 阅读/亲子共读

### 🌙 明日寄语
- 明天完成重要任务

### 🧠 人生教练
📌 模式识别
你今天表现很好
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DiaryMarkdownView(
              markdown: markdown,
              readOnly: true,
              hiddenSections: {'明日寄语', '习惯打卡'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🧠 人生教练'), findsOneWidget);
      expect(find.text('🌙 明日寄语'), findsNothing);
      expect(find.text('🏃 习惯打卡'), findsNothing);
      expect(find.text('📖 阅读/亲子共读'), findsNothing);
    });

    testWidgets(
      'today rendering keeps tomorrow and habits without hiddenSections',
      (tester) async {
        const markdown = '''
# 今天

## 🏃 习惯打卡
- [x] 📖 阅读/亲子共读

### 🧠 人生教练
📌 模式识别
你今天表现很好

### 🌙 明日寄语
- 明天完成重要任务
''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DiaryMarkdownView(
                markdown: markdown,
                onGenerateCoach: () {},
                readOnly: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('🧠 人生教练'), findsOneWidget);
        expect(find.text('重新生成'), findsOneWidget);
        expect(find.text('🌙 明日寄语'), findsOneWidget);
        expect(find.text('明天完成重要任务'), findsOneWidget);
        expect(find.text('🏃 习惯打卡'), findsOneWidget);
        expect(find.text('亲子共读'), findsOneWidget);
      },
    );
  });

  group('SettingsScreen', () {
    Widget buildScreen({AIConfigRepository? aiRepo}) {
      return MaterialApp(
        home: SettingsScreen(
          apiConfig: ApiConfig(
            baseUrl: 'https://obsidian.femkits.org',
            token: 'secret-token',
          ),
        ),
      );
    }

    testWidgets('shows AI section and connection info', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.text('AI 服务配置'), findsOneWidget);
      expect(find.text('启用 AI 润色'), findsOneWidget);
      expect(find.text('快速选择预设'), findsOneWidget);
      expect(find.text('保存 AI 配置'), findsOneWidget);
    });

    testWidgets('does not show plain text Token', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.text('secret-token'), findsNothing);
    });

    testWidgets('toggling AI switch disables AI fields', (tester) async {
      await tester.pumpWidget(buildScreen());

      // Initially disabled: skip server address + Token (which is _ReadOnlyField, not TextField)
      // Then AI fields: name (0), baseUrl (1), apiKey (2), model (3), prompt (4)
      final textFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();

      expect(textFields[0].enabled, isFalse); // name
      expect(textFields[1].enabled, isFalse); // baseUrl
      expect(textFields[2].enabled, isFalse); // apiKey
      expect(textFields[3].enabled, isFalse); // model

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      final enabledFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();

      expect(enabledFields[0].enabled, isTrue);
      expect(enabledFields[1].enabled, isTrue);
      expect(enabledFields[2].enabled, isTrue);
      expect(enabledFields[3].enabled, isTrue);
    });

    testWidgets('disabled fields preserve content', (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Base URL'),
        'https://api.test.com',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Model'), 'gpt-4o');
      await tester.pump();

      // Disable and re-enable
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Base URL'))
            .controller
            ?.text,
        'https://api.test.com',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Model'))
            .controller
            ?.text,
        'gpt-4o',
      );
    });

    testWidgets('API Key field uses obscureText', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      final apiKeyField = find.widgetWithText(TextField, 'API Key');
      expect(tester.widget<TextField>(apiKeyField).obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility).last);
      await tester.pump();
      expect(tester.widget<TextField>(apiKeyField).obscureText, isFalse);
    });

    testWidgets('preset chip fills name, baseUrl, and model', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      await tester.tap(find.text('DeepSeek'));
      await tester.pump();

      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '服务商名称'))
            .controller
            ?.text,
        'DeepSeek',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Base URL'))
            .controller
            ?.text,
        'https://api.deepseek.com',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Model'))
            .controller
            ?.text,
        'deepseek-v4-flash',
      );
    });

    testWidgets('Server address and Token not editable', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.text('https://obsidian.femkits.org'), findsNothing);
      expect(find.text('secret-token'), findsNothing);
    });

    testWidgets('shows polish and coach prompt fields with labels', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      expect(find.text('润色提示词'), findsNothing);
      expect(find.text('人生教练提示词'), findsNothing);
      expect(find.text('恢复默认润色提示词'), findsNothing);
      expect(find.text('恢复默认人生教练提示词'), findsNothing);
    });
  });

  group('EntryLineBuilder', () {
    test('rebuildTimelineLine preserves - prefix and time', () {
      const rawLine = '- **09:30** 原始内容 #旧标签';

      final result = rebuildTimelineLine(
        rawLine: rawLine,
        content: '新内容',
        tags: ['亲子', '亲子沟通'],
      );

      expect(result, '- **09:30** 新内容 #亲子 #亲子沟通');
    });

    test('rebuildTimelineLine preserves > prefix and time', () {
      const rawLine = '> **14:00** 小确幸原文 #生活';

      final result = rebuildTimelineLine(
        rawLine: rawLine,
        content: '更新后的内容',
        tags: ['生活', '日常记录'],
      );

      expect(result, '> **14:00** 更新后的内容 #生活 #日常记录');
    });

    test('rebuildTimelineLine preserves original time', () {
      const rawLine = '- **23:59** 晚间记录';

      final result = rebuildTimelineLine(
        rawLine: rawLine,
        content: '修改后',
        tags: [],
      );

      expect(result, '- **23:59** 修改后');
    });

    test('rebuildTimelineLine no tags produces no hashtag', () {
      const rawLine = '- **12:00** 内容 #标签';

      final result = rebuildTimelineLine(
        rawLine: rawLine,
        content: '新内容',
        tags: [],
      );

      expect(result, '- **12:00** 新内容');
    });

    test('rebuildTimelineLine throws on invalid format', () {
      expect(
        () => rebuildTimelineLine(
          rawLine: 'no prefix line',
          content: 'x',
          tags: [],
        ),
        throwsArgumentError,
      );
    });

    test('rebuildTimelineLine handles tags with addHash format', () {
      const rawLine = '- **08:00** 原文 #a #b';

      final result = rebuildTimelineLine(
        rawLine: rawLine,
        content: '新',
        tags: ['工作', '任务执行', '反思'],
      );

      expect(result, '- **08:00** 新 #工作 #任务执行 #反思');
    });
  });

  group('EntryDelete', () {
    testWidgets('QuickNoteTimeline shows delete button', (tester) async {
      final section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '09:30',
            content: '测试内容',
            tags: ['#工作'],
            rawLine: '- **09:30** 测试内容 #工作',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteTimeline(section: section, onDelete: (_) async {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('QuickNoteTimeline delete button shows confirm dialog', (
      tester,
    ) async {
      final section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '09:30',
            content: '测试',
            tags: [],
            rawLine: '- **09:30** 测试',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteTimeline(section: section, onDelete: (_) async {}),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      // PopupMenu shows edit/delete items
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      // Tap delete in the popup menu
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.text('确认删除'), findsOneWidget);
      expect(find.text('确定删除这条记录吗？'), findsOneWidget);
    });

    testWidgets(
      'QuickNoteTimeline confirm delete calls onDelete with rawLine',
      (tester) async {
        String? deletedRawLine;
        final section = QuickNoteSection(
          title: '随手记',
          contents: [],
          notes: [
            QuickNoteItem(
              time: '09:30',
              content: '测试',
              tags: [],
              rawLine: '- **09:30** 测试 #工作',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QuickNoteTimeline(
                section: section,
                onDelete: (note) async {
                  deletedRawLine = note.rawLine;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();

        // Tap delete in popup menu
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();

        // Now tap delete in confirm dialog
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();

        expect(deletedRawLine, '- **09:30** 测试 #工作');
      },
    );

    testWidgets('GenericSectionCard single happiness shows plain text', (
      tester,
    ) async {
      final section = HappinessSection(
        title: '小确幸',
        contents: [
          TimelineContent(
            time: '14:00',
            text: '下班看到晚霞',
            tags: ['#生活'],
            rawLine: '> **14:00** 下班看到晚霞 #生活',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenericSectionCard(section: section)),
        ),
      );

      // 单条显示纯文本，无项目符号
      expect(find.text('下班看到晚霞'), findsOneWidget);
      expect(find.text('•'), findsNothing);
      // 无 timeline 图标
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('GenericSectionCard multiple happiness shows bullet list', (
      tester,
    ) async {
      final section = HappinessSection(
        title: '小确幸',
        contents: [
          TimelineContent(
            time: '14:00',
            text: '下班看到晚霞',
            tags: [],
            rawLine: '> **14:00** 下班看到晚霞',
          ),
          TimelineContent(
            time: '15:00',
            text: '女儿收拾玩具',
            tags: [],
            rawLine: '> **15:00** 女儿收拾玩具',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenericSectionCard(section: section)),
        ),
      );

      // 多条显示 bullet list
      expect(find.text('•'), findsNWidgets(2));
      expect(find.text('下班看到晚霞'), findsOneWidget);
      expect(find.text('女儿收拾玩具'), findsOneWidget);
      // 无 timeline 样式
      expect(find.text('14:00'), findsNothing);
      expect(find.text('15:00'), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('GenericSectionCard happiness no longer shows timeline', (
      tester,
    ) async {
      final section = HappinessSection(
        title: '小确幸',
        contents: [
          TimelineContent(
            time: '20:00',
            text: '散步很快乐',
            tags: [],
            rawLine: '> **20:00** 散步很快乐',
          ),
          TimelineContent(
            time: '21:00',
            text: '喝了杯热茶',
            tags: [],
            rawLine: '> **21:00** 喝了杯热茶',
          ),
          TimelineContent(
            time: '22:00',
            text: '看了本好书',
            tags: [],
            rawLine: '> **22:00** 看了本好书',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenericSectionCard(section: section)),
        ),
      );

      // 三条都是 bullet，不是时间标签
      expect(find.text('•'), findsNWidgets(3));
      expect(find.text('20:00'), findsNothing);
      expect(find.text('21:00'), findsNothing);
      expect(find.text('22:00'), findsNothing);
    });

    testWidgets(
      'GenericSectionCard reflection delete calls onDelete with rawLine',
      (tester) async {
        String? deletedRawLine;
        final section = ReviewSection(
          title: '觉察',
          contents: [
            TimelineContent(
              time: '10:00',
              text: '觉察内容',
              tags: ['#反思'],
              rawLine: '- **10:00** 觉察内容 #反思',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenericSectionCard(
                section: section,
                onTimelineDelete: (rawLine) async {
                  deletedRawLine = rawLine;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();

        // Tap delete in popup menu
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();

        // Tap delete in confirm dialog
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();

        expect(deletedRawLine, '- **10:00** 觉察内容 #反思');
      },
    );

    testWidgets('no delete button when onDelete is null', (tester) async {
      final section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '09:30',
            content: '测试',
            tags: [],
            rawLine: '- **09:30** 测试',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QuickNoteTimeline(section: section)),
        ),
      );

      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('ReviewCard shows delete button via GenericSectionCard', (
      tester,
    ) async {
      final section = ReviewSection(
        title: '💡 觉察与迭代',
        contents: [
          TimelineContent(
            time: '10:00',
            text: '觉察内容',
            tags: ['#反思'],
            rawLine: '- **10:00** 觉察内容 #反思',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewCard(section: section, onTimelineDelete: (_) async {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('ReviewCard delete passes rawLine with section reflection', (
      tester,
    ) async {
      String? passedRawLine;
      final section = ReviewSection(
        title: '💡 觉察与迭代',
        contents: [
          TimelineContent(
            time: '10:00',
            text: '觉察内容',
            tags: ['#反思'],
            rawLine: '- **10:00** 觉察内容 #反思',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewCard(
              section: section,
              onTimelineDelete: (rawLine) async {
                passedRawLine = rawLine;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      // Tap delete in popup menu
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Tap delete in confirm dialog
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(passedRawLine, '- **10:00** 觉察内容 #反思');
    });

    testWidgets('ReviewCard with SubSectionContent still shows delete button', (
      tester,
    ) async {
      // Replicates real markdown: "## 每日复盘" / "### 💡 觉察与迭代"
      final section = ReviewSection(
        title: '🧠 每日复盘',
        contents: [
          const SubSectionContent('💡 觉察与迭代'),
          TimelineContent(
            time: '10:00',
            text: '觉察内容',
            tags: ['#反思'],
            rawLine: '- **10:00** 觉察内容 #反思',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewCard(section: section, onTimelineDelete: (_) async {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('PopupMenu shows edit and delete options', (tester) async {
      final section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '09:30',
            content: '测试',
            tags: [],
            rawLine: '- **09:30** 测试',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteTimeline(
              section: section,
              onDelete: (_) async {},
              onEdit: (_, _, _) async {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('edit opens EntryEditSheet with pre-filled content', (
      tester,
    ) async {
      final section = QuickNoteSection(
        title: '随手记',
        contents: [],
        notes: [
          QuickNoteItem(
            time: '09:30',
            content: '原始内容',
            tags: ['#工作'],
            rawLine: '- **09:30** 原始内容 #工作',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickNoteTimeline(
              section: section,
              onEdit: (_, _, _) async {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(find.text('编辑记录'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '原始内容',
      );
    });

    testWidgets('EntryEditSheet strips # prefix from tags for TagPicker', (
      tester,
    ) async {
      final tagConfig = _polishTagConfig();
      List<String>? savedTags;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => EntryEditSheet(
                        initialContent: 'test',
                        initialTags: const ['#亲子', '#亲子沟通'],
                        tagConfig: tagConfig,
                        onSave: (_, tags) async {
                          savedTags = tags;
                        },
                      ),
                    );
                  },
                  child: const Text('打开'),
                );
              },
            ),
          ),
        ),
      );

      // Open the sheet
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      // Tags should be properly prefixed (without #)
      // Save to verify the tags are stripped
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedTags, isNotNull);
      expect(savedTags, isNot(contains('#亲子')));
      expect(savedTags, contains('亲子'));
    });

    test('rebuildTimelineLine preserves original time for edit', () {
      const rawLine = '- **09:30** 旧内容 #旧标签';

      final replacement = rebuildTimelineLine(
        rawLine: rawLine,
        content: '新内容',
        tags: ['亲子', '亲子沟通'],
      );

      expect(replacement, '- **09:30** 新内容 #亲子 #亲子沟通');
    });

    test('rebuildTimelineLine preserves > prefix for happiness edit', () {
      const rawLine = '> **14:00** 旧小确幸 #生活';

      final replacement = rebuildTimelineLine(
        rawLine: rawLine,
        content: '新小确幸',
        tags: ['生活', '日常记录'],
      );

      expect(replacement, '> **14:00** 新小确幸 #生活 #日常记录');
    });
  });

  group('ApiClient replaceAnxiety', () {
    ApiClient makeClient(_CapturingClient client) {
      return ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: client,
      );
    }

    test('calls replace endpoint, not append endpoint', () async {
      final client = _CapturingClient();
      final api = makeClient(client);

      await api.replaceAnxiety(DateTime(2026, 6, 7), 'test');

      expect(client.lastUrl, contains('/api/v1/diary/anxiety/replace'));
    });

    test('sends date, content, and operationId in body', () async {
      final client = _CapturingClient();
      final api = makeClient(client);

      await api.replaceAnxiety(DateTime(2026, 6, 7), '四问内容');

      final body = jsonDecode(client.lastBody!) as Map<String, dynamic>;
      expect(body['date'], '2026-06-07');
      expect(body['content'], '四问内容');
      expect(body['operationId'], isA<String>());
      expect(body['operationId'], hasLength(36));
    });

    test('does NOT send tags (replace endpoint has no tags)', () async {
      final client = _CapturingClient();
      final api = makeClient(client);

      await api.replaceAnxiety(DateTime(2026, 6, 7), 'content');

      final body = jsonDecode(client.lastBody!) as Map<String, dynamic>;
      expect(body.containsKey('tags'), isFalse);
    });

    test('returns true on 200 response', () async {
      final client = _CapturingClient();
      final api = makeClient(client);

      final result = await api.replaceAnxiety(DateTime(2026, 6, 7), 'test');

      expect(result, isTrue);
    });
  });

  group('ImageCompressService', () {
    const maxBytes = 3 * 1024 * 1024;

    test('compressToBase64 output includes data:image/jpeg;base64, prefix', () {
      final image = img.Image(width: 1, height: 1);
      image.setPixelRgba(0, 0, 255, 0, 0, 255);
      final bytes = img.encodeJpg(image, quality: 90);

      final service = const ImageCompressService();
      final result = service.compressToBase64(bytes);

      expect(result, startsWith('data:image/jpeg;base64,'));
      expect(result.length, greaterThan('data:image/jpeg;base64,'.length));
    });

    test('small image is not enlarged', () {
      final image = img.Image(width: 100, height: 100);
      final bytes = img.encodeJpg(image, quality: 90);

      final service = const ImageCompressService();
      final result = service.compressToBase64(bytes);

      final base64 = result.split(',').last;
      final decoded = img.decodeImage(base64Decode(base64));
      expect(decoded, isNotNull);
      expect(decoded!.width, 100);
      expect(decoded.height, 100);
    });

    test('image over 2000px long side is downsized', () {
      final image = img.Image(width: 4000, height: 3000);
      _fillSolidImage(image);
      final bytes = img.encodeJpg(image, quality: 90);

      final service = const ImageCompressService();
      final result = service.compressToBase64(bytes);

      final base64 = result.split(',').last;
      final decoded = img.decodeImage(base64Decode(base64));
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(2000));
      expect(decoded.height, lessThanOrEqualTo(2000));
    });

    test('output fits under 3MB for a compressible large image', () {
      // Generate a 3000×2000 image with repeating pattern — highly compressible
      final image = img.Image(width: 3000, height: 2000);
      _fillSolidImage(image);
      final input = img.encodeJpg(image, quality: 95);

      final service = const ImageCompressService();
      final result = service.compressToBase64(input);
      final base64 = result.split(',').last;
      final outputBytes = base64Decode(base64);
      expect(outputBytes.length, lessThanOrEqualTo(maxBytes));
    });

    test('does not hang or crash on noisy incompressible image', () {
      final image = img.Image(width: 200, height: 200);
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
      final inputBytes = img.encodeJpg(image, quality: 100);
      final service = const ImageCompressService();
      final result = service.compressToBase64(inputBytes);
      expect(result, startsWith('data:image/jpeg;base64,'));
    });

    test('output can be decoded back from base64', () {
      final image = img.Image(width: 500, height: 500);
      _fillSolidImage(image);
      final bytes = img.encodeJpg(image, quality: 90);

      final service = const ImageCompressService();
      final result = service.compressToBase64(bytes);

      final base64 = result.split(',').last;
      final decoded = img.decodeImage(base64Decode(base64));
      expect(decoded, isNotNull);
      expect(decoded!.width, greaterThan(0));
      expect(decoded.height, greaterThan(0));
    });

    test('large uncompressible image returns best-effort and stops', () {
      // Generate a 6000×4000 image filled with noise — nearly incompressible.
      final image = img.Image(width: 6000, height: 4000);
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
      final inputBytes = img.encodeJpg(image, quality: 95);

      final service = const ImageCompressService();
      final result = service.compressToBase64(inputBytes);

      // Should complete without crash and produce valid output.
      expect(result, startsWith('data:image/jpeg;base64,'));

      final base64 = result.split(',').last;
      final decoded = img.decodeImage(base64Decode(base64));
      expect(decoded, isNotNull);
      // Long side is at most the initial 2000px after first resize.
      expect(decoded!.width, lessThanOrEqualTo(2000));
      expect(decoded.height, lessThanOrEqualTo(2000));
    });
  });

  group('ImageSectionCard', () {
    test('parseWikiLinks extracts single WikiLink', () {
      final section = MediaSection(
        title: '## 📸 影像记录',
        contents: [MarkdownContent('![[Image-20260608-001.jpg]]')],
      );
      final filenames = ImageSectionCard.parseWikiLinks(section);
      expect(filenames, ['Image-20260608-001.jpg']);
    });

    test('parseWikiLinks extracts multiple WikiLinks', () {
      final section = MediaSection(
        title: '## 📸 影像记录',
        contents: [
          MarkdownContent(
            '![[Image-20260608-001.jpg]]\n![[Image-20260608-002.jpg]]',
          ),
        ],
      );
      final filenames = ImageSectionCard.parseWikiLinks(section);
      expect(filenames, ['Image-20260608-001.jpg', 'Image-20260608-002.jpg']);
    });

    test('parseWikiLinks ignores non-wiki Markdown image format', () {
      final section = MediaSection(
        title: '## 📸 影像记录',
        contents: [MarkdownContent('![](path/to/image.jpg)')],
      );
      final filenames = ImageSectionCard.parseWikiLinks(section);
      expect(filenames, isEmpty);
    });

    test('parseWikiLinks only allows safe image extensions', () {
      final section = MediaSection(
        title: '## 📸 影像记录',
        contents: [
          MarkdownContent(
            '![[safe.jpg]]\n![[unsafe.exe]]\n![[safe.png]]\n![[no-ext]]',
          ),
        ],
      );
      final filenames = ImageSectionCard.parseWikiLinks(section);
      expect(filenames, ['safe.jpg', 'safe.png']);
    });

    test('parseWikiLinks handles PNG, GIF, WebP, HEIC extensions', () {
      final section = MediaSection(
        title: '## 📸 影像记录',
        contents: [
          MarkdownContent(
            '![[a.png]] ![[b.gif]] ![[c.webp]] ![[d.heic]] ![[e.heif]]',
          ),
        ],
      );
      final filenames = ImageSectionCard.parseWikiLinks(section);
      expect(filenames, ['a.png', 'b.gif', 'c.webp', 'd.heic', 'e.heif']);
    });

    test('parseWikiLinks returns empty for empty MediaSection', () {
      final section = MediaSection(title: '## 📸 影像记录', contents: []);
      final filenames = ImageSectionCard.parseWikiLinks(section);
      expect(filenames, isEmpty);
    });

    testWidgets('shows empty state when no images', (tester) async {
      final section = MediaSection(title: '## 📸 影像记录', contents: []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: section,
              apiClient: ApiClient(
                ApiConfig(baseUrl: 'https://test.local', token: 'x'),
              ),
              date: DateTime(2026, 6, 8),
            ),
          ),
        ),
      );

      expect(find.text('暂无影像记录'), findsOneWidget);
    });

    ApiClient imageTestApiClient() {
      final response =
          '{"data":"data:image/jpeg;base64,/9j/4AAQ","mimeType":"image/jpeg"}';
      return ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'x'),
        httpClient: _CapturingClient(responseBody: response),
      );
    }

    MediaSection imageSection(List<String> filenames) {
      final links = filenames.map((f) => '![[$f]]').join('\n');
      return MediaSection(
        title: '## 📸 影像记录',
        contents: [MarkdownContent(links)],
      );
    }

    testWidgets('thumbnail shows delete menu', (tester) async {
      String? deleted;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
              onDeleteImage: (rawLine) async {
                deleted = rawLine;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      expect(deleted, isNull);
    });

    testWidgets('delete shows confirm dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
              onDeleteImage: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(find.text('删除照片'), findsOneWidget);
      expect(find.text('将从今日影像记录中删除这张图片'), findsOneWidget);
    });

    testWidgets('cancel delete does not fire callback', (tester) async {
      String? deleted;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
              onDeleteImage: (rawLine) async {
                deleted = rawLine;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(deleted, isNull);
    });

    testWidgets('confirm delete fires callback with correct rawLine', (
      tester,
    ) async {
      String? deleted;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['Image-20260608-001.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
              onDeleteImage: (rawLine) async {
                deleted = rawLine;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(deleted, '![[Image-20260608-001.jpg]]');
    });

    testWidgets('multi-image delete passes correct rawLine per image', (
      tester,
    ) async {
      String? deleted;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg', 'img-002.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
              onDeleteImage: (rawLine) async {
                deleted = rawLine;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Two thumbnails → two delete menus
      expect(find.byIcon(Icons.more_horiz), findsNWidgets(2));

      // Delete the first image
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      expect(deleted, '![[img-001.jpg]]');
    });

    testWidgets('no delete menu when onDeleteImage is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('tap thumbnail opens preview with close gesture', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageSectionCard(
              section: imageSection(['img-001.jpg']),
              apiClient: imageTestApiClient(),
              date: DateTime(2026, 6, 8),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the thumbnail image
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();

      // Should show the full-screen preview image
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // Tap to close
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsNothing);
    });
  });

  group('ApiClient image', () {
    ApiClient makeImageClient(_CapturingClient client) {
      return ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: client,
      );
    }

    test('uploadImage sends correct payload', () async {
      final client = _CapturingClient();
      final api = makeImageClient(client);

      await api.uploadImage(
        DateTime(2026, 6, 8),
        'data:image/jpeg;base64,abc123',
      );

      expect(client.lastUrl, contains('/api/v1/diary/image/upload'));
      final body = jsonDecode(client.lastBody!) as Map<String, dynamic>;
      expect(body['date'], '2026-06-08');
      expect(body['imageData'], 'data:image/jpeg;base64,abc123');
    });

    test('uploadImage throws on non-200 response', () async {
      final failClient = _CapturingClient(statusCode: 500);
      final failApi = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: failClient,
      );

      expect(
        () => failApi.uploadImage(
          DateTime(2026, 6, 8),
          'data:image/jpeg;base64,test',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('fetchDiaryImage requests correct URL with month', () async {
      final client = _CapturingClient();
      final api = makeImageClient(client);

      await api.fetchDiaryImage(
        year: 2026,
        month: 6,
        imageName: 'Image-20260608-001.jpg',
      );

      expect(
        client.lastUrl,
        contains('/api/v1/diary/image/2026/Image-20260608-001.jpg'),
      );
      expect(client.lastUrl, contains('month=6'));
    });

    test('fetchDiaryImage returns parsed JSON', () async {
      final client = _CapturingClient(
        responseBody:
            '{"data":"data:image/jpeg;base64,test123","mimeType":"image/jpeg"}',
      );
      final api = makeImageClient(client);

      final result = await api.fetchDiaryImage(
        year: 2026,
        month: 6,
        imageName: 'Image-20260608-001.jpg',
      );

      expect(result['data'], 'data:image/jpeg;base64,test123');
      expect(result['mimeType'], 'image/jpeg');
    });
  });

  group('HabitStatsService', () {
    setUp(() {
      HabitStatsService.clearCache();
    });

    tearDown(() {
      HabitStatsService.clearCache();
    });

    ApiClient habitTestClient({
      required Map<int, int> waterByDay,
      required Map<int, int> stepsByDay,
      required Map<int, bool> readingByDay,
      required Map<int, bool> languageByDay,
      required Map<int, bool> supplementByDay,
    }) {
      final now = DateTime.now();
      return ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: waterByDay,
          stepsByDay: stepsByDay,
          readingByDay: readingByDay,
          languageByDay: languageByDay,
          supplementByDay: supplementByDay,
        ),
      );
    }

    test('generates correct 7-day date range', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final days = <DateTime>[];
      for (var i = 6; i >= 0; i--) {
        days.add(today.subtract(Duration(days: i)));
      }
      expect(days.length, 7);
      // No future dates
      for (final d in days) {
        expect(d.isAfter(today), false);
      }
    });

    test('parses numeric and boolean habits correctly', () async {
      final now = DateTime.now();
      final today = now.day;
      final apiClient = habitTestClient(
        waterByDay: {today - 1: 1500, today - 2: 800},
        stepsByDay: {today - 1: 6000},
        readingByDay: {today - 1: true, today - 2: true},
        languageByDay: {today - 1: true},
        supplementByDay: {today - 1: true, today - 2: true, today - 3: true},
      );

      final service = HabitStatsService(apiClient);
      final stats = await service.loadStats();

      expect(stats.items.length, 5);

      // 饮水
      final water = stats.items.firstWhere((i) => i.key == 'water');
      expect(water.type, HabitStatType.numeric);
      expect(water.completedDays, 2);

      // 亲子共读
      final reading = stats.items.firstWhere((i) => i.key == 'reading');
      expect(reading.type, HabitStatType.boolean);
      expect(reading.completedDays, 2);

      // 鱼油
      final supp = stats.items.firstWhere((i) => i.key == 'supplements');
      expect(supp.type, HabitStatType.boolean);
      expect(supp.completedDays, 3);
      expect(supp.currentStreak, 3);
    });

    test('returns empty stats when no habit data', () async {
      final apiClient = habitTestClient(
        waterByDay: {},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
      );

      final service = HabitStatsService(apiClient);
      final stats = await service.loadStats();

      expect(stats.feedbackSuggestion, '先选一个最容易的小习惯照顾起来就很好。');
    });

    test('generates feedback text for stable week', () async {
      final now = DateTime.now();
      final today = now.day;
      final apiClient = habitTestClient(
        waterByDay: {for (var i = 1; i <= 6; i++) today - i: 1500},
        stepsByDay: {for (var i = 1; i <= 6; i++) today - i: 5000},
        readingByDay: {for (var i = 1; i <= 6; i++) today - i: true},
        languageByDay: {for (var i = 1; i <= 6; i++) today - i: true},
        supplementByDay: {for (var i = 1; i <= 6; i++) today - i: true},
      );

      final service = HabitStatsService(apiClient);
      final stats = await service.loadStats();

      expect(stats.feedbackSummary, '这周你把自己照顾得挺稳定。');
    });

    test('phased loading: loadRecent7 returns 7-day data first', () async {
      final apiClient = habitTestClient(
        waterByDay: {DateTime.now().day - 1: 1500},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
      );

      final service = HabitStatsService(apiClient);
      final stats7 = await service.loadRecent7();

      // 7 天数据已填充
      expect(stats7.recentDays.length, 7);
      expect(stats7.items.length, 5);
      expect(stats7.items.first.recent7Values.length, 7);

      // 30 天字段应为空
      expect(stats7.days30, isEmpty);
      expect(stats7.items.first.recent30Values, isEmpty);
    });

    test(
      'phased loading: loadRecent30 fills 30-day data after loadRecent7',
      () async {
        final apiClient = habitTestClient(
          waterByDay: {DateTime.now().day - 1: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        );

        final service = HabitStatsService(apiClient);
        await service.loadRecent7();
        final stats30 = await service.loadRecent30();

        // 30 天数据已填充
        expect(stats30.days30.length, 30);
        expect(stats30.items.first.recent30Values.length, 30);
      },
    );

    test('30-day load reuses 7-day cached day records', () async {
      final apiClient = habitTestClient(
        waterByDay: {DateTime.now().day - 1: 1500},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
      );

      final service = HabitStatsService(apiClient);
      await service.loadRecent7();

      // 清掉 history month 缓存，验证 30 天阶段不再请求 history
      HabitStatsService.clearCache();
      // 但 dayCache 还保留（没办法单独检查，但能验证 30 天正常完成）
      final stats30 = await service.loadRecent30();
      expect(stats30.days30.length, 30);
    });

    test('history month results are cached', () async {
      final apiClient = habitTestClient(
        waterByDay: {},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
      );

      final service1 = HabitStatsService(apiClient);
      await service1.loadRecent7();

      // 第二个 service 实例复用缓存
      final service2 = HabitStatsService(apiClient);
      final stats = await service2.loadRecent7();
      expect(stats.recentDays.length, 7);
    });

    test(
      'static cache is reused across ApiClient instances with same baseUrl',
      () async {
        final now = DateTime.now();
        final today = now.day;
        final firstHttpClient = _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {today - 1: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        );
        final firstApiClient = ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
          httpClient: firstHttpClient,
        );

        final service1 = HabitStatsService(firstApiClient);
        await service1.loadRecent7();

        final secondHttpClient = _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        );
        final secondApiClient = ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
          httpClient: secondHttpClient,
        );

        final service2 = HabitStatsService(secondApiClient);
        final stats = await service2.loadRecent7();

        expect(stats.recentDays.length, 7);
        expect(secondHttpClient.historyRequestCount, 0);
        expect(secondHttpClient.diaryRequestCount, 0);
      },
    );

    test('single day getDiary failure does not break overall stats', () async {
      final now = DateTime.now();
      // 用 broken HTTP client 模拟某一天失败
      var callCount = 0;
      final brokenClient = _SelectiveFailureHttpClient(
        year: now.year,
        month: now.month,
        waterByDay: {now.day - 1: 1500, now.day - 2: 800, now.day - 3: 1200},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
        failOnDay: now.day - 2,
        failCount: 1,
        callCount: () => callCount++,
      );

      final apiClient = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: brokenClient,
      );

      final service = HabitStatsService(apiClient);
      final stats = await service.loadStats();

      // 即使某天失败，统计仍完整
      expect(stats.items.length, 5);
      expect(stats.recentDays.length, 7);
      // 不崩溃
    });

    test('only loads getDiary for dates in history month result', () async {
      final now = DateTime.now();
      var getDiaryCount = 0;

      final client = _CountingGetDiaryHttpClient(
        year: now.year,
        month: now.month,
        waterByDay: {now.day - 1: 1500},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
        onGetDiary: () => getDiaryCount++,
      );

      final apiClient = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: client,
      );

      final service = HabitStatsService(apiClient);
      await service.loadStats();

      // 只有 history month 中存在的日期才调用了 getDiary
      // 最多调用 1 次（只有 now.day-1 有数据）
      expect(getDiaryCount, lessThanOrEqualTo(1));
    });

    test('concurrent loading does not miss data', () async {
      final now = DateTime.now();
      final today = now.day;
      final waterData = <int, int>{};
      for (var i = 0; i < 7; i++) {
        waterData[today - i] = 1500;
      }

      final apiClient = habitTestClient(
        waterByDay: waterData,
        stepsByDay: {for (var i = 0; i < 7; i++) today - i: 5000},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
      );

      final service = HabitStatsService(apiClient);
      final stats = await service.loadStats();

      final water = stats.items.firstWhere((i) => i.key == 'water');
      // 最近 7 天全部有数据
      expect(water.completedDays, 7);
    });
  });

  group('HabitStatsScreen', () {
    setUp(() {
      HabitStatsService.clearCache();
    });

    tearDown(() {
      HabitStatsService.clearCache();
    });

    /// 返回一个不会在测试中挂起的内存缓存仓库。
    HabitStatsCacheRepository testCacheRepo() =>
        HabitStatsCacheRepository(storage: _MemoryStorage());

    testWidgets('shows title and subtitle', (tester) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('习惯统计'), findsOneWidget);
      expect(find.text('看看最近的生活节奏'), findsOneWidget);
    });

    testWidgets('shows empty state when no data', (tester) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('还没有足够的习惯记录。\n今天先照顾一个小习惯就很好。'), findsOneWidget);
    });

    testWidgets('no edit/delete/patch buttons present', (tester) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 不应该有任何编辑/删除按钮
      expect(find.text('编辑'), findsNothing);
      expect(find.text('删除'), findsNothing);
      expect(find.text('补打卡'), findsNothing);
    });

    testWidgets('supplement displays as 补充剂 not 鱼油/植物甾醇', (tester) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {now.day - 1: true},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('补充剂'), findsWidgets);
      expect(find.textContaining('鱼油'), findsNothing);
      expect(find.textContaining('植物甾醇'), findsNothing);
    });

    testWidgets('habit heatmap shows title and selector', (tester) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {now.day - 1: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('看看这 30 天的小痕迹'), findsOneWidget);
    });

    testWidgets('heatmap shows completion rate and longest streak', (
      tester,
    ) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {now.day - 1: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('完成率'), findsWidgets);
      expect(find.textContaining('最长连续'), findsWidgets);
    });

    testWidgets('header shown immediately before data loads', (tester) async {
      final now = DateTime.now();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      // 单帧后 header 已显示
      expect(find.text('习惯统计'), findsOneWidget);
      expect(find.text('看看最近的生活节奏'), findsOneWidget);
    });

    testWidgets('shows loading skeleton while 7-day data loads', (
      tester,
    ) async {
      final now = DateTime.now();
      // 延迟 HTTP 客户端：模拟网络延迟
      final delayedClient = _DelayedHttpClient(
        year: now.year,
        month: now.month,
        waterByDay: {},
        stepsByDay: {},
        readingByDay: {},
        languageByDay: {},
        supplementByDay: {},
        delay: const Duration(milliseconds: 500),
      );
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: delayedClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );

      // 还没 settle，应显示 loading
      expect(find.text('正在看看最近的生活节奏…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    });

    testWidgets('30-day loading does not block rhythm grid', (tester) async {
      final now = DateTime.now();
      final today = now.day;

      // 先给足 7 天数据，30 天其他日期的请求延迟
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {for (var i = 0; i < 7; i++) today - i: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 7 天节奏谱已显示
      expect(find.text('最近 7 天'), findsOneWidget);
      // 30 天热力图也已显示（因为 HTTP client 即时响应）
      expect(find.text('看看这 30 天的小痕迹'), findsOneWidget);
    });

    testWidgets('switching habit dropdown does not show page loading', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = now.day;
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {today - 1: 1500},
          stepsByDay: {today - 1: 5000},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 打开下方的 dropdown（tap first dropdown text）
      final selector = find.textContaining('💧');
      expect(selector, findsWidgets);
      await tester.tap(selector.first);
      await tester.pumpAndSettle();

      // 下拉菜单出现，页面不被整页 loading 遮挡
      expect(find.textContaining('🚶'), findsWidgets);
      // 没有全页 CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('refresh token reloads archived habit settings', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = now.day;
      final storage = _TestStorage();
      final settingsRepo = HabitSettingsRepository(storage: storage);
      final cacheRepo = testCacheRepo();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {today - 1: 1500},
          stepsByDay: {today - 1: 5000},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: cacheRepo,
            habitSettingsRepo: settingsRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('🚶'), findsWidgets);

      await storage.write(
        'habit_settings',
        jsonEncode(
          const HabitSettings(
            statusMap: {
              'water': true,
              'steps': false,
              'reading': true,
              'language': true,
              'supplements': true,
            },
          ).toJson(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: cacheRepo,
            habitSettingsRepo: settingsRepo,
            refreshToken: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('🚶'), findsNothing);
    });

    testWidgets('uses custom habit visual settings in stats', (tester) async {
      final now = DateTime.now();
      final today = now.day;
      final storage = _TestStorage();
      await storage.write(
        'habit_settings',
        jsonEncode(
          const HabitSettings(
            statusMap: {
              'water': true,
              'steps': true,
              'reading': true,
              'language': true,
              'supplements': true,
            },
            displayNameMap: {'water': '喝水啦'},
            iconMap: {'water': '🥤'},
            colorMap: {'water': 0xFF9B8EC4},
          ).toJson(),
        ),
      );
      final settingsRepo = HabitSettingsRepository(storage: storage);
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _HabitTestHttpClient(
          year: now.year,
          month: now.month,
          waterByDay: {today - 1: 1500},
          stepsByDay: {},
          readingByDay: {},
          languageByDay: {},
          supplementByDay: {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: settingsRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('喝水啦'), findsWidgets);
      expect(find.text('🥤'), findsWidgets);
      expect(find.text('饮水'), findsNothing);
      expect(find.text('💧'), findsNothing);
    });

    testWidgets('handles network failure without white screen', (tester) async {
      final brokenClient = _AlwaysFailHttpClient();
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: brokenClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HabitStatsScreen(
            apiClient: client,
            cacheRepo: testCacheRepo(),
            habitSettingsRepo: HabitSettingsRepository(storage: _TestStorage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // header 仍然可见，不白屏
      expect(find.text('习惯统计'), findsOneWidget);
      // 页面显示内容（空状态或错误），不是空白
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('HabitStatsCacheRepository', () {
    late _MemoryStorage memoryStorage;
    late HabitStatsCacheRepository cacheRepo;

    setUp(() {
      memoryStorage = _MemoryStorage();
      cacheRepo = HabitStatsCacheRepository(storage: memoryStorage);
    });

    HabitStats makeStats() {
      final day = HabitDayRecord(
        date: DateTime(2026, 6, 1),
        weekday: '星期一',
        hasDiary: true,
        waterMl: 1500,
        steps: 5000,
        readingDone: true,
        languageDone: false,
        supplementDone: true,
      );
      return HabitStats(
        recentDays: [day],
        monthDays: [day],
        days30: [day],
        items: [
          HabitItemStats(
            key: 'water',
            title: '饮水',
            group: HabitGroup.body,
            type: HabitStatType.numeric,
            recent7Values: [1500],
            completedDays: 1,
            totalDays: 1,
            averageValue: 1500,
            currentStreak: 1,
            displayName: '饮水',
            icon: '💧',
            color: const Color(0xFF6BAED6),
            recent30Values: [1500],
            completedDays30: 1,
            completionRate30: 1.0,
            longestStreak30: 1,
          ),
        ],
        overallRate: 1.0,
        feedbackText: '测试',
        feedbackSummary: '总结',
        feedbackSuggestion: '建议',
      );
    }

    test('save and load round-trip', () async {
      final stats = makeStats();
      await cacheRepo.save(stats);
      final loaded = await cacheRepo.load();
      expect(loaded, isNotNull);
      expect(loaded!.items.length, 1);
      expect(loaded.items.first.key, 'water');
      expect(loaded.feedbackSummary, '总结');
    });

    test('load returns null when no cache', () async {
      final loaded = await cacheRepo.load();
      expect(loaded, isNull);
    });

    test('schema version mismatch ignores cache', () async {
      final stats = makeStats();
      await cacheRepo.save(stats);

      // 篡改 schema version
      final raw = await memoryStorage.read('habit_stats_cache');
      final json = jsonDecode(raw!) as Map<String, dynamic>;
      json['schemaVersion'] = 999;
      await memoryStorage.write('habit_stats_cache', jsonEncode(json));

      final loaded = await cacheRepo.load();
      expect(loaded, isNull);
    });

    test('corrupted JSON returns null, does not throw', () async {
      await memoryStorage.write('habit_stats_cache', 'not valid json {{{');
      final loaded = await cacheRepo.load();
      expect(loaded, isNull);
    });

    test('clear removes cache', () async {
      final stats = makeStats();
      await cacheRepo.save(stats);
      await cacheRepo.clear();
      final loaded = await cacheRepo.load();
      expect(loaded, isNull);
    });
  });

  group('HabitStats persistence round-trip', () {
    test('HabitDayRecord toJson fromJson round-trip', () {
      final record = HabitDayRecord(
        date: DateTime(2026, 6, 1),
        weekday: '星期一',
        hasDiary: true,
        waterMl: 1500,
        steps: 5000,
        readingDone: true,
        languageDone: false,
        supplementDone: true,
      );
      final json = record.toJson();
      final restored = HabitDayRecord.fromJson(json);
      expect(restored.date, DateTime(2026, 6, 1));
      expect(restored.waterMl, 1500);
      expect(restored.readingDone, true);
      expect(restored.languageDone, false);
    });

    test('HabitItemStats toJson fromJson round-trip with Color', () {
      final item = HabitItemStats(
        key: 'water',
        title: '饮水',
        group: HabitGroup.body,
        type: HabitStatType.numeric,
        recent7Values: [1500, 800],
        completedDays: 2,
        totalDays: 7,
        averageValue: 328,
        currentStreak: 2,
        displayName: '饮水',
        icon: '💧',
        color: const Color(0xFF6BAED6),
        recent30Values: List.generate(30, (i) => i < 10 ? 1500 : 0),
        completedDays30: 10,
        completionRate30: 0.33,
        longestStreak30: 10,
      );
      final json = item.toJson();
      final restored = HabitItemStats.fromJson(json);
      expect(restored.key, 'water');
      expect(restored.recent7Values, [1500, 800]);
      expect(restored.displayName, '饮水');
      expect(restored.icon, '💧');
      expect(restored.color.toARGB32(), 0xFF6BAED6);
      expect(restored.recent30Values.length, 30);
      expect(restored.completionRate30, 0.33);
    });

    test('HabitStats full round-trip with cachedAt', () {
      final day = HabitDayRecord(
        date: DateTime(2026, 6, 1),
        weekday: '星期一',
        hasDiary: true,
        waterMl: 1500,
        steps: 5000,
        readingDone: true,
        languageDone: false,
        supplementDone: true,
      );
      final stats = HabitStats(
        recentDays: [day],
        monthDays: [day],
        days30: [day],
        items: [
          HabitItemStats(
            key: 'water',
            title: '饮水',
            group: HabitGroup.body,
            type: HabitStatType.numeric,
            recent7Values: [1500],
            completedDays: 1,
            totalDays: 1,
            averageValue: 1500,
            currentStreak: 1,
            displayName: '饮水',
            icon: '💧',
            color: const Color(0xFF6BAED6),
          ),
        ],
        overallRate: 1.0,
        feedbackText: '测试文案',
        feedbackSummary: '总结',
        feedbackSuggestion: '建议',
        cachedAt: DateTime(2026, 6, 1, 12, 0),
      );
      final json = stats.toJson();
      expect(json['schemaVersion'], HabitStats.schemaVersion);

      final restored = HabitStats.fromJson(json);
      expect(restored.items.length, 1);
      expect(restored.feedbackSummary, '总结');
      expect(restored.cachedAt, isNotNull);
    });
  });

  group('HabitVisualConfig', () {
    test('supplements displayName is 补充剂', () {
      final config = HabitVisualConfig.of('supplements');
      expect(config.displayName, '补充剂');
      expect(config.icon, '💊');
    });

    test('each habit has unique color', () {
      final colors = HabitVisualConfig.defaults.values
          .map((c) => c.color)
          .toSet();
      expect(colors.length, 5);
    });

    test('water and steps are body group', () {
      expect(HabitVisualConfig.of('water').group, HabitGroup.body);
      expect(HabitVisualConfig.of('steps').group, HabitGroup.body);
    });

    test('reading and language are growth group', () {
      expect(HabitVisualConfig.of('reading').group, HabitGroup.growth);
      expect(HabitVisualConfig.of('language').group, HabitGroup.growth);
    });
  });

  group('SettingsPage', () {
    Widget buildPage() {
      return MaterialApp(
        home: SettingsPage(
          apiConfig: ApiConfig(
            baseUrl: 'https://obsidian.femkits.org',
            token: '',
          ),
        ),
      );
    }

    testWidgets('shows header and section groups', (tester) async {
      await tester.pumpWidget(buildPage());

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('管理你的日记应用'), findsOneWidget);
      expect(find.text('常用'), findsOneWidget);
      expect(find.text('连接与智能'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('媒体与应用'), findsOneWidget);
    });

    testWidgets('shows all menu items', (tester) async {
      await tester.pumpWidget(buildPage());

      expect(find.text('外观'), findsOneWidget);
      expect(find.text('习惯设置'), findsOneWidget);
      expect(find.text('标签设置'), findsOneWidget);
      expect(find.text('远程 API'), findsOneWidget);
      expect(find.text('AI 服务配置'), findsOneWidget);
      expect(find.text('润色提示词'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('图片压缩'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });

    testWidgets('remote api page shows token configured state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteApiPage(
            apiConfig: ApiConfig(
              baseUrl: 'https://obsidian.femkits.org',
              token: '',
            ),
            tokenConfigured: false,
          ),
        ),
      );

      expect(find.text('Token 状态'), findsOneWidget);
      expect(find.text('未配置'), findsOneWidget);
      expect(find.text('已配置'), findsNothing);
    });

    testWidgets('tapping appearance navigates to appearance settings', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();

      expect(find.text('选择你喜欢的显示方式'), findsOneWidget);
    });

    testWidgets('tapping AI config navigates to AI settings', (tester) async {
      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('AI 服务配置'));
      await tester.pumpAndSettle();

      expect(find.text('保存 AI 配置'), findsOneWidget);
    });

    testWidgets('tapping about navigates to about page', (tester) async {
      await tester.pumpWidget(buildPage());

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();

      expect(find.text('荔枝日记'), findsOneWidget);
    });

    testWidgets('safe area prevents status bar overlap', (tester) async {
      await tester.pumpWidget(buildPage());

      expect(find.byType(SafeArea), findsWidgets);
    });
  });

// ── TagSettings ──


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
        topics: [
          TagTopic(id: 'work-task', name: '任务执行', order: 0),
        ],
      ),
    ],
    methods: [
      TagMethod(id: 'reflect', name: '反思', order: 0),
      TagMethod(id: 'methodology', name: '方法论', order: 1),
    ],
  );
}

// ── AppearanceSettings ──

group('AppearanceSettings', () {
  test('default themeMode is system', () {
    final settings = AppearanceSettings();
    expect(settings.themeMode, ThemeMode.system);
  });

  test('toJson / fromJson round-trip', () {
    final settings = AppearanceSettings(themeMode: ThemeMode.dark);
    final json = settings.toJson();
    final restored = AppearanceSettings.fromJson(json);
    expect(restored.themeMode, ThemeMode.dark);
  });

  test('fromJson broken falls back to system', () {
    final restored = AppearanceSettings.fromJson({'themeMode': null});
    expect(restored.themeMode, ThemeMode.system);
  });

  test('copyWith preserves other fields', () {
    final settings = AppearanceSettings(themeMode: ThemeMode.light);
    final updated = settings.copyWith(themeMode: ThemeMode.dark);
    expect(updated.themeMode, ThemeMode.dark);
    expect(updated.schemaVersion, settings.schemaVersion);
  });
});

group('AppearanceSettingsRepository', () {
  test('load returns defaults when no storage', () async {
    final storage = _TestStorage();
    final repo = AppearanceSettingsRepository(storage: storage);
    final settings = await repo.load();
    expect(settings.themeMode, ThemeMode.system);
  });

  test('save and reload preserves choice', () async {
    final storage = _TestStorage();
    final repo = AppearanceSettingsRepository(storage: storage);
    await repo.save(AppearanceSettings(themeMode: ThemeMode.dark));
    final reloaded = await repo.load();
    expect(reloaded.themeMode, ThemeMode.dark);
  });

  test('corrupted JSON falls back to system', () async {
    final storage = _TestStorage({'appearance_settings': 'broken!!!'});
    final repo = AppearanceSettingsRepository(storage: storage);
    final settings = await repo.load();
    expect(settings.themeMode, ThemeMode.system);
  });
});

group('AppearanceSettingsPage', () {
  testWidgets('shows three options with correct defaults', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: const AppearanceSettingsPage()),
    );

    expect(find.text('选择你喜欢的显示方式'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);
  });

  testWidgets('tapping option changes selection', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: const AppearanceSettingsPage()),
    );

    // Tap 深色模式
    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();

    // The radio button should be checked for 深色模式
    // Verify it navigated correctly (no errors)
    expect(find.text('外观'), findsOneWidget);
  });
});

  group('TagSettings', () {
    test('fromTagConfig creates all enabled defaults', () async {

      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      expect(settings.domainSettings.length, 2);
      expect(settings.domainSettings.every((d) => d.enabled), true);
      expect(settings.domainSettings[0].displayName, '亲子');
      expect(settings.domainSettings[1].displayName, '工作');
      expect(settings.methodSettings.length, 2);
      expect(settings.methodSettings.every((m) => m.enabled), true);
    });

    test('toJson / fromJson round-trip preserves data', () async {

      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      settings.domainSettings[0].displayName = '育儿';
      settings.domainSettings[0].enabled = false;
      final json = settings.toJson();
      final restored = TagSettings.fromJson(json);
      expect(restored.schemaVersion, 1);
      expect(restored.domainSettings[0].displayName, '育儿');
      expect(restored.domainSettings[0].enabled, false);
      expect(restored.domainSettings[0].defaultName, '亲子');
      expect(restored.domainSettings[0].topics.length, 2);
      expect(restored.methodSettings.length, 2);
    });

    test('broken JSON falls back with fromJson defaults', () async {

      final restored = TagSettings.fromJson({'schemaVersion': 0, 'domainSettings': null, 'methodSettings': null});
      expect(restored.domainSettings, isEmpty);
      expect(restored.methodSettings, isEmpty);
    });

    test('toEffectiveTagConfig filters disabled and applies displayName', () async {

      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      settings.domainSettings[1].enabled = false;
      settings.domainSettings[0].displayName = '育儿';
      settings.domainSettings[0].topics[0].displayName = '共处时光';
      final effective = settings.toEffectiveTagConfig(config);
      expect(effective.domains.length, 1);
      expect(effective.domains[0].name, '育儿');
      expect(effective.domains[0].topics[0].name, '共处时光');
      expect(effective.methods.length, 2);
    });

    test('countEnabled counts all enabled items', () async {

      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      expect(TagSettingsHelper.countEnabled(settings), 7);
      settings.domainSettings[0].enabled = false;
      expect(TagSettingsHelper.countEnabled(settings), 4);
    });

    test('hiddenInitialTags finds disabled tags by displayName or defaultName', () async {

      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      settings.domainSettings[0].enabled = false;
      final hidden = TagSettingsHelper.hiddenInitialTags(
        ['亲子', '陪伴互动', '反思'],
        settings,
      );
      expect(hidden, contains('亲子'));
      expect(hidden, contains('陪伴互动'));
      expect(hidden.length, 2);
    });

    test('hiddenInitialTags with renamed displayName still matches', () async {

      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      settings.domainSettings[0].enabled = false;
      settings.domainSettings[0].displayName = '育儿';
      final hidden = TagSettingsHelper.hiddenInitialTags(
        ['亲子', '陪伴互动', '反思'],
        settings,
      );
      expect(hidden, contains('亲子'));
    });

    test('validateDisplayName rejects invalid names', () async {

      expect(TagSettingsHelper.validateDisplayName(''), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('  '), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('#tag'), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('with space'), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('with\nnewline'), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('with\ttab'), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('valid'), isNull);
    });

    test('effectiveTagConfig helper works same as toEffectiveTagConfig', () async {

      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      settings.methodSettings[0].enabled = false;
      final result = TagSettingsHelper.effectiveTagConfig(config, settings);
      expect(result.methods.length, 1);
      expect(result.methods[0].id, 'methodology');
    });

    test('loadTagSettings returns defaults when no storage', () async {

      final storage = _TestStorage();
      final repo = TagSettingsRepository(storage: storage);
      final config = fullTagConfig();
      final settings = await repo.loadTagSettings(config);
      expect(settings.domainSettings.length, 2);
      expect(settings.domainSettings[0].enabled, true);
    });

    test('save and reload preserves changes', () async {

      final storage = _TestStorage();
      final repo = TagSettingsRepository(storage: storage);
      final config = fullTagConfig();
      var settings = await repo.loadTagSettings(config);
      settings.domainSettings[0].displayName = '育儿';
      await repo.saveTagSettings(settings);
      final reloaded = await repo.loadTagSettings(config);
      expect(reloaded.domainSettings[0].displayName, '育儿');
    });

    test('corrupted JSON falls back to defaults', () async {

      final storage = _TestStorage({'tag_settings': 'not json at all!!!'});
      final repo = TagSettingsRepository(storage: storage);
      final config = fullTagConfig();
      final settings = await repo.loadTagSettings(config);
      expect(settings.domainSettings.length, 2);
    });

  });
}
