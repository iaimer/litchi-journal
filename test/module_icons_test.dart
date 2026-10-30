import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/models/habit_settings.dart';
import 'package:litchi_journal_flutter/services/markdown_parser.dart';
import 'package:litchi_journal_flutter/widgets/habit_card.dart';
import 'package:litchi_journal_flutter/widgets/habit_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/journal_section.dart';

void main() {
  for (final readOnly in [false, true]) {
    for (final checked in [false, true]) {
      testWidgets('默认与自定义习惯图标跟随配置颜色 checked=$checked readOnly=$readOnly', (
        tester,
      ) async {
        final mark = checked ? 'x' : ' ';
        final section = const MarkdownParser()
            .parse(
              '## 习惯打卡\n- 饮水 250 mL\n- 运动 1000 步\n- [$mark] 阅读/亲子共读 10 分钟\n- [$mark] 学语言 5 分钟\n- [$mark] 补充剂\n- [$mark] 冥想',
            )
            .sections
            .whereType<HabitSection>()
            .single;
        const settings = HabitSettings(
          statusMap: {
            'water': true,
            'steps': true,
            'reading': true,
            'language': true,
            'supplements': true,
            'custom_calm': true,
          },
          extraHabits: {'custom_calm': '冥想'},
          iconMap: {'custom_calm': 'candidate-meditate'},
          colorMap: {'supplements': 0xFFAA5577, 'custom_calm': 0xFF338899},
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: HabitCard(
                section: section,
                readOnly: readOnly,
                habitSettings: settings,
                activeHabitKeys: settings.activeKeys.toSet(),
                onUpdate: (_) async => true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final entry in <String, Color>{
          'habit-water': const Color(0xFF6BAED6),
          'habit-walk': const Color(0xFF7BA67A),
          'habit-read': const Color(0xFF6B8E6B),
          'habit-language': const Color(0xFF9B8EC4),
          'habit-pill': const Color(0xFFAA5577),
          'candidate-meditate': const Color(0xFF338899),
        }.entries) {
          final icon = tester.widget<HabitIcon>(
            find.byWidgetPredicate(
              (w) => w is HabitIcon && w.icon == entry.key,
            ),
          );
          expect(icon.color, entry.value, reason: entry.key);
        }
        final titleIcon = find.byWidgetPredicate(
          (w) => w is FloraIcon && w.name == FloraIcons.settingHabits,
        );
        expect(titleIcon, findsOneWidget);
      });
    }
  }

  testWidgets('模块标题用对应颜色的图标替代竖线', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: DiaryMarkdownView(
              markdown:
                  '## 随手记\n- **08:25** 随手记录\n\n### 觉察\n- **09:00** 看见情绪\n\n## 小确幸\n- **12:00** 阳光很好\n\n### 人生教练\n今天看见了自己的进步。\n\n### 明日寄语\n明天慢慢进步。',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final entry in <String, Color>{
      '今日回顾': const Color(0xFF85ACD8),
      '随手记': const Color(0xFFF08F8F),
      '觉察': const Color(0xFF8DB993),
      '小确幸': const Color(0xFFF0B36F),
      '明日寄语': const Color(0xFFAC98CD),
    }.entries) {
      final section = find.ancestor(
        of: find.text(entry.key),
        matching: find.byType(JournalSection),
      );
      expect(section, findsOneWidget);
      final icons = find.descendant(
        of: section,
        matching: find.byType(FloraIcon),
      );
      expect(icons, findsOneWidget, reason: entry.key);
      final icon = tester.widget<FloraIcon>(icons);
      expect(icon.color, entry.value);
      expect(icon.size, 20);
      final expectedPath = switch (entry.key) {
        '随手记' => 'assets/icons/lucide/pen-line.svg',
        '觉察' => 'assets/icons/custom/brain-side.svg',
        '小确幸' => 'assets/icons/lucide/heart.svg',
        '今日回顾' => 'assets/icons/lucide/clipboard-check.svg',
        _ => 'assets/icons/lucide/sprout.svg',
      };
      expect(FloraIcons.path(icon.name), expectedPath);
      expect(
        find.descendant(
          of: section,
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 4 && w.height == 20,
          ),
        ),
        findsNothing,
      );
    }
  });
}
