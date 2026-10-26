import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/models/default_tag_config.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/screens/home_screen.dart';
import 'package:litchi_journal_flutter/screens/quick_capture_screen.dart';
import 'package:litchi_journal_flutter/screens/read_only_diary_screen.dart';
import 'package:litchi_journal_flutter/screens/settings_page.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/appearance_settings.dart';
import 'package:litchi_journal_flutter/services/markdown_parser.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/theme/diary_reading_style.dart';
import 'package:litchi_journal_flutter/widgets/anxiety_card.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
import 'package:litchi_journal_flutter/widgets/entry_type.dart';
import 'package:litchi_journal_flutter/widgets/entry_photo_grid.dart';
import 'package:litchi_journal_flutter/widgets/generic_section_card.dart';
import 'package:litchi_journal_flutter/widgets/journal_section.dart';
import 'package:litchi_journal_flutter/widgets/tag_picker.dart';
import 'package:litchi_journal_flutter/widgets/tag_color_helper.dart';
import 'package:litchi_journal_flutter/widgets/timeline_action_sheet.dart';

Widget _host(
  Widget child, {
  int size = 18,
  bool dark = false,
  double scale = 1,
  bool screen = false,
}) => MaterialApp(
  theme: DiaryReadingStyle.applyTo(
    dark ? AppTheme.dark : AppTheme.light,
    fontSize: size,
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: screen ? child : Scaffold(body: SingleChildScrollView(child: child)),
);

const _sampleDiary = '''
## ✍️ 随手记 & 灵感
- **09:00** 随手记正文 #生活

## ✨ 每日小确幸
> **09:10** 小确幸正文 #生活

## 🛡️ 焦虑时刻
**发生了什么？**
> 焦虑回答正文

### 💡 觉察与迭代
- **09:20** 觉察正文 #生活

### 🧠 人生教练
模式识别
今日回顾正文

### 🌙 明日寄语
明日寄语正文

## 自定义章节
自定义正文与 **加粗文字**。

- 列表文字

> 引用文字
''';

TextStyle? _textStyle(WidgetTester tester, String text) {
  final widget = tester.widget(find.text(text));
  return switch (widget) {
    Text(:final style) => style,
    SelectableText(:final style) => style,
    EditableText(:final style) => style,
    _ => throw StateError('未覆盖的阅读组件：${widget.runtimeType}'),
  };
}

void main() {
  group('阅读字号配置', () {
    test('默认与旧配置使用 16，并保留原主题', () {
      expect(AppearanceSettings().toJson()['readingFontSize'], 16);
      final restored = AppearanceSettings.fromJson({'themeMode': 'dark'});
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.toJson()['readingFontSize'], 16);
    });

    for (final size in [14, 16, 18]) {
      test('$size 档序列化并在切换主题时保留', () {
        final restored = AppearanceSettings.fromJson({
          'themeMode': 'light',
          'readingFontSize': size,
        });
        final updated = restored.copyWith(themeMode: ThemeMode.dark);
        expect(updated.toJson()['readingFontSize'], size);
        expect(updated.themeMode, ThemeMode.dark);
      });
    }

    test('非法字号回退 16，不影响已有主题', () {
      for (final value in [null, 4, 15, 17, 20, 22, '16', 18.0, 18.5, true]) {
        final restored = AppearanceSettings.fromJson({
          'themeMode': 'dark',
          'readingFontSize': value,
        });
        expect(restored.toJson()['readingFontSize'], 16);
        expect(restored.themeMode, ThemeMode.dark);
      }
    });
  });

  testWidgets('默认正文 16、时间标签 14，不改变全局正文与操作字号', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: JournalTimelineRow(
            time: '17:29',
            content: '日记阅读正文',
            tags: ['#生活'],
            accentColor: TodayRainbow.quickNote,
            tagConfig: null,
            isFirst: true,
            isLast: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('日记阅读正文')).style?.fontSize, 16);
    expect(tester.widget<Text>(find.text('17:29')).style?.fontSize, 14);
    expect(tester.widget<Text>(find.text('#生活')).style?.fontSize, 14);
    final theme = Theme.of(tester.element(find.text('日记阅读正文')));
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
    expect(theme.textTheme.bodyLarge?.fontSize, 16);
  });

  for (final dark in [false, true]) {
    for (final size in [14, 16, 18]) {
      for (final readOnly in [false, true]) {
        testWidgets('阅读组件 dark=$dark／$size／只读=$readOnly 全部使用独立字号', (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(
              DiaryMarkdownView(markdown: _sampleDiary, readOnly: readOnly),
              size: size,
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          for (final text in [
            '随手记正文',
            '小确幸正文',
            '觉察正文',
            '焦虑回答正文',
            '今日回顾正文',
            '明日寄语正文',
          ]) {
            expect(_textStyle(tester, text)?.fontSize, size);
            expect(_textStyle(tester, text)?.height, 1.6);
          }
          for (final title in [
            '随手记',
            '小确幸',
            '觉察',
            '焦虑时刻',
            '今日回顾',
            '明日寄语',
            '自定义章节',
            '模式识别',
          ]) {
            expect(tester.widget<Text>(find.text(title)).style?.fontSize, 18);
          }
          for (final row in [find.byType(JournalTimelineRow)]) {
            for (final element in row.evaluate()) {
              final entry = find.byElementPredicate(
                (candidate) => identical(candidate, element),
              );
              final tags = find.descendant(
                of: entry,
                matching: find.byType(TagChipList),
              );
              final widget = element.widget;
              final text = (widget as JournalTimelineRow).content;
              expect(
                tester.getRect(tags).top -
                    tester.getRect(find.text(text)).bottom,
                closeTo(12, 0.5),
              );
            }
          }
          final markdown = tester.widget<MarkdownBody>(
            find.byType(MarkdownBody).last,
          );
          final styles = markdown.styleSheet!;
          for (final textStyle in [
            styles.p,
            styles.listBullet,
            styles.blockquote,
          ]) {
            expect(textStyle?.fontSize, size);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('自定义章节的 Callout、子标题、checkbox 与时间条目不遗漏', (tester) async {
    await tester.pumpWidget(
      _host(
        const GenericSectionCard(
          section: GenericDiarySection(
            title: '自定义',
            contents: [
              CalloutContent(type: 'note', title: '引用标题', body: ['引用正文']),
              SubSectionContent('内部小标题'),
              CheckboxContent(
                checked: true,
                text: '自定义列表',
                rawLine: '- [x] 自定义列表',
              ),
              TimelineContent(
                time: '12:34',
                text: '自定义时间正文',
                tags: ['#自定义'],
                rawLine: '- **12:34** 自定义时间正文 #自定义',
              ),
            ],
          ),
        ),
        size: 16,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('内部小标题')).style?.fontSize, 18);
    expect(tester.widget<Text>(find.text('自定义列表')).style?.fontSize, 16);
    expect(tester.widget<Text>(find.text('自定义时间正文')).style?.fontSize, 16);
    expect(tester.widget<Text>(find.text('12:34')).style?.fontSize, 14);
    expect(
      tester.getRect(find.byType(TagChipList)).top -
          tester.getRect(find.text('自定义时间正文')).bottom,
      closeTo(12, 0.5),
    );
    final markdown = tester
        .widgetList<MarkdownBody>(find.byType(MarkdownBody))
        .toList();
    expect(markdown[0].styleSheet?.p?.fontSize, 18);
    expect(markdown[1].styleSheet?.p?.fontSize, 16);
  });

  testWidgets('焦虑非问答格式的回退正文同样可切换字号', (tester) async {
    final section =
        const MarkdownParser().parse('## 焦虑时刻\n没有问答结构的旧焦虑正文').sections.single
            as AnxietySection;
    await tester.pumpWidget(_host(AnxietyCard(section: section), size: 16));
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.styleSheet?.p?.fontSize, 16);
    expect(markdown.styleSheet?.p?.height, 1.6);
  });

  test('主题扩展保留 Callout 色与原文字主题，可插值', () {
    final base = AppTheme.dark;
    final result = DiaryReadingStyle.applyTo(base, fontSize: 16);
    expect(
      result.extension<AppCalloutColors>(),
      same(base.extension<AppCalloutColors>()),
    );
    expect(result.textTheme, base.textTheme);
    expect(result.extension<DiaryReadingStyle>()?.fontSize, 16);
    expect(
      const DiaryReadingStyle(
        fontSize: 16,
      ).lerp(const DiaryReadingStyle(fontSize: 18), 0.5).fontSize,
      17,
    );
    expect(
      DiaryReadingStyle.applyTo(result, fontSize: 18).extensions.length,
      result.extensions.length,
    );
  });

  for (final scale in [1.3, 1.6, 2.0]) {
    testWidgets('时间在 $scale 倍系统字体下完整显示为一行', (tester) async {
      await tester.pumpWidget(
        _host(
          const JournalTimelineRow(
            time: '17:29',
            content: '正文',
            tags: [],
            accentColor: Colors.red,
            tagConfig: null,
            isLast: true,
          ),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      final rich = find.descendant(
        of: find.text('17:29'),
        matching: find.byType(RichText),
      );
      final paragraph = tester.renderObject<RenderParagraph>(rich);
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      expect(boxes, hasLength(1));
    });
  }

  for (final size in [14, 16, 18]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$size 档／$scale 倍字体三条时间轴连续，末条随标签结束', (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _host(
            Column(
              children: [
                for (var i = 0; i < 3; i++)
                  JournalTimelineRow(
                    time: ['00:00', '12:30', '23:59'][i],
                    content: '第 $i 条正文。\n\n最后一段。',
                    tags: const ['#第一行标签', '#第二行较长标签'],
                    accentColor: Colors.red,
                    tagConfig: null,
                    isFirst: i == 0,
                    isLast: i == 2,
                  ),
              ],
            ),
            size: size,
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        final rails = find.descendant(
          of: find.byType(JournalTimelineRow),
          matching: find.byType(ColoredBox),
        );
        expect(rails, findsNWidgets(3));
        final first = tester.getRect(rails.at(0));
        final middle = tester.getRect(rails.at(1));
        final last = tester.getRect(rails.at(2));
        expect(first.left, middle.left);
        expect(middle.left, last.left);
        expect(first.bottom, closeTo(middle.top, 0.5));
        expect(middle.bottom, closeTo(last.top, 0.5));
        expect(
          last.bottom,
          closeTo(tester.getRect(find.byType(TagChipList).last).bottom, 0.5),
        );
        expect(tester.takeException(), isNull);
      });
    }
    for (final count in [1, 2, 9]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$size 档／$count 张照片／$scale 倍字体保持网格、间距与末条收尾', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final client = ApiClient(
            ApiConfig(baseUrl: 'https://test.local', token: 'test'),
            httpClient: MockClient((_) async => http.Response('{}', 404)),
          );
          addTearDown(client.dispose);
          await tester.pumpWidget(
            _host(
              JournalTimelineRow(
                time: '23:59',
                content: '第一段正文。\n\n最后一个自然段。',
                tags: const ['#一个较长的标签', '#第二个标签'],
                accentColor: Colors.red,
                tagConfig: null,
                isFirst: true,
                isLast: true,
                attachment: EntryPhotoGrid(
                  photos: List.generate(
                    count,
                    (i) =>
                        DiaryPhoto(filename: '$i.jpg', rawLine: '![[$i.jpg]]'),
                  ),
                  uploads: const [],
                  removedPhotoNames: const {},
                  apiClient: client,
                  date: DateTime(2026, 10, 18),
                ),
              ),
              size: size,
              dark: scale == 2,
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          final grid = tester.getRect(find.byType(EntryPhotoGrid));
          final contentWidth = tester
              .getSize(
                find
                    .ancestor(
                      of: find.byType(EntryPhotoGrid),
                      matching: find.byType(Column),
                    )
                    .first,
              )
              .width;
          final tags = tester.getRect(find.byType(TagChipList));
          final tile = tester.getRect(
            find.byKey(const ValueKey('entry_photo_0.jpg')),
          );
          expect(tile.width, closeTo((contentWidth - 16) / 3, 0.1));
          expect(tile.height, closeTo(tile.width, 0.1));
          expect(tags.top - grid.bottom, closeTo(12, 0.1));
          final rail = find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox &&
                widget.color == Colors.red.withAlpha(88),
          );
          expect(rail, findsOneWidget);
          expect(tester.getRect(rail).bottom, closeTo(tags.bottom, 0.5));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final dark in [false, true]) {
    for (final scale in [1.3, 1.6, 2.0]) {
      testWidgets('设置与确认菜单 dark=$dark／320dp／$scale 倍字体完整可操作', (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final client = ApiClient(
          ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        );
        addTearDown(client.dispose);
        await tester.pumpWidget(
          _host(
            SettingsPage(
              apiConfig: ApiConfig(
                baseUrl: 'https://test.local',
                token: 'test',
              ),
              apiClient: client,
            ),
            dark: dark,
            scale: scale,
            screen: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const ValueKey('settings-item-外观'))).height,
          greaterThanOrEqualTo(56),
        );
        expect(tester.widget<Text>(find.text('外观')).style?.fontSize, 16);
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('确认删除'),
                    content: const Text('同时删除关联的 2 张照片，确定继续吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                ),
                child: const Text('打开确认'),
              ),
            ),
            dark: dark,
            scale: scale,
          ),
        );
        await tester.tap(find.text('打开确认'));
        await tester.pumpAndSettle();
        final content = tester.widget<DefaultTextStyle>(
          find
              .ancestor(
                of: find.text('同时删除关联的 2 张照片，确定继续吗？'),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        );
        expect(content.style.fontSize, 16);
        final theme = Theme.of(tester.element(find.text('确认删除')));
        expect(theme.dialogTheme.titleTextStyle?.fontSize, 18);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('确认删除'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('三档阅读字号均不影响输入、标签选择与操作菜单', (tester) async {
    for (final size in [14, 16, 18]) {
      await tester.pumpWidget(
        _host(
          QuickCaptureScreen(
            entryType: EntryType.quickNote,
            openedAt: DateTime(2026, 10, 18),
            initialContent: '输入正文保持不变',
            tagConfig: DefaultTagConfig.value,
            onSave: (_) async {},
          ),
          size: size,
          screen: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).style?.fontSize,
        16,
      );
      await tester.tap(find.text('标签'));
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(find.byType(TagPicker)));
      expect(theme.textTheme.bodySmall?.fontSize, 12);
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showTimelineActionSheet(
                context,
                showEdit: true,
                showDelete: true,
              ),
              child: const Text('打开菜单'),
            ),
          ),
          size: size,
        ),
      );
      await tester.tap(find.text('打开菜单'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('编辑')).style?.fontSize, 16);
      expect(tester.widget<Text>(find.text('删除')).style?.fontSize, 16);
      final menuContext = tester.element(find.text('编辑'));
      Navigator.of(menuContext).pop();
      await tester.pumpAndSettle();
    }
  });

  for (final historical in [false, true]) {
    testWidgets('${historical ? '历史详情' : '今天页'} 切换字号不请求数据也不跳顶', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      var requests = 0;
      final raw =
          '## ✍️ 随手记 & 灵感\n${List.generate(30, (index) => '- **09:00** 记录$index：足够长的正文用于检验滚动位置。 #生活').join('\n')}';
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: MockClient((request) async {
          requests++;
          if (request.url.path.startsWith('/api/v1/diary/')) {
            return http.Response(
              jsonEncode({
                'date': '2026-10-17',
                'title': '',
                'raw': raw,
                'sections': {},
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{}', 500);
        }),
      );
      addTearDown(client.dispose);
      final size = ValueNotifier(18);
      addTearDown(size.dispose);
      final screen = historical
          ? ReadOnlyDiaryScreen(date: DateTime(2026, 10, 17), apiClient: client)
          : HomeScreen(apiClient: client);
      await tester.pumpWidget(
        ValueListenableBuilder<int>(
          valueListenable: size,
          child: screen,
          builder: (_, size, child) => MaterialApp(
            theme: DiaryReadingStyle.applyTo(AppTheme.light, fontSize: size),
            home: child,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -350));
      await tester.pumpAndSettle();
      final state = tester.state<ScrollableState>(scrollable);
      final offset = state.position.pixels;
      expect(offset, greaterThan(0));
      final initialRequests = requests;
      size.value = 16;
      await tester.pumpAndSettle();
      expect(requests, initialRequests);
      expect(tester.state<ScrollableState>(scrollable), same(state));
      expect(state.position.pixels, closeTo(offset, 0.1));
      expect(
        tester.widget<Text>(find.text('记录0：足够长的正文用于检验滚动位置。')).style?.fontSize,
        16,
      );
    });
  }
}
