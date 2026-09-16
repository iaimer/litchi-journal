import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'journal_section.dart';

import '../models/diary_document.dart';
import '../models/image_upload_item.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'image_upload_strip.dart';
import 'timeline_action_sheet.dart';

class ImageSectionCard extends StatelessWidget {
  final MediaSection section;
  final Color? accentColor;
  final ApiClient apiClient;
  final DateTime date;
  final Future<void> Function(String rawLine)? onDeleteImage;

  const ImageSectionCard({
    super.key,
    required this.section,
    this.accentColor,
    required this.apiClient,
    required this.date,
    this.onDeleteImage,
    this.imageUploads = const [],
    this.onRetryImageUpload,
    this.onRemoveImageUpload,
    this.canRemoveImageUpload,
  });

  final List<ImageUploadItem> imageUploads;
  final ValueChanged<ImageUploadItem>? onRetryImageUpload;
  final ValueChanged<ImageUploadItem>? onRemoveImageUpload;
  final bool Function(ImageUploadItem item)? canRemoveImageUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filenames = parseWikiLinks(section);

    if (filenames.isEmpty && imageUploads.isEmpty) {
      return JournalSection(
        title: '影像记录',
        accentColor: accentColor ?? theme.colorScheme.primary,
        children: [
          Text(
            '暂无影像记录',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final children = <Widget>[];
    if (filenames.isNotEmpty) {
      children.add(
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth > FloraSpacing.sm
                ? (constraints.maxWidth - FloraSpacing.sm) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: FloraSpacing.sm,
              runSpacing: FloraSpacing.sm,
              children: filenames.map((name) {
                return _ImageThumbnail(
                  size: cellWidth,
                  filename: name,
                  apiClient: apiClient,
                  date: date,
                  onDelete: onDeleteImage != null
                      ? () => onDeleteImage!('![[$name]]')
                      : null,
                );
              }).toList(),
            );
          },
        ),
      );
    }

    if (imageUploads.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: FloraSpacing.md));
      }
      children.add(
        ImageUploadStrip(
          items: imageUploads,
          onRetry: onRetryImageUpload ?? (_) {},
          onRemove: onRemoveImageUpload ?? (_) {},
          canRemove: canRemoveImageUpload,
          padding: EdgeInsets.zero,
        ),
      );
    }

    return JournalSection(
      title: '影像记录',
      accentColor: accentColor ?? theme.colorScheme.primary,
      children: children,
    );
  }

  static List<String> parseWikiLinks(MediaSection section) {
    final filenames = <String>[];
    final wikiLinkPattern = RegExp(
      r'!\[\[([^\]\\]+\.(?:jpg|jpeg|png|gif|webp|heic|heif))\]\]',
      caseSensitive: false,
    );

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
  final double size;
  final String filename;
  final ApiClient apiClient;
  final DateTime date;
  final VoidCallback? onDelete;

  const _ImageThumbnail({
    required this.size,
    required this.filename,
    required this.apiClient,
    required this.date,
    this.onDelete,
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

      final commaIndex = dataUrl.indexOf(',');
      final base64 = commaIndex >= 0
          ? dataUrl.substring(commaIndex + 1)
          : dataUrl;
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

  void _openPreview() {
    if (_bytes == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: InteractiveViewer(
          child: Center(
            child: Image.memory(
              _bytes!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Center(
                child: Text('图片加载失败', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除照片'),
        content: const Text('将从今日影像记录中删除这张图片'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete?.call();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _openActions() async {
    if (widget.onDelete == null) return;
    final action = await showTimelineActionSheet(
      context,
      showEdit: false,
      showDelete: true,
    );
    if (!mounted || action != TimelineAction.delete) return;
    _confirmDelete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(FloraRadius.sm),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_error != null || _bytes == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(FloraRadius.sm),
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

    return Stack(
      children: [
        GestureDetector(
          onTap: _openPreview,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _bytes!,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(FloraRadius.sm),
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
          ),
        ),
        if (widget.onDelete != null)
          Positioned(
            top: 0,
            right: 0,
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                onPressed: _openActions,
                tooltip: '更多操作',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                icon: const Icon(Icons.more_horiz_rounded, size: 18),
              ),
            ),
          ),
      ],
    );
  }
}
