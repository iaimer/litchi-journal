import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/models/default_tag_config.dart';
import 'package:litchi_journal_flutter/models/polish_result.dart';
import 'package:litchi_journal_flutter/models/quick_capture_submission.dart';
import 'package:litchi_journal_flutter/screens/quick_capture_screen.dart';
import 'package:litchi_journal_flutter/services/draft_repository.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/entry_type.dart';
import 'package:litchi_journal_flutter/widgets/tag_picker.dart';

const _writePreview = bool.fromEnvironment('WRITE_REFLECTION_PREVIEW');
const _previewFontPath = String.fromEnvironment('REFLECTION_PREVIEW_FONT');
const _previewKey = ValueKey('reflection_preview');
const _questions = '发生了什么？\n当时我在想什么、在意什么？\n现在有什么需要？';
const _quickNoteHint = '有什么想记下来的？\n一句话也可以。';
const _happinessHint = '有什么让你开心的小事？\n记下那个瞬间就好。';

ThemeData _theme(bool dark) {
  final theme = dark ? AppTheme.dark : AppTheme.light;
  if (!_writePreview) return theme;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'ReflectionPreview'),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'ReflectionPreview',
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _previewButton(theme.textButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _previewButton(theme.elevatedButtonTheme.style),
    ),
  );
}

ButtonStyle _previewButton(ButtonStyle? style) =>
    (style ?? const ButtonStyle()).copyWith(
      textStyle: WidgetStateProperty.resolveWith(
        (states) => (style?.textStyle?.resolve(states) ?? const TextStyle())
            .copyWith(fontFamily: 'ReflectionPreview'),
      ),
    );

Widget _host({
  String? content,
  DateTime? date,
  EntryType type = EntryType.reflection,
  double scale = 1,
  bool dark = false,
  bool highContrast = false,
  List<String> tags = const [],
  ValueChanged<QuickCaptureSubmission>? onSave,
  DraftRepository? drafts,
  Future<PolishResult> Function(String, EntryType)? onPolish,
}) => MaterialApp(
  theme: _theme(dark),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      highContrast: highContrast,
    ),
    child: child!,
  ),
  home: RepaintBoundary(
    key: _previewKey,
    child: QuickCaptureScreen(
      entryType: type,
      openedAt: DateTime(2026, 10, 25, 12),
      recordDate: date,
      initialContent: content,
      initialTags: tags,
      draftRepository: drafts,
      tagConfig: DefaultTagConfig.value,
      onPolish: onPolish,
      onSave: (submission) async => onSave?.call(submission),
    ),
  ),
);

final _editor = find.byKey(const ValueKey('quick_capture_editor'));

void main() {
  testWidgets('空白觉察直接显示小号三问，不再提供展开入口', (tester) async {
    await tester.pumpWidget(_host());
    final field = tester.widget<TextField>(_editor);
    expect(field.controller!.text, isEmpty);
    expect(field.decoration!.hintText, _questions);
    expect(field.decoration!.maintainHintSize, isFalse);
    expect(field.decoration!.hintFadeDuration, Duration.zero);
    expect(find.text(_questions), findsOneWidget);
    expect(find.text('给点提示'), findsNothing);
    expect(find.byKey(const Key('reflection_guidance')), findsNothing);
    expect(find.text('挑一个想想就好，也可以直接写'), findsNothing);
  });

  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      testWidgets('提示字号与主题颜色 dark=$dark highContrast=$highContrast', (
        tester,
      ) async {
        await tester.pumpWidget(_host(dark: dark, highContrast: highContrast));
        final field = tester.widget<TextField>(_editor);
        final hint = tester.widget<Text>(find.text(_questions));
        final baseColor = _theme(dark).colorScheme.onSurfaceVariant;
        final alpha = highContrast ? 1.0 : (dark ? 0.65 : 0.5);
        expect(hint.style!.fontSize, 13);
        expect(hint.style!.fontWeight, FontWeight.w400);
        expect(hint.style!.height, 1.7);
        expect(hint.style!.color, baseColor.withValues(alpha: alpha));
        expect(hint.maxLines, isNull);
        expect(hint.overflow, isNot(TextOverflow.ellipsis));
        expect(field.style!.fontSize, 16);
        expect(field.style!.height, 1.6);
      });
    }
  }

  for (final mode in ['new', 'edit', 'historical']) {
    testWidgets('$mode 输入和清空切换提示，不替换编辑器或打断输入法', (tester) async {
      await tester.pumpWidget(
        _host(
          content: mode == 'edit' ? '已有觉察' : null,
          date: mode == 'historical' ? DateTime(2026, 10, 24) : null,
        ),
      );
      expect(
        find.text(_questions),
        mode == 'edit' ? findsNothing : findsOneWidget,
      );
      await tester.showKeyboard(_editor);
      final element = tester.element(_editor);
      final field = tester.widget<TextField>(_editor);
      const composing = TextEditingValue(
        text: '有点紧张，还没想明白',
        selection: TextSelection(baseOffset: 1, extentOffset: 4),
        composing: TextRange(start: 1, end: 4),
      );
      const cleared = TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
      for (final value in [cleared, composing, cleared]) {
        tester.testTextInput.updateEditingValue(value);
        await tester.pump();
        final current = tester.widget<TextField>(_editor);
        expect(identical(tester.element(_editor), element), isTrue);
        expect(identical(current.controller, field.controller), isTrue);
        expect(identical(current.focusNode, field.focusNode), isTrue);
        expect(current.controller!.value, value);
        expect(current.focusNode!.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(
          find.text(_questions),
          value.text.isEmpty ? findsOneWidget : findsNothing,
        );
      }
    });
  }

  testWidgets('空格和换行隐藏提示，但不能保存；清空立即恢复', (tester) async {
    await tester.pumpWidget(_host());
    for (final text in [' ', '\n', ' \n ']) {
      await tester.enterText(_editor, text);
      await tester.pump();
      expect(find.text(_questions), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    }
    await tester.enterText(_editor, '');
    await tester.pump();
    expect(find.text(_questions), findsOneWidget);
  });

  testWidgets('空白提示不会启用保存、润色或触发离开确认', (tester) async {
    await tester.pumpWidget(_host());
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('quick_capture_polish')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(QuickCaptureScreen), findsNothing);
  });

  testWidgets('保存只提交用户正文，不提交三问', (tester) async {
    QuickCaptureSubmission? saved;
    await tester.pumpWidget(_host(onSave: (submission) => saved = submission));
    await tester.enterText(_editor, '只写一句也可以');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved!.content, '只写一句也可以');
    expect(saved!.time, '12:00');
    expect(saved!.tags, isEmpty);
  });

  testWidgets('提示不产生草稿和请求，草稿与润色只包含用户正文', (tester) async {
    final storage = _DraftStorage();
    storage.values['draft_2026-10-24_anxiety'] = 'legacy';
    final polished = <String>[];
    await tester.pumpWidget(
      _host(
        date: DateTime(2026, 10, 24),
        drafts: DraftRepository(storage: storage),
        onPolish: (content, type) async {
          polished.add(content);
          expect(type, EntryType.reflection);
          return PolishResult(content: content, tags: const ['生活', '情绪感受']);
        },
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(storage.writes, 0);
    expect(polished, isEmpty);
    expect(storage.values, {'draft_2026-10-24_anxiety': 'legacy'});
    await tester.enterText(_editor, '还没有想明白');
    await tester.pump(const Duration(milliseconds: 400));
    final draft = storage.values['draft_2026-10-24_reflection']!;
    expect(draft, contains('还没有想明白'));
    expect(draft, isNot(contains('发生了什么')));
    await tester.tap(find.byKey(const Key('quick_capture_polish')));
    await tester.pumpAndSettle();
    expect(polished, ['还没有想明白']);
    expect(storage.values['draft_2026-10-24_anxiety'], 'legacy');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('恢复草稿直接显示正文，清空后重新显示三问', (tester) async {
    final storage = _DraftStorage();
    final drafts = DraftRepository(
      storage: storage,
      now: () => DateTime(2026, 10, 26, 12),
    );
    await drafts.saveQuickDraft(
      date: DateTime(2026, 10, 24),
      entryType: EntryType.reflection,
      content: '尚未提交的觉察',
      tags: const ['生活'],
    );
    await tester.pumpWidget(
      _host(date: DateTime(2026, 10, 24), drafts: drafts),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_editor).controller!.text, '尚未提交的觉察');
    expect(find.text(_questions), findsNothing);
    await tester.enterText(_editor, '');
    await tester.pump();
    expect(find.text(_questions), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('输入后不保留三问高度，正文到已选标签仍为12dp', (tester) async {
    await tester.pumpWidget(_host(tags: const ['生活']));
    final emptyHeight = tester.getSize(_editor).height;
    await tester.enterText(_editor, '先停下来');
    await tester.pump();
    expect(tester.getSize(_editor).height, lessThan(emptyHeight));
    final tags = tester.getRect(find.byType(TagSelectionSummary));
    expect(tags.top - tester.getRect(_editor).bottom, closeTo(12, 0.1));
    final filledHeight = tester.getSize(_editor).height;
    await tester.enterText(_editor, '先停下来\n看看自己在意什么\n慢慢写');
    await tester.pump();
    expect(tester.getSize(_editor).height, greaterThan(filledHeight));
  });

  for (final (type, copy) in [
    (EntryType.quickNote, _quickNoteHint),
    (EntryType.happiness, _happinessHint),
  ]) {
    for (final dark in [false, true]) {
      for (final highContrast in [false, true]) {
        testWidgets(
          '${type.name} 空白提示与觉察同样轻巧 dark=$dark highContrast=$highContrast',
          (tester) async {
            await tester.pumpWidget(
              _host(type: type, dark: dark, highContrast: highContrast),
            );
            final field = tester.widget<TextField>(_editor);
            final hint = tester.widget<Text>(find.text(copy));
            final color = _theme(dark).colorScheme.onSurfaceVariant;
            final alpha = highContrast ? 1.0 : (dark ? 0.65 : 0.5);
            expect(field.controller!.text, isEmpty);
            expect(field.decoration!.hintText, copy);
            expect(field.decoration!.maintainHintSize, isFalse);
            expect(field.decoration!.hintFadeDuration, Duration.zero);
            expect(hint.style!.fontSize, 13);
            expect(hint.style!.fontWeight, FontWeight.w400);
            expect(hint.style!.height, 1.7);
            expect(hint.style!.color, color.withValues(alpha: alpha));
            expect(field.style!.fontSize, 16);
            expect(find.text(_questions), findsNothing);
          },
        );
      }
    }

    for (final mode in ['new', 'edit', 'historical']) {
      testWidgets('${type.name} $mode 输入后隐藏提示，清空后恢复', (tester) async {
        await tester.pumpWidget(
          _host(
            type: type,
            content: mode == 'edit' ? '已有记录' : null,
            date: mode == 'historical' ? DateTime(2026, 10, 24) : null,
          ),
        );
        final field = tester.widget<TextField>(_editor);
        final element = tester.element(_editor);
        expect(find.text(copy), mode == 'edit' ? findsNothing : findsOneWidget);
        await tester.showKeyboard(_editor);
        for (final value in [
          const TextEditingValue(
            text: ' ',
            selection: TextSelection.collapsed(offset: 1),
          ),
          const TextEditingValue(
            text: '用户正文',
            selection: TextSelection.collapsed(offset: 4),
          ),
          const TextEditingValue(selection: TextSelection.collapsed(offset: 0)),
        ]) {
          tester.testTextInput.updateEditingValue(value);
          await tester.pump();
          final current = tester.widget<TextField>(_editor);
          expect(identical(tester.element(_editor), element), isTrue);
          expect(identical(current.controller, field.controller), isTrue);
          expect(current.controller!.value, value);
          expect(current.focusNode!.hasFocus, isTrue);
          expect(
            find.text(copy),
            value.text.isEmpty ? findsOneWidget : findsNothing,
          );
        }
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull,
        );
      });
    }

    testWidgets('${type.name} 保存和草稿只使用用户正文', (tester) async {
      final storage = _DraftStorage();
      QuickCaptureSubmission? saved;
      await tester.pumpWidget(
        _host(
          type: type,
          date: DateTime(2026, 10, 24),
          drafts: DraftRepository(storage: storage),
          onSave: (submission) => saved = submission,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(storage.writes, 0);
      await tester.enterText(_editor, '只写这一句');
      await tester.pump(const Duration(milliseconds: 400));
      expect(storage.values.values.single, contains('只写这一句'));
      expect(storage.values.values.single, isNot(contains(copy)));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved!.content, '只写这一句');
    });

    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.3, 2.0, 3.0]) {
        testWidgets('${type.name} 320dp dark=$dark scale=$scale 提示完整且输入后收起', (
          tester,
        ) async {
          _setViewport(tester, const Size(320, 900));
          await tester.pumpWidget(_host(type: type, dark: dark, scale: scale));
          final hint = tester.renderObject<RenderParagraph>(find.text(copy));
          expect(hint.didExceedMaxLines, isFalse);
          expect(hint.size.width, lessThanOrEqualTo(288));
          expect(tester.getSize(_editor).height, greaterThan(50));
          final emptyHeight = tester.getSize(_editor).height;
          await tester.enterText(_editor, '记下一句');
          await tester.pump();
          expect(find.text(copy), findsNothing);
          expect(tester.getSize(_editor).height, lessThan(emptyHeight));
          expect(tester.takeException(), isNull);
          _expectToolbarTargets(tester);
        });
      }
    }
  }

  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      for (final scale in [1.0, 1.3, 2.0, 3.0]) {
        testWidgets(
          '320dp / $scale / dark=$dark / highContrast=$highContrast 完整换行和标签过渡',
          (tester) async {
            _setViewport(tester, const Size(320, 900));
            await tester.pumpWidget(
              _host(scale: scale, dark: dark, highContrast: highContrast),
            );
            final hint = tester.renderObject<RenderParagraph>(
              find.text(_questions),
            );
            expect(hint.didExceedMaxLines, isFalse);
            expect(hint.size.width, lessThanOrEqualTo(288));
            expect(
              hint
                  .getBoxesForSelection(
                    const TextSelection(
                      baseOffset: 0,
                      extentOffset: _questions.length,
                    ),
                  )
                  .length,
              greaterThanOrEqualTo(3),
            );
            expect(tester.takeException(), isNull);
            _expectToolbarTargets(tester);
            await tester.enterText(_editor, '先写一句');
            await tester.pump();
            await _checkTagTransition(tester);
          },
        );
      }
    }
  }

  if (_writePreview) {
    for (final type in EntryType.values) {
      for (final dark in [false, true]) {
        for (final filled in [false, true]) {
          testWidgets('导出${type.label}预览 dark=$dark filled=$filled', (
            tester,
          ) async {
            _setViewport(tester, const Size(390, 844));
            await tester.runAsync(_loadPreviewFont);
            await tester.pumpWidget(_host(type: type, dark: dark));
            if (filled) {
              await tester.enterText(_editor, '只写这一句，留住刚才的瞬间。');
            }
            await tester.pumpAndSettle();
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(_previewKey),
            );
            await tester.runAsync(
              () => _savePreview(
                boundary,
                '${type.name}-${dark ? 'dark' : 'light'}-${filled ? 'filled' : 'empty'}',
              ),
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectToolbarTargets(WidgetTester tester) {
  for (final key in ['quick_capture_polish', 'quick_capture_tag_toggle']) {
    final size = tester.getSize(find.byKey(Key(key)));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  }
  expect(find.text('给点提示'), findsNothing);
}

Future<void> _checkTagTransition(WidgetTester tester) async {
  tester.view.viewInsets = const FakeViewPadding(bottom: 280);
  addTearDown(tester.view.resetViewInsets);
  await tester.pump();
  await tester.tap(find.byKey(const Key('quick_capture_tag_toggle')));
  await tester.pump(const Duration(milliseconds: 80));
  expect(tester.takeException(), isNull);
  expect(find.byKey(const Key('quick_capture_tag_panel')), findsNothing);
  tester.view.resetViewInsets();
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('quick_capture_tag_panel')), findsOneWidget);
  await tester.tap(find.byKey(const Key('quick_capture_tag_toggle')));
  await tester.pumpAndSettle();
  expect(find.text('保存').hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _loadPreviewFont() async {
  if (_previewFontPath.trim().isEmpty) {
    throw StateError(
      '导出预览请通过 --dart-define=REFLECTION_PREVIEW_FONT=/绝对路径/字体文件 指定中文字体。',
    );
  }
  final previewFont = File(_previewFontPath);
  if (!await previewFont.exists()) {
    throw StateError('预览字体不存在：$_previewFontPath');
  }
  final font = FontLoader('ReflectionPreview');
  font.addFont(
    Future.value(ByteData.sublistView(await previewFont.readAsBytes())),
  );
  await font.load();
}

Future<void> _savePreview(RenderRepaintBoundary boundary, String name) async {
  final frame = await boundary.toImage(pixelRatio: 2);
  try {
    final png = (await frame.toByteData(format: ui.ImageByteFormat.png))!;
    final directory = await Directory(
      'build/record-placeholder-preview',
    ).create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(png.buffer.asUint8List());
  } finally {
    frame.dispose();
  }
}

class _DraftStorage implements DraftStorage {
  final values = <String, String>{};
  var writes = 0;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}
