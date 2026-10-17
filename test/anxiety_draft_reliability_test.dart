import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/services/draft_repository.dart';
import 'package:litchi_journal_flutter/widgets/anxiety_composer.dart';

class _DelayedDraftStorage implements DraftStorage {
  final pending = Completer<String?>();
  String? written;

  @override
  Future<String?> read(String key) => pending.future;
  @override
  Future<void> write(String key, String value) async => written = value;
  @override
  Future<void> delete(String key) async => written = null;

  void completeDraft() => pending.complete(
    jsonEncode(
      AnxietyDraft(
        step: 2,
        answers: ['旧场景', '旧担心', '旧应对', '旧反思'],
        updatedAt: DateTime.now(),
      ).toJson(),
    ),
  );
}

Widget _composer(
  _DelayedDraftStorage storage, {
  List<String>? initialAnswers,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: AnxietyComposer(
        date: DateTime(2026, 10, 18),
        draftRepository: DraftRepository(storage: storage),
        initialAnswers: initialAnswers,
        onSubmit: (_, _) async {},
      ),
    ),
  ),
);

void main() {
  testWidgets('late anxiety draft cannot replace new text or reset its step', (
    tester,
  ) async {
    final storage = _DelayedDraftStorage();
    await tester.pumpWidget(_composer(storage));
    await tester.enterText(find.byType(TextField), '刚刚输入的新场景');
    storage.completeDraft();
    await tester.pumpAndSettle();
    expect(find.text('刚刚输入的新场景'), findsOneWidget);
    expect(find.text('旧应对'), findsNothing);
    expect(find.text('1/4'), findsOneWidget);
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(storage.written, contains('刚刚输入的新场景'));
  });

  testWidgets('typing then clearing still prevents late draft restoration', (
    tester,
  ) async {
    final storage = _DelayedDraftStorage();
    await tester.pumpWidget(_composer(storage));
    await tester.enterText(find.byType(TextField), '输入后删掉');
    await tester.enterText(find.byType(TextField), '');
    storage.completeDraft();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('1/4'), findsOneWidget);
  });

  testWidgets(
    'moving to an empty next question prevents late draft restoration',
    (tester) async {
      final storage = _DelayedDraftStorage();
      await tester.pumpWidget(_composer(storage));
      await tester.tap(find.text('跳过'));
      await tester.pump();
      storage.completeDraft();
      await tester.pumpAndSettle();
      expect(find.text('2/4'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('draft read failure preserves input and lets the user continue', (
    tester,
  ) async {
    final storage = _DelayedDraftStorage();
    await tester.pumpWidget(
      _composer(storage, initialAnswers: ['初始场景', '', '', '']),
    );
    await tester.enterText(find.byType(TextField), '用户新场景');
    storage.pending.completeError(StateError('storage unavailable'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('用户新场景'), findsOneWidget);
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('2/4'), findsOneWidget);
    expect(storage.written, contains('用户新场景'));
  });

  testWidgets('untouched form restores the stored question and answer', (
    tester,
  ) async {
    final storage = _DelayedDraftStorage();
    await tester.pumpWidget(_composer(storage));
    storage.completeDraft();
    await tester.pumpAndSettle();
    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('旧应对'), findsOneWidget);
  });

  testWidgets(
    'draft read failure falls back to initial answers in an untouched form',
    (tester) async {
      final storage = _DelayedDraftStorage();
      await tester.pumpWidget(
        _composer(storage, initialAnswers: ['初始场景', '', '', '']),
      );
      storage.pending.completeError(StateError('storage unavailable'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('初始场景'), findsOneWidget);
    },
  );
}
