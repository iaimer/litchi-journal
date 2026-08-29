import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/gallery_result.dart';
import '../services/api_client.dart';
import '../services/gallery_service.dart';
import 'read_only_diary_screen.dart';

class GalleryImageViewerScreen extends StatefulWidget {
  final GalleryDay day;
  final GalleryService galleryService;
  final ApiClient apiClient;
  final int initialIndex;

  const GalleryImageViewerScreen({
    super.key,
    required this.day,
    required this.galleryService,
    required this.apiClient,
    this.initialIndex = 0,
  });

  @override
  State<GalleryImageViewerScreen> createState() =>
      _GalleryImageViewerScreenState();
}

class _GalleryImageViewerScreenState extends State<GalleryImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.day.images.isEmpty
        ? 0
        : widget.day.images.length - 1;
    _currentIndex = widget.initialIndex.clamp(0, maxIndex).toInt();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _formatDate(widget.day.dateTime);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(dateLabel),
        actions: [
          IconButton(
            tooltip: '查看当天日记',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: _openDiary,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.day.images.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return _ViewerImage(
                  key: ValueKey(
                    '${widget.day.date}-${widget.day.images[index]}',
                  ),
                  day: widget.day,
                  imageName: widget.day.images[index],
                  galleryService: widget.galleryService,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_currentIndex + 1} / ${widget.day.images.length}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openDiary,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('查看当天日记'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDiary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReadOnlyDiaryScreen(
          date: widget.day.dateTime,
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}年${date.month}月${date.day}日';
}

class _ViewerImage extends StatefulWidget {
  final GalleryDay day;
  final String imageName;
  final GalleryService galleryService;

  const _ViewerImage({
    super.key,
    required this.day,
    required this.imageName,
    required this.galleryService,
  });

  @override
  State<_ViewerImage> createState() => _ViewerImageState();
}

class _ViewerImageState extends State<_ViewerImage> {
  late Future<Uint8List> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImage();
  }

  @override
  void didUpdateWidget(covariant _ViewerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.galleryService, widget.galleryService) ||
        oldWidget.imageName != widget.imageName ||
        oldWidget.day.date != widget.day.date) {
      _imageFuture = _loadImage();
    }
  }

  Future<Uint8List> _loadImage({bool forceRefresh = false}) {
    return widget.galleryService.loadImage(
      day: widget.day,
      imageName: widget.imageName,
      maxWidth: 1600,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _buildError(snapshot.error);
        }
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              cacheWidth: 1600,
              errorBuilder: (_, error, _) => _buildError(error),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(Object? error) {
    final unavailable = error is ApiException && error.statusCode == 404;
    if (unavailable) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.white70),
            SizedBox(height: 8),
            Text('图片不可用', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    return TextButton.icon(
      onPressed: () => setState(() {
        _imageFuture = _loadImage(forceRefresh: true);
      }),
      icon: const Icon(Icons.refresh),
      label: const Text('图片无法显示，点击重试'),
      style: TextButton.styleFrom(foregroundColor: Colors.white),
    );
  }
}
