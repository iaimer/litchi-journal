import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/widgets/generic_section_card.dart';

void main() {
  testWidgets('日记 Markdown 外部图片不会生成网络 ImageProvider', (tester) async {
    final section = GenericDiarySection(
      title: '旧正文',
      contents: [
        MarkdownContent('![外部图](https://external.invalid/tracker.png)'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GenericSectionCard(section: section)),
      ),
    );
    await tester.pump();
    final markdown = tester.widget<MarkdownBody>(
      find.byType(MarkdownBody).first,
    );
    expect(markdown.sizedImageBuilder, isNotNull);
    expect(markdown.onTapLink, isNotNull);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('仅当前服务器的 render 路径经 ApiClient 取图，其他来源全部拦截', (tester) async {
    final requests = <Uri>[];
    final api = ApiClient(
      ApiConfig(baseUrl: 'https://journal.example', token: 'dummy-token'),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response.bytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aCYsAAAAASUVORK5CYII=',
          ),
          200,
        );
      }),
    );
    try {
      for (final source in [
        'https://journal.example/api/v1/diary/image/render/2024/%FF.png?month=2',
        'https://journal.example/api/v1/diary/image/render/2024/photo.png?month=%FF',
        'https://journal.example/api/v1/diary/image/render/2024/a%2Fb.png?month=2',
        'https://external.invalid/tracker.png',
        'file:///private/photo.png',
        'data:image/png;base64,AA==',
        'https://journal.example.other/api/v1/diary/image/render/2024/a.png?month=2',
      ]) {
        final section = GenericDiarySection(
          title: '正文',
          contents: [MarkdownContent('![图]($source)')],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenericSectionCard(section: section, apiClient: api),
            ),
          ),
        );
        await tester.pump();
      }
      expect(requests, isEmpty);
      final section = GenericDiarySection(
        title: '正文',
        contents: [
          MarkdownContent(
            '![图](https://journal.example/api/v1/diary/image/render/2024/Image-20261029-001.jpg?month=2&maxWidth=480)',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericSectionCard(section: section, apiClient: api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(
        requests.single.path,
        '/api/v1/diary/image/render/2024/Image-20261029-001.jpg',
      );
    } finally {
      api.dispose();
    }
  });
}
