import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'diary_module_visual.dart';
import 'flora_origin.dart';
import 'flora_dialog.dart';

import 'journal_section.dart';

import '../models/diary_document.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'flora_icon.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allPhotos = section.photos;
    final photos = allPhotos
        .where((photo) => photo.entryId == null)
        .toList(growable: false);

    if (photos.isEmpty) {
      if (allPhotos.isNotEmpty) return const SizedBox.shrink();
      return JournalSection(
        title: '影像记录',
        icon: DiaryModuleVisual.forType(section.sectionType)?.icon,
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
    if (photos.isNotEmpty) {
      children.add(
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth > FloraSpacing.sm
                ? (constraints.maxWidth - FloraSpacing.sm) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: FloraSpacing.sm,
              runSpacing: FloraSpacing.sm,
              children: photos.asMap().entries.map((entry) {
                final index = entry.key;
                final photo = entry.value;
                return DiaryImageThumbnail(
                  size: cellWidth,
                  index: index,
                  filename: photo.filename,
                  apiClient: apiClient,
                  date: date,
                  onDelete: onDeleteImage != null
                      ? () => onDeleteImage!(photo.rawLine)
                      : null,
                );
              }).toList(),
            );
          },
        ),
      );
    }

    return JournalSection(
      title: '影像记录',
      icon: DiaryModuleVisual.forType(section.sectionType)?.icon,
      accentColor: accentColor ?? theme.colorScheme.primary,
      children: children,
    );
  }
}

class DiaryImageThumbnail extends StatefulWidget {
  final double size;
  final int index;
  final String filename;
  final ApiClient apiClient;
  final DateTime date;
  final VoidCallback? onDelete;

  const DiaryImageThumbnail({
    super.key,
    required this.size,
    required this.index,
    required this.filename,
    required this.apiClient,
    required this.date,
    this.onDelete,
  });

  @override
  State<DiaryImageThumbnail> createState() => _DiaryImageThumbnailState();
}

class _DiaryImageThumbnailState extends State<DiaryImageThumbnail> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  int _requestSerial = 0;
  int? _imageGeneration;
  DateTime? _lastLoadAttempt;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant DiaryImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.apiClient, widget.apiClient) ||
        oldWidget.date != widget.date ||
        oldWidget.filename != widget.filename ||
        _imageGeneration != widget.apiClient.readingCache.imageGeneration ||
        (!_loading &&
            _lastLoadAttempt != null &&
            widget.apiClient.readingCache.now().difference(_lastLoadAttempt!) >=
                const Duration(days: 7))) {
      _bytes = null;
      _loadImage();
    }
  }

  Future<void> _loadImage({bool forceRefresh = false}) async {
    final serial = ++_requestSerial;
    _imageGeneration = widget.apiClient.readingCache.imageGeneration;
    _lastLoadAttempt = widget.apiClient.readingCache.now();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await widget.apiClient.fetchRenderedDiaryImage(
        year: widget.date.year,
        month: widget.date.month,
        imageName: widget.filename,
        maxWidth: 480,
        forceRefresh: forceRefresh,
        onRevalidated: (result) {
          if (!mounted || serial != _requestSerial) return;
          if (result.bytes != null) {
            _requestSerial++;
            setState(() {
              _bytes = result.bytes;
              _loading = false;
              _error = null;
            });
          } else if (result.error?.statusCode == 404 ||
              result.error?.isAuthenticationFailure == true) {
            _requestSerial++;
            setState(() {
              _bytes = null;
              _loading = false;
              _error = result.error!.isAuthenticationFailure ? '认证失败' : '图片不可用';
            });
          }
        },
      );

      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _error = e is ApiException
            ? (e.statusCode == 404
                  ? '图片不可用'
                  : e.isAuthenticationFailure
                  ? '认证失败'
                  : e.isNetworkFailure
                  ? '此图片尚未缓存'
                  : '图片加载失败')
            : '图片加载失败';
        _loading = false;
      });
    }
  }

  void _openPreview() {
    if (_bytes == null) return;
    showFloraDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: '图片预览',
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
              child: InteractiveViewer(
                child: Center(
                  child: _DiaryImagePreview(
                    apiClient: widget.apiClient,
                    date: widget.date,
                    filename: widget.filename,
                    initialBytes: _bytes!,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      tooltip: '关闭预览',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      icon: const FloraIcon(
                        FloraIcons.close,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showFloraDialog(
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
          child: TextButton(
            onPressed: _error == '图片不可用' || _error == '认证失败'
                ? null
                : () => _loadImage(forceRefresh: true),
            child: Text(
              _error ?? '图片加载失败',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Semantics(
          button: true,
          label: '预览第 ${widget.index + 1} 张图片',
          child: GestureDetector(
            onTap: _openPreview,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FloraRadius.sm),
              child: Image.memory(
                _bytes!,
                width: widget.size,
                height: widget.size,
                cacheWidth:
                    (widget.size * MediaQuery.devicePixelRatioOf(context))
                        .ceil()
                        .clamp(1, 480),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(FloraRadius.sm),
                  ),
                  child: Center(
                    child: TextButton(
                      onPressed: () => _loadImage(forceRefresh: true),
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
          ),
        ),
        if (widget.onDelete != null)
          Positioned(
            top: 0,
            right: 0,
            child: SizedBox(
              width: 48,
              height: 48,
              child: FloraOriginIconButton(
                button: IconButton(
                  onPressed: _openActions,
                  tooltip: '更多操作',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const FloraIcon(FloraIcons.more, size: 18),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DiaryImagePreview extends StatefulWidget {
  final ApiClient apiClient;
  final DateTime date;
  final String filename;
  final Uint8List initialBytes;
  const _DiaryImagePreview({
    required this.apiClient,
    required this.date,
    required this.filename,
    required this.initialBytes,
  });
  @override
  State<_DiaryImagePreview> createState() => _DiaryImagePreviewState();
}

class _DiaryImagePreviewState extends State<_DiaryImagePreview> {
  Uint8List? _bytes;
  String? _error;
  int _serial = 0;
  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes;
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final serial = ++_serial;
    setState(() => _error = null);
    try {
      final bytes = await widget.apiClient.fetchRenderedDiaryImage(
        year: widget.date.year,
        month: widget.date.month,
        imageName: widget.filename,
        maxWidth: 1600,
        forceRefresh: forceRefresh,
        onRevalidated: (result) {
          if (!mounted || serial != _serial) return;
          if (result.bytes != null) {
            _serial++;
            setState(() => _bytes = result.bytes);
          } else if (result.error?.statusCode == 404 ||
              result.error?.isAuthenticationFailure == true) {
            _serial++;
            setState(() {
              _bytes = null;
              _error = result.error!.isAuthenticationFailure ? '认证失败' : '图片不可用';
            });
          }
        },
      );
      if (mounted && serial == _serial) setState(() => _bytes = bytes);
    } catch (error) {
      if (!mounted || serial != _serial) return;
      setState(() {
        if (error is ApiException &&
            (error.statusCode == 404 || error.isAuthenticationFailure)) {
          _bytes = null;
          _error = error.isAuthenticationFailure ? '认证失败' : '图片不可用';
        } else {
          _error = '大图暂时无法加载';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_bytes != null)
        Flexible(
          child: Image.memory(
            _bytes!,
            cacheWidth: 1600,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Text('图片加载失败', style: TextStyle(color: Colors.white70)),
          ),
        ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: Colors.white70)),
      if (_error != null && _error != '图片不可用' && _error != '认证失败')
        TextButton(
          onPressed: () => _load(forceRefresh: true),
          child: const Text('重试'),
        ),
    ],
  );
}
