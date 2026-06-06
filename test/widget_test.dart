import 'package:flutter_test/flutter_test.dart';

import 'package:litchi_journal_flutter/models/diary_entry.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/services/markdown_parser.dart';

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
    expect(document.sections.whereType<ReviewSection>(), hasLength(1));
    expect(document.sections.whereType<MediaSection>(), hasLength(1));

    final habit = document.sections.whereType<HabitSection>().single;
    expect(habit.contents.whereType<CheckboxContent>(), hasLength(2));
    expect(habit.habits, hasLength(3));
    expect(habit.habits[0].label, '📖 阅读/亲子共读');
    expect(habit.habits[0].checked, isTrue);
    expect(habit.habits[0].rawLine, '- [x] 📖 阅读/亲子共读');
    expect(habit.habits[1].label, '💊 鱼油/植物甾醇');
    expect(habit.habits[1].checked, isFalse);
    expect(habit.habits[1].rawLine, '- [ ] 💊 鱼油/植物甾醇');
    expect(habit.habits[2].label, '喝水 8 杯');

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
    expect(
      quickNote.notes.single.rawLine,
      '- **09:30** 写下一个想法 #生活 #日常记录',
    );

    final anxiety = document.sections.whereType<AnxietySection>().single;
    expect(anxiety.isEmpty, isTrue);

    final review = document.sections.whereType<ReviewSection>().single;
    expect(review.isEmpty, isFalse);
  });
}
