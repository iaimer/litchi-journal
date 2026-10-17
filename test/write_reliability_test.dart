import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/models/focus_timer.dart';
import 'package:litchi_journal_flutter/screens/focus_timer_screen.dart';
import 'package:litchi_journal_flutter/services/focus_timer_controller.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/focus_timer_repository.dart';
import 'package:litchi_journal_flutter/services/markdown_parser.dart';

class _Storage implements FocusTimerStorage {
  String? value;
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String value) async => this.value = value;
  @override
  Future<void> delete(String key) async => value = null;
}

final _target = HabitTimerTarget(
  habitKey: 'reading',
  displayName: '阅读',
  markdownLabel: '📖 阅读/亲子共读',
  icon: 'habit-read',
  colorArgb: 0xFF7BA67A,
  diaryDate: DateTime(2026, 10, 18),
  rawLine: '- [ ] 📖 阅读/亲子共读 0 分钟',
  currentMinutes: 0,
);

void main() {
  test(
    'timer retries use the same operation id and frozen HTTP payload',
    () async {
      var now = DateTime(2026, 10, 18, 8);
      final controller = FocusTimerController(
        repository: FocusTimerRepository(storage: _Storage()),
        now: () => now,
      );
      await controller.start(_target);
      now = now.add(const Duration(minutes: 2));
      final requests = <Map<String, dynamic>>[];
      final api = ApiClient(
        ApiConfig(baseUrl: 'https://fixture.invalid', token: 'fixture'),
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          if (requests.length == 1) return http.Response('{}', 500);
          return http.Response(
            jsonEncode({
              'success': true,
              'minutes': 2,
              'completed': true,
              'rawLine': '- [x] 📖 阅读/亲子共读 2 分钟',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      Future<bool> save(FocusTimerSession session, int minutes) async =>
          await api.updateHabitDuration(
            session.diaryDate,
            habitKey: session.habitKey,
            label: session.markdownLabel,
            rawLine: session.rawLine,
            minutes: minutes,
            replace: false,
            operationId: session.saveOperationId,
          ) !=
          null;
      expect(await controller.save(save), false);
      now = now.add(const Duration(minutes: 5));
      expect(await controller.save(save), true);
      expect(requests.last, requests.first);
      expect(requests.last['minutes'], 2);
      expect(controller.session, isNull);
      controller.dispose();
      api.dispose();
    },
  );

  test(
    'Parser does not absorb independent images or pasted identity comments',
    () {
      const id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      const entry = '- **08:00** 正文\n  <!-- litchi-entry-id:$id -->';
      final doc = const MarkdownParser().parse(
        '## ✍️ 随手记 & 灵感\n$entry\n![[独立.jpg]]',
      );
      final note = doc.sections
          .whereType<QuickNoteSection>()
          .single
          .notes
          .single;
      expect(note.rawLine, entry);
      expect(note.entryId, isNull);
      expect(note.content, contains('litchi-entry-id:'));
    },
  );

  test(
    'repeated save clicks cannot submit an in-flight session twice',
    () async {
      var now = DateTime(2026, 10, 18, 8);
      final controller = FocusTimerController(
        repository: FocusTimerRepository(storage: _Storage()),
        now: () => now,
      );
      await controller.start(_target);
      now = now.add(const Duration(minutes: 1));
      final response = Completer<bool>();
      var calls = 0;
      Future<bool> save(FocusTimerSession session, int minutes) {
        calls++;
        return response.future;
      }

      final first = controller.save(save);
      expect(await controller.save(save), false);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      response.complete(true);
      expect(await first, true);
      controller.dispose();
    },
  );
  for (final continuation in [
    '  ## 细节',
    '  - [ ] 子任务',
    '  - **08:00** 正文里的时间',
    '  <!-- 正文注释 -->',
    '  ![[正文照片.jpg]]',
  ]) {
    test('Parser keeps $continuation inside the exact record', () {
      final entry = '- **18:00** 晚间\n$continuation\n  续行';
      final doc = const MarkdownParser().parse(
        '## ✍️ 随手记 & 灵感\n$entry\n- **19:00** 下一条',
      );
      final notes = doc.sections.whereType<QuickNoteSection>().single.notes;
      expect(notes.length, 2);
      expect(notes.first.rawLine, entry);
    });
  }

  testWidgets(
    'failed save persists one frozen request and reuses it after restart',
    (tester) async {
      final storage = _Storage();
      var now = DateTime(2026, 10, 18, 8);
      final repository = FocusTimerRepository(storage: storage);
      var controller = FocusTimerController(
        repository: repository,
        now: () => now,
      );
      await controller.start(_target);
      now = now.add(const Duration(minutes: 1, seconds: 10));
      final requests = <Map<String, dynamic>>[];
      Future<bool> save(FocusTimerSession session, int minutes) async {
        final persisted = jsonDecode(storage.value!) as Map<String, dynamic>;
        expect(persisted['saveOperationId'], isNotEmpty);
        requests.add({...session.toJson(), 'requestedMinutes': minutes});
        return false;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: FocusTimerScreen(controller: controller, onSave: save),
        ),
      );
      await _finish(tester, 1);
      expect(await controller.resume(), false);
      final firstId = requests.single['saveOperationId'];
      expect(firstId, matches(RegExp(r'^[0-9a-f-]{36}$')));
      await tester.pumpWidget(const SizedBox());
      controller.dispose();

      now = now.add(const Duration(minutes: 5));
      controller = FocusTimerController(repository: repository, now: () => now);
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          home: FocusTimerScreen(controller: controller, onSave: save),
        ),
      );
      await _finish(tester, 1);
      expect(requests.last['saveOperationId'], firstId);
      expect(requests.last['requestedMinutes'], 1);
      controller.dispose();
    },
  );

  testWidgets(
    'a thrown save restores interaction and retains the frozen session',
    (tester) async {
      var now = DateTime(2026, 10, 18, 8);
      final controller = FocusTimerController(
        repository: FocusTimerRepository(storage: _Storage()),
        now: () => now,
      );
      await controller.start(_target);
      now = now.add(const Duration(minutes: 1));
      await tester.pumpWidget(
        MaterialApp(
          home: FocusTimerScreen(
            controller: controller,
            onSave: (_, _) async => throw TimeoutException('response lost'),
          ),
        ),
      );
      await _finish(tester, 1);
      expect(tester.takeException(), isNull);
      expect(find.text('保存失败，计时仍保留'), findsOneWidget);
      expect(controller.isBusy, false);
      expect(controller.session, isNotNull);
      controller.dispose();
    },
  );

  testWidgets(
    'committed save clears the session even if the page was removed',
    (tester) async {
      final storage = _Storage();
      var now = DateTime(2026, 10, 18, 8);
      final controller = FocusTimerController(
        repository: FocusTimerRepository(storage: storage),
        now: () => now,
      );
      await controller.start(_target);
      now = now.add(const Duration(minutes: 1));
      final completion = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: FocusTimerScreen(
            controller: controller,
            onSave: (_, _) => completion.future,
          ),
        ),
      );
      await _finish(tester, 1);
      await tester.pumpWidget(const SizedBox());
      completion.complete(true);
      await tester.pump();
      await tester.pump();
      expect(controller.session, isNull);
      expect(storage.value, isNull);
      controller.dispose();
    },
  );
}

Future<void> _finish(WidgetTester tester, int minutes) async {
  final finish = find.text('完成');
  final retry = find.text('重试保存');
  await tester.tap(finish.evaluate().isNotEmpty ? finish : retry);
  await tester.pumpAndSettle();
  await tester.tap(find.text('保存 $minutes 分钟'));
  await tester.pumpAndSettle();
}
