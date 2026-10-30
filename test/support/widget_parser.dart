part of '../widget_test.dart';

void registerParserTests() {
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

  test('MarkdownParser links photo blocks to note and happiness entries', () {
    const noteId = '11111111-1111-4111-8111-111111111111';
    const happinessId = '22222222-2222-4222-8222-222222222222';
    const markdown =
        '''
## ✍️ 随手记 & 灵感
- **08:00** 随手记第一段。

随手记最后一段。 #记录
<!-- litchi-entry-id:$noteId -->

## ✨ 每日小确幸
> **09:00** 小确幸正文。
<!-- litchi-entry-id:$happinessId -->

## 📸 影像记录
![[note.jpg]]
<!-- litchi-photo-of:$noteId;op:33333333-3333-4333-8333-333333333333 -->
![[happiness.jpg]]
<!-- litchi-photo-of:$happinessId;op:44444444-4444-4444-8444-444444444444 -->
![[orphan.jpg]]
''';

    final document = const MarkdownParser().parse(markdown);
    final note = document.sections
        .whereType<QuickNoteSection>()
        .single
        .contents
        .whereType<TimelineContent>()
        .single;
    final happiness = document.sections
        .whereType<HappinessSection>()
        .single
        .contents
        .whereType<TimelineContent>()
        .single;
    final media = document.sections.whereType<MediaSection>().single;

    expect(note.entryId, noteId);
    expect(note.text, '随手记第一段。\n\n随手记最后一段。');
    expect(note.rawLine, contains('<!-- litchi-entry-id:$noteId -->'));
    expect(note.photos.single.filename, 'note.jpg');
    expect(note.photos.single.rawLine, contains('litchi-photo-of:$noteId'));
    expect(happiness.entryId, happinessId);
    expect(happiness.photos.single.filename, 'happiness.jpg');
    expect(media.photos.map((photo) => photo.filename), [
      'note.jpg',
      'happiness.jpg',
      'orphan.jpg',
    ]);
  });

  test(
    'Parser only uses the trailing entry id and keeps invalid photo links',
    () {
      const copiedId = '11111111-1111-4111-8111-111111111111';
      const actualId = '22222222-2222-4222-8222-222222222222';
      const markdown =
          '''
## ✍️ 随手记 & 灵感
- **08:00** 正文
  <!-- litchi-entry-id:$copiedId -->
<!-- litchi-entry-id:$actualId -->

## 📸 影像记录
![[linked.jpg]]
<!-- litchi-photo-of:$actualId;op:33333333-3333-4333-8333-333333333333 -->
![[orphan.jpg]]
<!-- litchi-photo-of:$actualId;op:------------------------------------ -->
''';

      final document = const MarkdownParser().parse(markdown);
      final note = document.sections
          .whereType<QuickNoteSection>()
          .single
          .notes
          .single;
      final media = document.sections.whereType<MediaSection>().single;
      expect(note.entryId, actualId);
      expect(note.photos.single.filename, 'linked.jpg');
      expect(note.content, contains('litchi-entry-id:$copiedId'));
      expect(media.photos.map((photo) => photo.entryId), [actualId, null]);
      expect(
        media.photos.last.rawLine,
        contains('op:------------------------------------'),
      );
    },
  );

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

    expect(find.text('明日寄语'), findsOneWidget);
    expect(find.text('🌙 明日寄语'), findsNothing);
    expect(find.textContaining('明天当焦虑升起时'), findsOneWidget);
    expect(find.textContaining('- 明天当焦虑升起时'), findsNothing);
    expect(find.byKey(const ValueKey('diary_group_ai')), findsOneWidget);
  });
}
