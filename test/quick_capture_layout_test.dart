import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litchi_journal_flutter/models/polish_result.dart';
import 'package:litchi_journal_flutter/models/tag_config.dart';
import 'package:litchi_journal_flutter/screens/quick_capture_screen.dart';
import 'package:litchi_journal_flutter/widgets/entry_type.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';

void main() {
  group('QuickCaptureScreen layout', () {
    testWidgets('时间元信息是可点击的轻量行而不是卡片', (tester) async {
      await tester.pumpWidget(_buildCapture());

      final metadata = find.byKey(const Key('quick_capture_time_metadata'));
      expect(metadata, findsOneWidget);
      expect(tester.getSize(metadata).height, greaterThanOrEqualTo(48));
      expect(
        find.ancestor(of: metadata, matching: find.byType(Card)),
        findsNothing,
      );
      expect(
        find.ancestor(of: metadata, matching: find.byType(ListTile)),
        findsNothing,
      );
    });

    testWidgets('今日新建记录自动聚焦正文', (tester) async {
      await tester.pumpWidget(_buildCapture());
      final newField = tester.widget<TextField>(find.byType(TextField));
      expect(newField.autofocus, isTrue);
      expect(newField.focusNode!.hasFocus, isTrue);
    });

    testWidgets('历史补录不自动聚焦正文', (tester) async {
      await tester.pumpWidget(_buildCapture(recordDate: DateTime(2026, 9, 10)));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isFalse);
      expect(field.focusNode!.hasFocus, isFalse);
    });

    testWidgets('编辑记录不自动聚焦正文', (tester) async {
      await tester.pumpWidget(_buildCapture(initialContent: '已有内容'));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isFalse);
      expect(field.focusNode!.hasFocus, isFalse);
    });

    testWidgets('今天的编辑记录仍显示今天', (tester) async {
      await tester.pumpWidget(
        _buildCapture(recordDate: DateTime.now(), initialContent: '已有内容'),
      );

      expect(find.textContaining('今天'), findsOneWidget);
    });

    testWidgets('正文编辑区占据页面主要空间', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildCapture());

      expect(tester.getSize(find.byType(TextField)).height, greaterThan(300));
    });

    testWidgets('已选标签显示在工具栏上方，标签按钮只有一个展开箭头', (tester) async {
      await tester.pumpWidget(
        _buildCapture(tagConfig: _tagConfig(), initialTags: const ['工作']),
      );

      final tag = find.text('工作');
      final toggle = find.byKey(const Key('quick_capture_tag_toggle'));
      expect(tag, findsOneWidget);
      expect(toggle, findsOneWidget);
      expect(tester.getCenter(tag).dy, lessThan(tester.getCenter(toggle).dy));
      final arrows = find.descendant(
        of: toggle,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is FloraIcon &&
              (widget.name == FloraIcons.chevronDown ||
                  widget.name == FloraIcons.chevronUp),
        ),
      );
      expect(arrows, findsOneWidget);
      expect(tester.widget<FloraIcon>(arrows).name, FloraIcons.chevronDown);
    });

    testWidgets('展开标签前收起正文焦点，折叠后不自动重新聚焦', (tester) async {
      await tester.pumpWidget(_buildCapture(tagConfig: _tagConfig()));

      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pump();
      final focusNode = tester.widget<TextField>(field).focusNode!;
      expect(focusNode.hasFocus, isTrue);

      await tester.tap(find.byKey(const Key('quick_capture_tag_toggle')));
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);

      await tester.tap(find.byKey(const Key('quick_capture_tag_toggle')));
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('窄屏和放大字体下展开标签没有溢出', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _buildCapture(
            tagConfig: _tagConfig(),
            initialTags: const ['工作', '复盘'],
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('quick_capture_tag_toggle')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('领域'), findsOneWidget);
      expect(find.text('主题'), findsOneWidget);
      expect(find.text('方法'), findsOneWidget);
    });

    testWidgets('键盘出现时底部保存按钮保持在键盘上方', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 280)),
          child: _buildCapture(),
        ),
      );

      final save = find.widgetWithText(ElevatedButton, '保存');
      expect(save, findsOneWidget);
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(520));
      expect(
        tester.getRect(find.byType(TextField)).bottom,
        lessThanOrEqualTo(tester.getRect(save).top),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('错误提示使用 bodySmall 且长标签展开时没有布局异常', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _buildCapture(
            tagConfig: _longTagConfig(),
            initialContent: '已有内容',
            initialTags: const ['这是一个很长的工作领域名称'],
            onSave: (_, _, _) async => throw Exception('保存失败'),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('quick_capture_tag_toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '保存'));
      await tester.pumpAndSettle();

      final error = find.text('更新失败，请重试');
      final save = find.widgetWithText(ElevatedButton, '保存');
      expect(error, findsOneWidget);
      final errorText = tester.widget<Text>(error);
      final expectedFontSize = Theme.of(
        tester.element(find.byType(QuickCaptureScreen)),
      ).textTheme.bodySmall?.fontSize;
      expect(errorText.style?.fontSize, expectedFontSize);
      expect(find.text('这是一个很长的工作领域名称'), findsWidgets);
      expect(find.text('领域'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('quick_capture_error'))).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const Key('quick_capture_toolbar'))).bottom,
        ),
      );
      expect(
        tester.getRect(find.byKey(const Key('quick_capture_tag_panel'))).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const Key('quick_capture_error'))).bottom,
        ),
      );
      expect(
        tester.getRect(save).top,
        greaterThanOrEqualTo(
          tester
              .getRect(find.byKey(const Key('quick_capture_tag_panel')))
              .bottom,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('润色缩减标签后再次选择不会带回旧标签', (tester) async {
      List<String>? savedTags;

      await tester.pumpWidget(
        _buildCapture(
          tagConfig: _tagConfig(),
          initialContent: '原始内容',
          initialTags: const ['工作', '复盘', '记录'],
          onPolish: (_, _) async =>
              const PolishResult(content: '润色内容', tags: ['工作']),
          onSave: (_, tags, _) async => savedTags = tags,
        ),
      );

      await tester.tap(find.byKey(const Key('quick_capture_polish')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_capture_tag_toggle')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '复盘'))
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '记录'))
            .selected,
        isFalse,
      );

      await tester.tap(find.text('行动').last);
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedTags, ['工作', '行动']);
    });
  });
}

Widget _buildCapture({
  TagConfig? tagConfig,
  List<String> initialTags = const [],
  DateTime? recordDate,
  String? initialContent,
  Future<PolishResult> Function(String content, EntryType entryType)? onPolish,
  Future<void> Function(String content, List<String> tags, String time)? onSave,
}) {
  return MaterialApp(
    home: QuickCaptureScreen(
      entryType: EntryType.quickNote,
      openedAt: DateTime(2026, 9, 16, 8, 25),
      recordDate: recordDate,
      initialContent: initialContent,
      initialTags: initialTags,
      tagConfig: tagConfig,
      onPolish:
          onPolish ??
          ((_, _) async => const PolishResult(content: '润色后的内容', tags: ['工作'])),
      onSave: onSave ?? (_, _, _) async {},
    ),
  );
}

TagConfig _longTagConfig() {
  return const TagConfig(
    domains: [
      TagDomain(
        id: 'long-work',
        name: '这是一个很长的工作领域名称',
        order: 0,
        topics: [TagTopic(id: 'long-topic', name: '这是一个很长的主题标签名称', order: 0)],
      ),
    ],
    methods: [TagMethod(id: 'long-method', name: '这是一个很长的方法标签名称', order: 0)],
  );
}

TagConfig _tagConfig() {
  return const TagConfig(
    domains: [
      TagDomain(
        id: 'work',
        name: '工作',
        order: 0,
        topics: [
          TagTopic(id: 'review', name: '复盘', order: 0),
          TagTopic(id: 'communication', name: '沟通', order: 1),
        ],
      ),
      TagDomain(
        id: 'life',
        name: '生活',
        order: 1,
        topics: [TagTopic(id: 'family', name: '家庭', order: 0)],
      ),
    ],
    methods: [
      TagMethod(id: 'record', name: '记录', order: 0),
      TagMethod(id: 'action', name: '行动', order: 1),
    ],
  );
}
