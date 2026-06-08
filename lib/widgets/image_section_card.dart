import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../services/api_client.dart';

class ImageSectionCard extends StatelessWidget {
  final MediaSection section;
  final ApiClient apiClient;
  final DateTime date;

  const ImageSectionCard({
    super.key,
    required this.section,
    required this.apiClient,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filenames = parseWikiLinks(section);

    if (filenames.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '暂无影像记录',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filenames.map((name) {
                return _ImageThumbnail(
                  filename: name,
                  apiClient: apiClient,
                  date: date,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  static List<String> parseWikiLinks(MediaSection section) {
    final filenames = <String>[];
    final wikiLinkPattern = RegExp(r'!\[\[([^\]\\]+\.(?:jpg|jpeg|png|gif|webp|heic|heif))\]\]',
        caseSensitive: false);

    for (final content in section.contents) {
      if (content is MarkdownContent) {
        for (final match in wikiLinkPattern.allMatches(content.text)) {
          final name = match.group(1);
          if (name != null) filenames.add(name);
        }
      }
    }

    return filenames;
  }
}

class _ImageThumbnail extends StatefulWidget {
  final String filename;
  final ApiClient apiClient;
  final DateTime date;

  const _ImageThumbnail({
    required this.filename,
    required this.apiClient,
    required this.date,
  });

  @override
  State<_ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends State<_ImageThumbnail> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final result = await widget.apiClient.fetchDiaryImage(
        year: widget.date.year,
        month: widget.date.month,
        imageName: widget.filename,
      );
      final dataUrl = result['data'] as String?;
      if (dataUrl == null) throw Exception('图片数据为空');

      // data:image/jpeg;base64,xxx...
      final commaIndex = dataUrl.indexOf(',');
      final base64 = commaIndex >= 0 ? dataUrl.substring(commaIndex + 1) : dataUrl;
      final bytes = base64Decode(base64);

      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '图片加载失败';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const SizedBox(
        width: 120,
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null || _bytes == null) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            _error ?? '图片加载失败',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        _bytes!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '图片加载失败',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
