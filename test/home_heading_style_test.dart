import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('主页标题统一，生活记录复用随手记图标 dark=$dark scale=$scale', (tester) async {
        tester.view.physicalSize = const Size(320, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        Future<void> show(String content) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 1200),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: DiaryMarkdownView(
                      markdown: '## 习惯打卡\n- [ ] 补充剂\n$content',
                      showTodayPlaceholders: true,
                      onHabitUpdate: (_) async => true,
                      onOpenQuickRecord: () {
                        opened++;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        void checkTitle(String title) {
          final style = tester.widget<Text>(find.text(title)).style!;
          expect(style.fontSize, 18, reason: title);
          expect(style.fontWeight, FontWeight.w600, reason: title);
          expect(style.height, 1.35, reason: title);
        }

        await show('');
        checkTitle('习惯打卡');
        checkTitle('生活记录');
        final iconFinder = find.byWidgetPredicate(
          (w) => w is FloraIcon && w.name == FloraIcons.fabWrite,
        );
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<FloraIcon>(iconFinder);
        expect(icon.size, 20);
        expect(icon.color, TodayRainbow.quickNote);
        await tester.ensureVisible(find.text('生活记录'));
        await tester.tap(find.text('生活记录'));
        expect(opened, 1);
        expect(tester.takeException(), isNull);
        await show(
          '## 随手记\n- **08:00** 今天的一件小事\n\n## 小确幸\n- **09:00** 阳光很好\n\n### 觉察\n- **10:00** 慢慢来\n\n### 人生教练\n继续前行。\n\n### 明日寄语\n明天见。',
        );
        expect(find.text('生活记录'), findsNothing);
        for (final title in ['习惯打卡', '随手记', '小确幸', '觉察', '今日回顾', '明日寄语']) {
          checkTitle(title);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
