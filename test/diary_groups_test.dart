import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';

Future<void> mount(WidgetTester tester, String raw, {bool today = true}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiaryMarkdownView(
            markdown: raw,
            readOnly: !today,
            showTodayPlaceholders: today,
            onHabitUpdate: today ? (_) async => true : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('只有关联照片不创建独立影像空容器，旧独立图仍显示', (tester) async {
    const raw =
        '## 随手记\n- **12:00** 一张照片\n<!-- litchi-entry-id:11111111-1111-4111-8111-111111111111 -->\n### 影像记录\n![[attached.jpg]]\n<!-- litchi-photo-of:11111111-1111-4111-8111-111111111111;op:22222222-2222-4222-8222-222222222222 -->\n';
    final client = ApiClient(
      ApiConfig(baseUrl: 'http://example.invalid', token: 'test'),
      httpClient: MockClient((_) async => http.Response('', 404)),
    );
    addTearDown(client.dispose);
    Future<void> show(String text) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DiaryMarkdownView(
                markdown: text,
                apiClient: client,
                date: DateTime(2026, 10, 30),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(raw);
    expect(find.byKey(const ValueKey('diary_group_personal')), findsOneWidget);
    expect(find.byKey(const ValueKey('diary_group_media')), findsNothing);
    await show('$raw\n![[legacy.jpg]]\n');
    expect(find.byKey(const ValueKey('diary_group_media')), findsOneWidget);
    expect(find.text('影像记录'), findsOneWidget);
  });

  testWidgets('首次生成立即显示向下展开中的回顾加载区域', (tester) async {
    var generating = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return DiaryMarkdownView(
                  markdown: '## 随手记\n- **12:00** 记录\n',
                  showTodayPlaceholders: true,
                  generatingCoach: generating,
                  onGenerateCoach: () {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => generating = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('正在生成今日回顾…'), findsOneWidget);
    final during = tester
        .getSize(find.byKey(const ValueKey('coach_reveal')))
        .height;
    await tester.pump(const Duration(milliseconds: 240));
    expect(
      tester.getSize(find.byKey(const ValueKey('coach_reveal'))).height,
      greaterThan(during),
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final reduced in [false, true]) {
    testWidgets('只有寄语时生成也展示回顾状态并推动旧影像 reduced=$reduced', (tester) async {
      var generating = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return DiaryMarkdownView(
                      markdown: '### 明日寄语\n明天继续\n### 影像记录\n![[old.jpg]]\n',
                      showTodayPlaceholders: true,
                      generatingCoach: generating,
                      onGenerateCoach: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final media = find.byKey(const ValueKey('diary_group_media'));
      final before = tester.getTopLeft(media).dy;
      update(() => generating = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('正在生成今日回顾…'), findsOneWidget);
      expect(tester.getTopLeft(media).dy, greaterThan(before));
      final during = tester.getTopLeft(media).dy;
      await tester.pump(const Duration(milliseconds: 260));
      if (reduced) {
        expect(tester.getTopLeft(media).dy, during);
      } else {
        expect(tester.getTopLeft(media).dy, greaterThan(during));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('仅习惯仍显示紧凑生活记录引导，没有影像空框', (tester) async {
    await mount(tester, '## 习惯打卡\n- [x] 阅读\n');
    expect(find.text('生活记录'), findsOneWidget);
    expect(find.textContaining('今天发生了什么'), findsOneWidget);
    expect(find.byKey(const ValueKey('diary_group_media')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('diary_group_personal'))).height,
      lessThan(240),
    );
  });
  testWidgets('三类记录共用背景而无水平分隔线', (tester) async {
    await mount(
      tester,
      '## 随手记\n- **12:00** 记录\n## 小确幸\n- **13:00** 开心\n## 觉察\n- **14:00** 觉察正文\n',
    );
    final group = find.byKey(const ValueKey('diary_group_personal'));
    expect(group, findsOneWidget);
    for (final title in ['随手记', '小确幸', '觉察']) {
      expect(
        find.descendant(of: group, matching: find.text(title)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: group, matching: find.byType(Divider)),
      findsNothing,
    );
    expect(find.textContaining('今天发生了什么'), findsNothing);
  });
  testWidgets('历史空记录无占位，有回顾显示分组', (tester) async {
    await mount(tester, '### 人生教练\n今天很好\n', today: false);
    expect(find.byKey(const ValueKey('diary_group_ai')), findsOneWidget);
    expect(find.textContaining('今天发生了什么'), findsNothing);
  });
}
