import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/gallery_result.dart';
import '../services/gallery_service.dart';
import 'flora_icon.dart';

class GalleryImageTile extends StatefulWidget {
  final GalleryDay day;
  final GalleryService galleryService;
  final VoidCallback onTap;

  const GalleryImageTile({
    super.key,
    required this.day,
    required this.galleryService,
    required this.onTap,
  });

  @override
  State<GalleryImageTile> createState() => _GalleryImageTileState();
}

class _GalleryImageTileState extends State<GalleryImageTile> {
  late Future<Uint8List> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImage();
  }

  @override
  void didUpdateWidget(covariant GalleryImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.galleryService, widget.galleryService) ||
        oldWidget.day.date != widget.day.date ||
        oldWidget.day.firstImage != widget.day.firstImage) {
      _imageFuture = _loadImage();
    }
  }

  Future<Uint8List> _loadImage({bool forceRefresh = false}) {
    final imageName = widget.day.firstImage;
    if (imageName == null) return Future.error('图片不存在');
    return widget.galleryService.loadImage(
      day: widget.day,
      imageName: imageName,
      maxWidth: 480,
      forceRefresh: forceRefresh,
    );
  }

  void _retry() {
    setState(() {
      _imageFuture = _loadImage(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1,
          child: FutureBuilder<Uint8List>(
            future: _imageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _buildPlaceholder(theme, loading: true);
              }
              if (snapshot.hasError || snapshot.data == null) {
                return _buildError(theme);
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    cacheWidth: 480,
                    errorBuilder: (_, _, _) => _buildError(theme),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                      color: Colors.black38,
                      child: Text(
                        _dayNumber(widget.day.date),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, {required bool loading}) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FloraIcon(
                FloraIcons.imagePlaceholder,
                size: 28,
                color: theme.colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: _retry,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh,
                size: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text('点击重试', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  String _dayNumber(String date) {
    final parts = date.split('-');
    return parts.length == 3 ? parts[2] : date;
  }
}
