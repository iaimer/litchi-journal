import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/services/markdown_parser.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/habit_card.dart';

const _habits = '''
# 今天

## 习惯打卡
- [x] 阅读/亲子共读
- 饮水 750 mL
''';

// 与服务端 createObsidianDiaryContent 的模板结构一致，不访问真实日记。
const _serverTemplate = '''
---
tags:
  - 日记
---

# 🌿 星期日 · 此时此刻
> [!quote] 2026 年，如果只选一件事：**让健康和记录成为习惯。**

---
## 🏃 习惯打卡
- 🥛饮水 0 mL
- 🧘 运动/拉伸/快走 0 步
- [ ] 📖 阅读/亲子共读 0 分钟
- [ ] 🇬🇧 学语言 0 分钟
- [ ] 💊 鱼油/植物甾醇

---
## ✍️ 随手记 & 灵感
<!-- 随手记和灵感，文案喵会自动添加合适的标签 -->
- **HH:MM** 内容 #标签

---
## ✨ 每日小确幸
> [!success] 总有事件值得感恩🙏♥️
>

---
## 😰 焦虑时刻
- 今天什么时候我感到焦虑/紧张？
>
- 当时我在担心什么？（具体到一句话)
>
- 我做了什么？
>
- 这个应对是帮我面对了，还是帮我躲开了？
>

---
## 📈 每日复盘
### 💡 觉察与迭代
<!-- 这里是你的观点和思考，荔枝喵会重点提取 -->
-

### 🧠 人生教练
<!-- 基于当天日记的客观反馈：模式识别、矛盾指出、批判性问题 -->
-

### 🌙 明日寄语
-

---
## 📸 影像记录
''';

Future<void> _mount(
  WidgetTester tester,
  String markdown, {
  VoidCallback? onGenerate,
  bool readOnly = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiaryMarkdownView(
            markdown: markdown,
            onHabitUpdate: (_) async => true,
            onGenerateCoach: onGenerate ?? () {},
            readOnly: readOnly,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final prefix in ['-', '>']) {
    test('Parser 排除 $prefix HH:MM 模板示例但保留实际时间记录', () {
      final document = const MarkdownParser().parse('''
## 随手记
$prefix **HH:MM** 内容 #标签
$prefix **08:25** 我的真实记录 #生活
''');
      final section = document.sections.single as QuickNoteSection;
      expect(section.contents, hasLength(1));
      expect(section.notes.single.content, '我的真实记录');
      expect(section.notes.single.rawLine, '$prefix **08:25** 我的真实记录 #生活');
    });
  }

  test('Parser 不丢弃使用 HH:MM 但已改写的正文', () {
    final document = const MarkdownParser().parse(
      '## 随手记\n- **HH:MM** 我写下的内容 #生活\n',
    );
    expect(document.sections.single.isEmpty, isFalse);
    expect(
      (document.sections.single.contents.single as MarkdownContent).text,
      '- **HH:MM** 我写下的内容 #生活',
    );
  });

  testWidgets('仅有习惯时不补出今日回顾模块', (tester) async {
    await _mount(tester, _habits);
    expect(find.byType(HabitCard), findsOneWidget);
    expect(find.text('今日回顾'), findsNothing);
    expect(find.text('生成回顾'), findsNothing);
  });

  for (final title in ['人生教练', '荔枝喵说']) {
    testWidgets('仅有习惯和空的 $title 时隐藏今日回顾', (tester) async {
      await _mount(tester, '$_habits\n### $title\n-\n');
      expect(find.byType(HabitCard), findsOneWidget);
      expect(find.text('今日回顾'), findsNothing);
      expect(find.text('生成回顾'), findsNothing);
    });
  }

  testWidgets('未填写的模板不让仅有习惯的日记显示回顾', (tester) async {
    await _mount(tester, '''
$_habits
## 随手记
-
## 小确幸
-
## 焦虑时刻
- 今天什么时候我感到焦虑/紧张？
>
- 当时我在担心什么？（具体到一句话）
>
## 觉察
-
### 人生教练
-
### 明日寄语
-
### 影像记录
<!-- 空模板 -->
''');
    expect(find.text('今日回顾'), findsNothing);
  });

  testWidgets('只有默认习惯卡时也隐藏今日回顾', (tester) async {
    await _mount(tester, '# 今天\n');
    expect(find.byType(HabitCard), findsOneWidget);
    expect(find.text('今日回顾'), findsNothing);
  });

  testWidgets('服务端完整空模板和习惯更新均不显示今日回顾', (tester) async {
    await _mount(tester, _serverTemplate);
    expect(find.byType(HabitCard), findsOneWidget);
    expect(find.text('今日回顾'), findsNothing);
    expect(find.text('生成回顾'), findsNothing);

    await _mount(tester, _serverTemplate.replaceFirst('饮水 0 mL', '饮水 1000 mL'));
    expect(find.text('今日回顾'), findsNothing);
  });

  testWidgets('完整模板新增正文后显示回顾，移除后再次隐藏', (tester) async {
    await _mount(
      tester,
      _serverTemplate.replaceFirst(
        '- **HH:MM** 内容 #标签',
        '- **08:25** 今天写下的内容 #生活',
      ),
    );
    expect(find.text('今日回顾'), findsOneWidget);
    expect(find.text('生成回顾'), findsOneWidget);
    await _mount(tester, _serverTemplate);
    expect(find.text('今日回顾'), findsNothing);
  });

  testWidgets('HH:MM 示例不是随手记正文，不恢复生成回顾', (tester) async {
    await _mount(tester, '$_habits\n## 随手记\n- **HH:MM** 内容 #标签\n');
    expect(find.text('今日回顾'), findsNothing);
    expect(find.text('生成回顾'), findsNothing);
  });

  testWidgets('未填写的完整焦虑四问不恢复生成回顾', (tester) async {
    await _mount(tester, '''
$_habits
## 焦虑时刻
- 今天什么时候我感到焦虑/紧张？
>
- 当时我在担心什么？（具体到一句话)
>
- 我做了什么？
>
- 这个应对是帮我面对了，还是帮我躲开了？
>
''');
    expect(find.text('今日回顾'), findsNothing);
  });

  const entries = {
    '随手记': '- **08:25** 今天写下一件事',
    '小确幸': '- **08:25** 午后的阳光很舒服',
    '觉察': '- **08:25** 我发现自己需要休息',
    '焦虑时刻': '- 今天什么时候我感到焦虑/紧张？\n> 开会前',
    '影像记录': '![[assets/test-photo.jpg]]',
    '自己的栏目': '今天值得记住的事',
  };
  for (final entry in entries.entries) {
    testWidgets('习惯之外有${entry.key}内容时保留生成回顾', (tester) async {
      var generated = false;
      await _mount(
        tester,
        '$_habits\n## ${entry.key}\n${entry.value}\n',
        onGenerate: () => generated = true,
      );
      expect(find.text('今日回顾'), findsOneWidget);
      await tester.ensureVisible(find.text('生成回顾'));
      await tester.tap(find.text('生成回顾'));
      expect(generated, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('标题前有正文时不误判为仅有习惯', (tester) async {
    await _mount(tester, _habits.replaceFirst('# 今天', '# 今天\n今天过得不错'));
    expect(find.text('今日回顾'), findsOneWidget);
  });

  testWidgets('已有回顾不会因为没有其他文字记录而被隐藏', (tester) async {
    await _mount(tester, '$_habits\n### 人生教练\n今天保持了阅读的节奏。\n');
    expect(find.text('今日回顾'), findsOneWidget);
    expect(find.text('今天保持了阅读的节奏。'), findsOneWidget);
    expect(find.text('更新回顾'), findsOneWidget);
  });

  testWidgets('新增和移除最后一条正文时同步更新回顾可见性', (tester) async {
    await _mount(tester, _habits);
    expect(find.text('今日回顾'), findsNothing);
    await _mount(tester, '$_habits\n## 随手记\n- **08:25** 今天的记录\n');
    expect(find.text('生成回顾'), findsOneWidget);
    await _mount(tester, _habits);
    expect(find.text('今日回顾'), findsNothing);
  });

  testWidgets('历史只读页继续保留已保存的回顾且隐藏操作', (tester) async {
    await _mount(tester, '$_habits\n### 人生教练\n过去的回顾内容\n', readOnly: true);
    expect(find.text('今日回顾'), findsOneWidget);
    expect(find.text('过去的回顾内容'), findsOneWidget);
    expect(find.text('更新回顾'), findsNothing);
    expect(find.text('生成回顾'), findsNothing);
  });
}
