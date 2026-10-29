import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_client.dart';

/// Markdown 不自行访问网络或本地文件，附件只经当前连接的图片接口读取。
Widget markdownImageBoundary(
  Uri uri,
  String? title,
  String? alt,
  ApiClient? api,
) {
  final unavailable = Text(alt?.isNotEmpty == true ? '图片不可用：$alt' : '图片不可用');
  if (api == null) return unavailable;
  final request = _renderRequest(uri, api);
  if (request == null) return unavailable;
  return FutureBuilder<Uint8List>(
    key: ValueKey(
      '${api.readingCacheNamespace}:${request.year}:${request.month}:${request.name}:${request.width}',
    ),
    future: api.fetchRenderedDiaryImage(
      year: request.year,
      month: request.month,
      imageName: request.name,
      maxWidth: request.width,
    ),
    builder: (context, snapshot) => snapshot.hasData
        ? Image.memory(
            snapshot.data!,
            semanticLabel: alt,
            errorBuilder: (_, _, _) => unavailable,
          )
        : unavailable,
  );
}

({int year, int month, int width, String name})? _renderRequest(
  Uri uri,
  ApiClient api,
) {
  final prefix = Uri.parse('${api.baseUrl}/api/v1/diary/image/render/');
  if (uri.scheme != prefix.scheme ||
      uri.host != prefix.host ||
      uri.port != prefix.port ||
      uri.userInfo.isNotEmpty ||
      !uri.path.startsWith(prefix.path)) {
    return null;
  }
  final parts = uri.path.substring(prefix.path.length).split('/');
  if (parts.length != 2) return null;
  final year = int.tryParse(parts[0]);
  final int? month;
  final int? width;
  final String name;
  try {
    final query = uri.queryParameters;
    month = int.tryParse(query['month'] ?? '');
    width = int.tryParse(query['maxWidth'] ?? '480');
    name = Uri.decodeComponent(parts[1]);
  } on FormatException {
    return null;
  }
  if (year == null ||
      year < 1000 ||
      year > 9999 ||
      month == null ||
      month < 1 ||
      month > 12 ||
      width == null ||
      width < 64 ||
      width > 2000 ||
      name.isEmpty ||
      name.codeUnits.any(
        (unit) => unit < 32 || unit == 127 || unit == 47 || unit == 92,
      )) {
    return null;
  }
  return (year: year, month: month, width: width, name: name);
}

void ignoreMarkdownLink(String text, String? href, String title) {}
