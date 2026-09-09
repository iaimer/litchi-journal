import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/models/focus_timer.dart';
import 'package:litchi_journal_flutter/models/habit_settings.dart';
import 'package:litchi_journal_flutter/screens/focus_timer_screen.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/focus_timer_controller.dart';
import 'package:litchi_journal_flutter/services/focus_timer_repository.dart';
import 'package:litchi_journal_flutter/services/markdown_parser.dart';
import 'package:litchi_journal_flutter/widgets/habit_card.dart';

class _MemoryFocusStorage implements FocusTimerStorage {
  String? value;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async => this.value = value;

  @override
  Future<void> delete(String key) async => value = null;
}

class _DeleteFailingFocusStorage extends _MemoryFocusStorage {
  @override
  Future<void> delete(String key) async {
    throw StateError('delete failed');
  }
}

HabitTimerTarget _target({int currentMinutes = 0}) {
  return HabitTimerTarget(
    habitKey: 'reading',
    displayName: '亲子共读',
    markdownLabel: '📖 阅读/亲子共读 0 分钟',
    icon: 'habit-read',
    colorArgb: 0xFF7BA67A,
    diaryDate: DateTime(2026, 9, 9),
    rawLine: '- [ ] 📖 阅读/亲子共读 0 分钟',
    currentMinutes: currentMinutes,
    dailyTargetMinutes: 30,
  );
}

FocusTimerSession _session() {
  final started = DateTime(2026, 9, 9, 8);
  return FocusTimerSession(
    habitKey: 'reading',
    displayName: '亲子共读',
    markdownLabel: '📖 阅读/亲子共读 0 分钟',
    icon: 'habit-read',
    colorArgb: 0xFF7BA67A,
    diaryDate: DateTime(2026, 9, 9),
    startedAt: started,
    accumulatedSeconds: 10,
    state: FocusTimerState.running,
    runningSince: started,
    rawLine: '- [ ] 📖 阅读/亲子共读 0 分钟',
    currentMinutes: 0,
    dailyTargetMinutes: 30,
  );
}

void main() {
  group('FocusTimerSession', () {
    test('uses timestamps for elapsed, pause, resume, and persistence', () {
      final session = _session();
      final now = DateTime(2026, 9, 9, 8, 1, 30);

      expect(session.elapsedSeconds(now), 100);

      final paused = session.pauseAt(now);
      expect(paused.isPaused, isTrue);
      expect(paused.runningSince, isNull);
      expect(paused.elapsedSeconds(now.add(const Duration(minutes: 5))), 100);

      final resumed = paused.resumeAt(now.add(const Duration(minutes: 5)));
      expect(resumed.elapsedSeconds(now.add(const Duration(minutes: 6))), 160);

      final restored = FocusTimerSession.fromJson(session.toJson());
      expect(restored.habitKey, session.habitKey);
      expect(restored.elapsedSeconds(now), 100);
    });

    test('rejects malformed persisted sessions', () {
      expect(
        () => FocusTimerSession.fromJson({'habitKey': 'reading'}),
        throwsFormatException,
      );
    });
  });

  group('FocusTimerController', () {
    test('persists one session and survives pause/resume', () async {
      final storage = _MemoryFocusStorage();
      final repository = FocusTimerRepository(storage: storage);
      var now = DateTime(2026, 9, 9, 8);
      final controller = FocusTimerController(
        repository: repository,
        now: () => now,
      );

      await controller.load();
      expect(await controller.start(_target()), isTrue);
      now = now.add(const Duration(seconds: 95));
      expect(controller.elapsedSeconds(), 95);

      expect(await controller.pause(), isTrue);
      now = now.add(const Duration(minutes: 3));
      expect(controller.elapsedSeconds(), 95);

      expect(await controller.resume(), isTrue);
      now = now.add(const Duration(seconds: 25));
      expect(controller.elapsedSeconds(), 120);
      expect(storage.value, isNotNull);

      expect(await controller.discard(), isTrue);
      expect(controller.session, isNull);
      expect(storage.value, isNull);
      controller.dispose();
    });

    test(
      'loads a persisted session without replacing a newly started one',
      () async {
        final storage = _MemoryFocusStorage();
        final repository = FocusTimerRepository(storage: storage);
        final controller = FocusTimerController(repository: repository);

        await controller.start(_target());
        final started = controller.session;
        await controller.load();

        expect(controller.session, same(started));
        await controller.discard();
        controller.dispose();
      },
    );

    test('clears the in-memory session when storage deletion fails', () async {
      final storage = _DeleteFailingFocusStorage();
      final repository = FocusTimerRepository(storage: storage);
      final controller = FocusTimerController(repository: repository);

      await controller.start(_target());
      expect(await controller.clearAfterSave(), isFalse);
      expect(controller.session, isNull);
      expect(await repository.load(), isNull);
      controller.dispose();
    });
  });

  group('Duration habit model and parser', () {
    test('parses duration rows while keeping raw Markdown line', () {
      const raw = '''
## 🏃 习惯打卡
- [x] 📖 阅读/亲子共读 35 分钟
- [ ] 📝 法语听力 12 min
''';
      final section = const MarkdownParser()
          .parse(raw)
          .sections
          .whereType<HabitSection>()
          .single;

      expect(section.habits[0].kind, HabitKind.duration);
      expect(section.habits[0].value, 35);
      expect(section.habits[0].rawLine, '- [x] 📖 阅读/亲子共读 35 分钟');
      expect(section.habits[1].kind, HabitKind.duration);
      expect(section.habits[1].value, 12);
    });

    test(
      'limits duration settings to supported habits and migrates schema 6',
      () {
        final migrated = HabitSettings.fromJson(const {
          'schemaVersion': 6,
          'statusMap': {'reading': true, 'supplements': true},
        });
        expect(migrated.trackingTypeFor('reading'), HabitTrackingType.duration);
        expect(
          migrated.trackingTypeFor('supplements'),
          HabitTrackingType.checkbox,
        );

        final custom = migrated.updateHabit(
          key: 'custom_language',
          trackingType: HabitTrackingType.duration,
          durationDailyTargetMinutes: 20,
          durationLifetimeTargetMinutes: 1000,
        );
        expect(
          custom.trackingTypeFor('custom_language'),
          HabitTrackingType.duration,
        );
        expect(custom.durationDailyTargetFor('custom_language'), 20);
        expect(custom.durationLifetimeTargetFor('custom_language'), 1000);

        final unsupported = migrated.updateHabit(
          key: 'supplements',
          trackingType: HabitTrackingType.duration,
          durationDailyTargetMinutes: 30,
        );
        expect(
          unsupported.trackingTypeFor('supplements'),
          HabitTrackingType.checkbox,
        );
        expect(unsupported.durationDailyTargetFor('supplements'), isNull);
      },
    );

    test('matches renamed custom habits through current name and aliases', () {
      final settings = HabitSettings.defaults
          .copyWith(
            statusMap: {'custom_reading': true},
            extraHabits: {'custom_reading': '旧阅读'},
          )
          .updateHabit(
            key: 'custom_reading',
            displayName: '亲子共读',
            trackingType: HabitTrackingType.duration,
          )
          .appendHabitAlias(key: 'custom_reading', newName: '旧阅读');

      expect(settings.customHabitKeyForLabel('📝 亲子共读'), 'custom_reading');
      expect(settings.customHabitKeyForLabel('📝 旧阅读'), 'custom_reading');
      expect(settings.customHabitKeyForLabel('📝 不相关'), isNull);
    });
  });

  group('Duration HabitCard', () {
    HabitSection section() {
      return const HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          HabitItem(
            kind: HabitKind.duration,
            label: '📖 阅读/亲子共读 0 分钟',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 📖 阅读/亲子共读 0 分钟',
            value: 0,
            unit: '分钟',
          ),
        ],
      );
    }

    HabitSection sectionWithMinutes() {
      return const HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          HabitItem(
            kind: HabitKind.duration,
            label: '📖 阅读/亲子共读 20 分钟',
            checked: true,
            checkable: true,
            rawLine: '- [x] 📖 阅读/亲子共读 20 分钟',
            value: 20,
            unit: '分钟',
          ),
        ],
      );
    }

    testWidgets('starts from the whole row and manually appends duration', (
      tester,
    ) async {
      HabitTimerTarget? started;
      int? savedMinutes;
      bool? replaced;
      var feedbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section(),
              habitSettings: HabitSettings.defaults,
              onUpdate: (_) async => true,
              onStartDuration: (target) async {
                started = target;
                return true;
              },
              onDurationUpdate: (target, minutes, replace) async {
                savedMinutes = minutes;
                replaced = replace;
                return true;
              },
              onPositiveFeedback: () => feedbackCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('duration_row_reading')));
      await tester.pump();
      expect(started?.habitKey, 'reading');
      expect(started?.diaryDate, isNotNull);

      await tester.tap(find.byTooltip('手动记录时长'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '15');
      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      expect(savedMinutes, 15);
      expect(replaced, isFalse);
      expect(find.text('15 分钟'), findsOneWidget);
      expect(feedbackCount, 1);
    });

    testWidgets('rolls back duration when saving fails', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section(),
              habitSettings: HabitSettings.defaults,
              onUpdate: (_) async => true,
              onStartDuration: (_) async => true,
              onDurationUpdate: (_, _, _) async => false,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('手动记录时长'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '15');
      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      expect(find.text('更新失败'), findsOneWidget);
      expect(find.text('未开始'), findsOneWidget);
    });

    testWidgets(
      'clearing duration does not fall back to the old parsed value',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HabitCard(
                section: sectionWithMinutes(),
                habitSettings: HabitSettings.defaults,
                onUpdate: (_) async => true,
                onStartDuration: (_) async => true,
                onDurationUpdate: (_, _, _) async => true,
              ),
            ),
          ),
        );

      expect(find.text('20 分钟'), findsOneWidget);
        await tester.tap(find.byTooltip('手动记录时长'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '0');
        await tester.tap(find.text('设为'));
        await tester.pumpAndSettle();

        expect(find.text('未开始'), findsOneWidget);
      expect(find.text('20 分钟'), findsNothing);
      },
    );
  });

  testWidgets('focus timer saves whole minutes and clears the session', (
    tester,
  ) async {
    final storage = _MemoryFocusStorage();
    final repository = FocusTimerRepository(storage: storage);
    var now = DateTime(2026, 9, 9, 8);
    final controller = FocusTimerController(
      repository: repository,
      now: () => now,
    );
    await controller.start(_target());
    now = now.add(const Duration(minutes: 1, seconds: 20));
    var savedMinutes = 0;
    var soundCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FocusTimerScreen(
          controller: controller,
          onSave: (_, minutes) async {
            savedMinutes = minutes;
            return true;
          },
          onPositiveFeedback: () => soundCount++,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存 1 分钟'));
    await tester.pumpAndSettle();

    expect(savedMinutes, 1);
    expect(soundCount, 1);
    expect(storage.value, isNull);
    controller.dispose();
  });

  test(
    'ApiClient sends a duration operation without changing the habit payload',
    () async {
      final client = _DurationCapturingClient();
      final api = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: client,
      );

      final result = await api.updateHabitDuration(
        DateTime(2026, 9, 9),
        habitKey: 'reading',
        label: '📖 阅读/亲子共读 0 分钟',
        rawLine: '- [ ] 📖 阅读/亲子共读 0 分钟',
        minutes: 15,
        replace: false,
        dailyTargetMinutes: 30,
      );

      final body = jsonDecode(client.body!) as Map<String, dynamic>;
      expect(client.url!.path, '/api/v1/diary/habit/duration');
      expect(body['habitKey'], 'reading');
      expect(body['minutes'], 15);
      expect(body['operation'], 'add');
      expect(body['dailyTargetMinutes'], 30);
      expect(result?.minutes, 15);
    },
  );
}

class _DurationCapturingClient extends http.BaseClient {
  Uri? url;
  String? body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    url = request.url;
    body = await request.finalize().bytesToString();
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'success': true,
            'minutes': 15,
            'completed': false,
            'rawLine': '- [ ] 📖 阅读/亲子共读 15 分钟',
          }),
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
