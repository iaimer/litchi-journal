import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/image_upload_item.dart';
import '../theme/app_theme.dart';
import 'flora_icon.dart';

class ImageUploadStrip extends StatelessWidget {
  final List<ImageUploadItem> items;
  final ValueChanged<ImageUploadItem> onRetry;
  final ValueChanged<ImageUploadItem> onRemove;
  final bool Function(ImageUploadItem item)? canRemove;

  const ImageUploadStrip({
    super.key,
    required this.items,
    required this.onRetry,
    required this.onRemove,
    this.canRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: FloraSpacing.md),
      child: SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: FloraSpacing.sm),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ImageUploadTile(
              key: ValueKey('image_upload_${item.id}'),
              item: item,
              onRetry: () => onRetry(item),
              onRemove: () => onRemove(item),
              canRemove: canRemove?.call(item) ?? true,
            );
          },
        ),
      ),
    );
  }
}

class _ImageUploadTile extends StatefulWidget {
  final ImageUploadItem item;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final bool canRemove;

  const _ImageUploadTile({
    super.key,
    required this.item,
    required this.onRetry,
    required this.onRemove,
    required this.canRemove,
  });

  @override
  State<_ImageUploadTile> createState() => _ImageUploadTileState();
}

class _ImageUploadTileState extends State<_ImageUploadTile> {
  late Future<Uint8List> _previewBytes;

  @override
  void initState() {
    super.initState();
    _previewBytes = widget.item.file.readAsBytes();
  }

  @override
  void didUpdateWidget(covariant _ImageUploadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.file != widget.item.file) {
      _previewBytes = widget.item.file.readAsBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final canRemove =
        widget.canRemove &&
        (item.status == ImageUploadStatus.selected ||
            item.status == ImageUploadStatus.failed);
    return Semantics(
      label: _semanticLabel(item),
      button: item.status == ImageUploadStatus.failed,
      child: SizedBox(
        width: 104,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(FloraRadius.sm),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List>(
                future: _previewBytes,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                    );
                  }
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  );
                },
              ),
              _buildStatusOverlay(context, item),
              if (canRemove)
                Positioned(
                  top: FloraSpacing.xs,
                  right: FloraSpacing.xs,
                  child: IconButton.filled(
                    key: ValueKey('remove_image_${item.id}'),
                    onPressed: widget.onRemove,
                    tooltip: '移除图片',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const FloraIcon(FloraIcons.close, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOverlay(BuildContext context, ImageUploadItem item) {
    switch (item.status) {
      case ImageUploadStatus.selected:
        return Align(
          alignment: Alignment.bottomCenter,
          child: ColoredBox(
            color: Colors.black54,
            child: const SizedBox(
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: FloraSpacing.xs),
                child: Text(
                  '待上传',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        );
      case ImageUploadStatus.preparing:
        return _LoadingOverlay(label: '准备中');
      case ImageUploadStatus.uploading:
        final percent = (item.progress * 100).round();
        return _LoadingOverlay(label: '$percent%', progress: item.progress);
      case ImageUploadStatus.success:
        return const SizedBox.shrink();
      case ImageUploadStatus.failed:
        return Material(
          color: Colors.black.withValues(alpha: 0.62),
          child: InkWell(
            key: ValueKey('retry_image_${item.id}'),
            onTap: widget.onRetry,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(FloraSpacing.sm),
                child: Text(
                  '上传失败\n点击重试',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }

  String _semanticLabel(ImageUploadItem item) {
    return switch (item.status) {
      ImageUploadStatus.selected => '图片已选择，待上传',
      ImageUploadStatus.preparing => '图片准备中',
      ImageUploadStatus.uploading => '图片上传中，${(item.progress * 100).round()}%',
      ImageUploadStatus.success => '图片上传完成',
      ImageUploadStatus.failed => '图片上传失败，点击重试',
    };
  }
}

class _LoadingOverlay extends StatelessWidget {
  final String label;
  final double? progress;

  const _LoadingOverlay({required this.label, this.progress});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                key: ValueKey(
                  progress == null
                      ? 'image_preparing_indicator'
                      : 'image_upload_progress_indicator',
                ),
                value: progress,
                strokeWidth: 2.5,
                color: Colors.white,
                backgroundColor: progress == null ? null : Colors.white30,
              ),
            ),
            const SizedBox(height: FloraSpacing.sm),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
