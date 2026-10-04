import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:litchi_journal_flutter/models/image_upload_item.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/widgets/entry_photo_grid.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/image_upload_strip.dart';

ImageUploadItem _upload(ImageUploadStatus status) => ImageUploadItem(
  id: 'photo',
  file: XFile.fromData(
    Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2))),
    name: 'photo.png',
  ),
  status: status,
);

Widget _tile(
  ImageUploadItem item, {
  VoidCallback? onRemove,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.6)),
    child: child!,
  ),
  home: Scaffold(
    body: ImageUploadTile(
      item: item,
      onRetry: () {},
      onRemove: onRemove ?? () {},
      canRemove: true,
      size: 104,
      height: 104,
    ),
  ),
);

void main() {
  testWidgets('照片移除操作的可见底色不超过 24dp，叉号为 14dp', (tester) async {
    await tester.pumpWidget(_tile(_upload(ImageUploadStatus.selected)));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('remove_image_photo'));
    final paintedMaterials = find.descendant(
      of: button,
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && (widget.color?.a ?? 0) > 0,
      ),
    );
    for (final element in paintedMaterials.evaluate()) {
      expect(
        tester.getSize(find.byWidget(element.widget)).width,
        lessThanOrEqualTo(24),
      );
    }
    final icon = tester.widget<FloraIcon>(
      find.descendant(of: button, matching: find.byType(FloraIcon)),
    );
    expect(icon.size, 14);
    final badge = find.descendant(
      of: button,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(badge, findsOneWidget);
    expect(tester.getSize(badge), const Size(24, 24));
  });

  for (final brightness in Brightness.values) {
    for (final status in [
      ImageUploadStatus.selected,
      ImageUploadStatus.failed,
    ]) {
      testWidgets('$brightness 下 $status 照片的透明角标热区仍可移除', (tester) async {
        var removed = 0;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _tile(
            _upload(status),
            brightness: brightness,
            onRemove: () => removed++,
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('remove_image_photo'));
        final area = tester.getRect(button);
        expect(area.size, const Size(48, 48));
        expect(find.byTooltip('移除图片'), findsOneWidget);
        expect(tester.getSemantics(button).getSemanticsData().tooltip, '移除图片');
        await tester.tapAt(area.bottomLeft + const Offset(8, -8));
        await tester.pump();
        expect(removed, 1);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }

  testWidgets('准备中、上传中及成功照片不显示移除入口', (tester) async {
    for (final status in [
      ImageUploadStatus.preparing,
      ImageUploadStatus.uploading,
      ImageUploadStatus.success,
    ]) {
      await tester.pumpWidget(_tile(_upload(status)));
      await tester.pump();
      expect(find.byTooltip('移除图片'), findsNothing);
    }
  });

  testWidgets('已有照片移除与恢复复用小角标，点击透明区域不触发预览', (tester) async {
    final api = ApiClient(
      ApiConfig(baseUrl: 'https://test.local', token: 'test'),
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          img.encodePng(img.Image(width: 2, height: 2)),
          200,
          headers: {'content-type': 'image/png'},
        ),
      ),
    );
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 328,
                child: EntryPhotoGrid(
                  photos: const [
                    DiaryPhoto(
                      filename: 'photo.png',
                      rawLine: '![[photo.png]]',
                    ),
                  ],
                  uploads: const [],
                  removedPhotoNames: removed ? {'photo.png'} : {},
                  apiClient: api,
                  date: DateTime(2026, 10, 4),
                  onAdd: () {},
                  onTogglePhotoRemoval: (_) =>
                      setState(() => removed = !removed),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final tooltip in ['保存时移除照片', '恢复照片']) {
      final button = find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      );
      final area = tester.getRect(button);
      expect(area.size, const Size(48, 48));
      final icon = tester.widget<FloraIcon>(
        find.descendant(of: button, matching: find.byType(FloraIcon)),
      );
      expect(icon.size, 14);
      await tester.tapAt(area.bottomLeft + const Offset(8, -8));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    }
    expect(removed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
