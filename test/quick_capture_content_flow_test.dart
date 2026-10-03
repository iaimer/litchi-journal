import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/screens/quick_capture_screen.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/image_settings_repository.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/entry_photo_grid.dart';
import 'package:litchi_journal_flutter/widgets/entry_type.dart';
import 'package:litchi_journal_flutter/widgets/image_upload_strip.dart';
import 'package:litchi_journal_flutter/widgets/tag_picker.dart';

final _photoBytes = Uint8List.fromList(
  img.encodeJpg(img.Image(width: 8, height: 8)),
);

Widget _capture({
  String content = '今天带小宝去游乐场。',
  int photoCount = 1,
  List<String> tags = const ['亲子', '陪伴互动'],
  EntryType type = EntryType.quickNote,
  DateTime? recordDate,
  bool dark = false,
  double textScale = 1,
  QuickCaptureImagePicker? imagePicker,
}) {
  return MaterialApp(
    theme: dark ? AppTheme.dark : AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: QuickCaptureScreen(
      entryType: type,
      openedAt: DateTime(2026, 10, 4, 16, 42),
      recordDate: recordDate,
      initialContent: content,
      initialTags: tags,
      initialPhotos: List.generate(
        photoCount,
        (index) => DiaryPhoto(
          filename: 'photo$index.jpg',
          rawLine: '![[photo$index.jpg]]',
        ),
      ),
      apiClient: ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _PreviewClient(),
      ),
      imageSettingsRepository: ImageSettingsRepository(
        storage: _MemoryImageSettingsStorage(),
      ),
      imagePicker: imagePicker,
      onSave: (_) async {},
    ),
  );
}

Finder get _entry => find.byKey(const Key('quick_capture_entry_scroll'));
Finder get _summary => find.byType(TagSelectionSummary);
Finder get _toolbar => find.byKey(const Key('quick_capture_toolbar'));

void _setScreen(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final type in [EntryType.quickNote, EntryType.happiness]) {
    testWidgets('${type.name} 短正文、照片与标签按 12dp 顺序排列', (tester) async {
      _setScreen(tester, const Size(420, 800));
      await tester.pumpWidget(_capture(type: type));
      await tester.pumpAndSettle();

      final editor = tester.getRect(find.byType(TextField));
      final photos = tester.getRect(find.byType(EntryPhotoGrid));
      final tags = tester.getRect(_summary);
      expect(photos.top - editor.bottom, closeTo(12, 0.1));
      expect(tags.top - photos.bottom, closeTo(12, 0.1));
      expect(photos.bottom, lessThan(tester.getRect(_toolbar).top));
      expect(find.ancestor(of: _summary, matching: _entry), findsOneWidget);
    });
  }

  for (final type in EntryType.values.where(
    (type) => type != EntryType.anxiety,
  )) {
    testWidgets('${type.name} 纯文字没有空照片格，标签紧跟正文', (tester) async {
      await tester.pumpWidget(_capture(type: type, photoCount: 0));
      await tester.pumpAndSettle();

      expect(find.byType(EntryPhotoGrid), findsNothing);
      expect(
        tester.getRect(_summary).top -
            tester.getRect(find.byType(TextField)).bottom,
        closeTo(12, 0.1),
      );
    });
  }

  testWidgets('空白处可聚焦，移除与恢复照片不触发正文聚焦', (tester) async {
    _setScreen(tester, const Size(420, 800));
    await tester.pumpWidget(_capture());
    await tester.pumpAndSettle();
    final focus = tester.widget<TextField>(find.byType(TextField)).focusNode!;
    final viewport = tester.getRect(_entry);
    await tester.tapAt(Offset(viewport.center.dx, viewport.bottom - 20));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    focus.unfocus();
    await tester.pump();

    await tester.tap(find.byTooltip('保存时移除照片'));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    expect(find.byTooltip('恢复照片'), findsOneWidget);
    await tester.tap(find.byTooltip('恢复照片'));
    await tester.pump();
    expect(find.byTooltip('保存时移除照片'), findsOneWidget);
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('长正文自然增高，正文和照片由同一列表滚动', (tester) async {
    _setScreen(tester, const Size(420, 800));
    await tester.pumpWidget(
      _capture(content: List.filled(36, '这是日记的一个自然段。').join('\n')),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.expands, isFalse);
    expect(
      tester.getSize(find.byType(TextField)).height,
      greaterThan(tester.getSize(_entry).height),
    );

    await tester.scrollUntilVisible(
      _summary,
      250,
      scrollable: find
          .descendant(of: _entry, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(EntryPhotoGrid)).bottom,
      lessThanOrEqualTo(tester.getRect(_toolbar).top - 16),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('选图后显示首张新照片，而非跳到九宫格末尾', (tester) async {
    _setScreen(tester, const Size(320, 480));
    await tester.pumpWidget(
      _capture(
        content: List.filled(30, '今天的记录。').join('\n'),
        photoCount: 0,
        recordDate: DateTime(2026, 10, 3),
        imagePicker: (_, _) async => List.generate(
          9,
          (index) => XFile.fromData(_photoBytes, name: 'new$index.jpg'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_capture_add_photo')));
    await tester.pumpAndSettle();

    final first = tester.getRect(find.byType(ImageUploadTile).first);
    final viewport = tester.getRect(_entry);
    expect(first.top, greaterThanOrEqualTo(viewport.top));
    expect(first.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(find.text('照片 9/9'), findsOneWidget);
  });

  testWidgets('追加照片定位本次首张，而非已有照片', (tester) async {
    _setScreen(tester, const Size(320, 480));
    await tester.pumpWidget(
      _capture(
        photoCount: 6,
        imagePicker: (_, _) async => List.generate(
          3,
          (index) => XFile.fromData(_photoBytes, name: 'new$index.jpg'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_capture_add_photo')));
    await tester.pumpAndSettle();

    final firstNew = tester.getRect(find.byType(ImageUploadTile).first);
    final viewport = tester.getRect(_entry);
    expect(firstNew.top, greaterThanOrEqualTo(viewport.top));
    expect(firstNew.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  testWidgets('键盘出现后长正文的末尾光标与保存按钮保持可见', (tester) async {
    _setScreen(tester, const Size(420, 800));
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_capture(photoCount: 0));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(
      find.byType(TextField),
      List.filled(40, '继续写下今天的记录。').join('\n'),
    );
    await tester.pumpAndSettle();

    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    final render = editable.renderEditable;
    final selection = editable.widget.controller.selection;
    final caret = render.getLocalRectForCaret(selection.extent);
    final caretBottom = render.localToGlobal(caret.bottomLeft).dy;
    final caretTop = render.localToGlobal(caret.topLeft).dy;
    final viewport = tester.getRect(_entry);
    expect(caretTop, greaterThanOrEqualTo(viewport.top));
    expect(caretBottom, lessThanOrEqualTo(viewport.bottom));
    expect(
      tester.getRect(find.widgetWithText(ElevatedButton, '保存')).bottom,
      lessThanOrEqualTo(520),
    );
    expect(tester.takeException(), isNull);
  });

  for (final count in [1, 2, 9]) {
    testWidgets('$count 张照片在窄屏大字体下完整显示，标签与工具栏不重叠', (tester) async {
      _setScreen(tester, const Size(320, 640));
      await tester.pumpWidget(
        _capture(
          photoCount: count,
          dark: count != 1,
          textScale: count == 2 ? 1.3 : 1.6,
          tags: const ['很长的亲子记录标签', '这是陪伴互动标签', '家庭'],
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(_entry, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(_summary).top -
            tester.getRect(find.byType(EntryPhotoGrid)).bottom,
        closeTo(12, 0.1),
      );
      expect(
        tester.getRect(_summary).bottom,
        lessThanOrEqualTo(tester.getRect(_toolbar).top - 16),
      );
      final first = tester.getSize(
        find.byKey(const ValueKey('entry_photo_photo0.jpg')),
      );
      expect(first.height, closeTo(first.width, 0.1));
      expect(tester.takeException(), isNull);
    });
  }
}

class _PreviewClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream.value(_photoBytes), 200);
}

class _MemoryImageSettingsStorage implements ImageSettingsStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}
