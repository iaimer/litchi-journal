import 'dart:collection';
import 'dart:typed_data';

import '../models/gallery_result.dart';
import 'api_client.dart';

/// 画廊数据与图片加载入口。
class GalleryService {
  final ApiClient apiClient;
  final GalleryImageCache imageCache;

  GalleryService(this.apiClient, {GalleryImageCache? imageCache})
    : imageCache = imageCache ?? GalleryImageCache();

  Future<GalleryPage> fetchPage({String? cursor, int limit = 3}) {
    return apiClient.fetchGallery(cursor: cursor, limit: limit);
  }

  Future<Uint8List> loadImage({
    required GalleryDay day,
    required String imageName,
    required int maxWidth,
    bool forceRefresh = false,
  }) {
    return imageCache.load(
      apiClient,
      year: day.dateTime.year,
      month: day.dateTime.month,
      imageName: imageName,
      maxWidth: maxWidth,
      forceRefresh: forceRefresh,
    );
  }

  void clearImageCache() => imageCache.clear();
}

/// 画廊专用的有界 LRU 图片缓存，避免连续回顾导致内存无限增长。
class GalleryImageCache {
  static const maxEntries = 60;

  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  final Map<String, Future<Uint8List>> _pending = {};

  Future<Uint8List> load(
    ApiClient apiClient, {
    required int year,
    required int month,
    required String imageName,
    required int maxWidth,
    bool forceRefresh = false,
  }) {
    final key = '$year-$month-$imageName-$maxWidth';
    // 高分辨率预览只做请求去重，不长期留在缩略图缓存中。
    final cacheImage = maxWidth <= 480;
    if (forceRefresh) _cache.remove(key);
    final cached = cacheImage ? _cache.remove(key) : null;
    if (cached != null) {
      _cache[key] = cached;
      return Future.value(cached);
    }

    final pending = _pending[key];
    if (pending != null) return pending;

    final future = apiClient
        .fetchRenderedDiaryImage(
          year: year,
          month: month,
          imageName: imageName,
          maxWidth: maxWidth,
        )
        .then((bytes) {
          if (cacheImage) {
            _cache[key] = bytes;
            while (_cache.length > maxEntries) {
              _cache.remove(_cache.keys.first);
            }
          }
          return bytes;
        })
        .whenComplete(() {
          _pending.remove(key);
        });
    _pending[key] = future;
    return future;
  }

  void clear() {
    _cache.clear();
  }
}
