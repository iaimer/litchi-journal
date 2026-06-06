import 'package:flutter_test/flutter_test.dart';

import 'package:litchi_journal_flutter/models/diary_entry.dart';

void main() {
  test('DiaryEntry.fromJson parses valid data', () {
    final json = {
      'date': '2026-06-06',
      'title': 'Test',
      'raw': 'Hello world',
      'sections': {
        'notes': ['note1', 'note2']
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
}
