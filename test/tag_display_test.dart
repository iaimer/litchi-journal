import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/screens/settings_page.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/tag_color_helper.dart';

void main() {
  testWidgets('settings distinguish image and local cache icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          primary: true,
          apiConfig: ApiConfig(baseUrl: 'https://test.invalid', token: 'test'),
        ),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-item-本地缓存')),
    );
    await tester.pumpAndSettle();
    final image = tester.widget<FloraIcon>(
      find
          .descendant(
            of: find.byKey(const ValueKey('settings-item-图片设置')),
            matching: find.byType(FloraIcon),
          )
          .first,
    );
    final cache = tester.widget<FloraIcon>(
      find
          .descendant(
            of: find.byKey(const ValueKey('settings-item-本地缓存')),
            matching: find.byType(FloraIcon),
          )
          .first,
    );
    expect(image.name, FloraIcons.settingImage);
    expect(FloraIcons.path(cache.name), 'assets/icons/lucide/hard-drive.svg');
    expect(cache.size, 22);
    expect(cache.name, isNot(image.name));
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.3, 1.6, 2.0, 2.5, 3.0, 4.0]) {
        testWidgets('tag display width=$width dark=$dark scale=$scale', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final semantics = tester.ensureSemantics();
          const original = ['#生活', '无前缀', '#生活/日常#片段', '#非常非常非常长的标签仍应保留完整语义'];
          const labels = ['生活', '无前缀', '生活/日常#片段', '非常非常非常长的标签仍应保留完整语义'];
          final theme = dark ? AppTheme.dark : AppTheme.light;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  boldText: scale >= 3,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TagChipList(
                    tags: original,
                    tagConfig: null,
                    singleLine: true,
                    moduleAccentColor: TodayRainbow.quickNote,
                  ),
                ),
              ),
            ),
          );
          for (final label in labels) {
            expect(find.text(label), findsOneWidget);
            expect(find.bySemanticsLabel(label), findsOneWidget);
            expect(tester.widget<Text>(find.text(label)).maxLines, 1);
          }
          expect(find.text('#生活'), findsNothing);
          expect(
            tester.widget<TagChipList>(find.byType(TagChipList)).tags,
            same(original),
          );
          final context = tester.element(find.byType(TagChipList));
          expect(
            readingTagWidth(context, original, 12),
            closeTo(readingTagWidth(context, labels, 12), .001),
          );
          expect(
            readingTagFontSize(context, original, width - 32),
            closeTo(readingTagFontSize(context, labels, width - 32), .001),
          );
          final last = tester.widget<Text>(find.text(labels.last));
          expect(last.overflow, TextOverflow.ellipsis);
          semantics.dispose();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
