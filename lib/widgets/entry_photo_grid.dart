import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../models/image_upload_item.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'flora_icon.dart';
import 'image_section_card.dart';
import 'image_upload_strip.dart';

class EntryPhotoGrid extends StatelessWidget {
  final List<DiaryPhoto> photos;
  final List<ImageUploadItem> uploads;
  final Set<String> removedPhotoNames;
  final ApiClient apiClient;
  final DateTime date;
  final VoidCallback? onAdd;
  final ValueChanged<DiaryPhoto>? onTogglePhotoRemoval;
  final ValueChanged<ImageUploadItem>? onRetryUpload;
  final ValueChanged<ImageUploadItem>? onRemoveUpload;
  final int maxCount;

  const EntryPhotoGrid({
    super.key,
    required this.photos,
    required this.uploads,
    required this.removedPhotoNames,
    required this.apiClient,
    required this.date,
    this.onAdd,
    this.onTogglePhotoRemoval,
    this.onRetryUpload,
    this.onRemoveUpload,
    this.maxCount = 9,
  });

  @override
  Widget build(BuildContext context) {
    final visiblePhotos = photos
        .where((photo) => !removedPhotoNames.contains(photo.filename))
        .toList(growable: false);
    final activeCount = visiblePhotos.length + uploads.length;
    if (activeCount == 0 && onAdd == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = FloraSpacing.sm;
        final size = (constraints.maxWidth - spacing * 2) / 3;
        final children = <Widget>[];
        for (var index = 0; index < photos.length; index++) {
          final photo = photos[index];
          children.add(
            _SavedPhotoTile(
              key: ValueKey('entry_photo_${photo.filename}'),
              photo: photo,
              index: index,
              size: size,
              apiClient: apiClient,
              date: date,
              removed: removedPhotoNames.contains(photo.filename),
              onToggleRemoval: onTogglePhotoRemoval == null
                  ? null
                  : () => onTogglePhotoRemoval!(photo),
            ),
          );
        }
        children.addAll(
          uploads.map(
            (item) => ImageUploadTile(
              key: ValueKey('image_upload_${item.id}'),
              item: item,
              onRetry: () => onRetryUpload?.call(item),
              onRemove: () => onRemoveUpload?.call(item),
              canRemove: onRemoveUpload != null,
              size: size,
              height: size,
            ),
          ),
        );
        if (onAdd != null && activeCount < maxCount) {
          children.add(_AddPhotoTile(size: size, onTap: onAdd!));
        }

        return Wrap(spacing: spacing, runSpacing: spacing, children: children);
      },
    );
  }
}

class _SavedPhotoTile extends StatelessWidget {
  final DiaryPhoto photo;
  final int index;
  final double size;
  final ApiClient apiClient;
  final DateTime date;
  final bool removed;
  final VoidCallback? onToggleRemoval;

  const _SavedPhotoTile({
    super.key,
    required this.photo,
    required this.index,
    required this.size,
    required this.apiClient,
    required this.date,
    required this.removed,
    this.onToggleRemoval,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: removed ? 0.35 : 1,
              child: DiaryImageThumbnail(
                size: size,
                index: index,
                filename: photo.filename,
                apiClient: apiClient,
                date: date,
              ),
            ),
          ),
          if (onToggleRemoval != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton.filled(
                onPressed: onToggleRemoval,
                tooltip: removed ? '恢复照片' : '保存时移除照片',
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                icon: FloraIcon(
                  removed ? FloraIcons.restore : FloraIcons.close,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final double size;
  final VoidCallback onTap;

  const _AddPhotoTile({required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '添加照片',
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(FloraRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FloraRadius.sm),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(FloraRadius.sm),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FloraIcon(FloraIcons.add, size: 24),
                const SizedBox(height: FloraSpacing.xs),
                Text('添加照片', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
