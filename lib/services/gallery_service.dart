import 'dart:collection';
import 'dart:typed_data';

import '../models/gallery_result.dart';
import 'api_client.dart';
import 'reading_cache_repository.dart';

/// 画廊数据与图片加载入口。
class GalleryService {
  final ApiClient apiClient;
  final GalleryImageCache imageCache;

  GalleryService(this.apiClient, {GalleryImageCache? imageCache})
    : imageCache = imageCache ?? GalleryImageCache();

  Future<GalleryPage> fetchPage({
    String? cursor,
    int limit = 3,
    void Function(CachedReading<GalleryPage>)? onCached,
  }) {
    return apiClient.fetchGallery(
      cursor: cursor,
      limit: limit,
      onCached: onCached,
    );
  }

  Future<Uint8List> loadImage({
    required GalleryDay day,
    required String imageName,
    required int maxWidth,
    bool forceRefresh = false,
    void Function(ImageRevalidation)? onRevalidated,
  }) {
    return imageCache.load(
      apiClient,
      year: day.dateTime.year,
      month: day.dateTime.month,
      imageName: imageName,
      maxWidth: maxWidth,
      forceRefresh: forceRefresh,
      onRevalidated: onRevalidated,
    );
  }

  void clearImageCache() => imageCache.clear();
}

/// 画廊专用的有界 LRU 图片缓存，避免连续回顾导致内存无限增长。
class GalleryImageCache {
  static const maxEntries = 60;

  final LinkedHashMap<String, CachedBytes> _cache = LinkedHashMap();
  final Map<String, Future<Uint8List>> _pending = {};
  final Map<String, List<void Function(ImageRevalidation)>> _listeners = {};

  Future<Uint8List> load(
    ApiClient apiClient, {
    required int year,
    required int month,
    required String imageName,
    required int maxWidth,
    bool forceRefresh = false,
    void Function(ImageRevalidation)? onRevalidated,
  }) {
    final generation = apiClient.readingCache.imageGeneration;
    final key =
        '${apiClient.readingCacheNamespace}-$generation-$year-$month-$imageName-$maxWidth';
    if (_generation != generation) {
      clear();
      _generation = generation;
    }
    // 高分辨率预览只做请求去重，不长期留在缩略图缓存中。
    final cacheImage = maxWidth <= 480;
    if (forceRefresh) {
      _cache.remove(key);
      _pending.remove(key);
      _listeners.remove(key);
    }
    final cached = cacheImage ? _cache.remove(key) : null;
    if (cached != null &&
        apiClient.readingCache.now().difference(cached.updatedAt) <
            ReadingCacheRepository.imageFreshness) {
      _cache[key] = cached;
      return Future.value(cached.bytes);
    }

    if (onRevalidated != null) {
      (_listeners[key] ??= []).add(onRevalidated);
    }

    final pending = _pending[key];
    if (pending != null) return pending;

    final revision = _revision;
    var updatedAt = apiClient.readingCache.now();
    var revalidating = false;
    var revalidated = false;
    late final Future<Uint8List> future;
    future = apiClient
        .fetchRenderedDiaryImage(
          year: year,
          month: month,
          imageName: imageName,
          maxWidth: maxWidth,
          forceRefresh: forceRefresh,
          onCacheRead: (time) {
            updatedAt = time;
            revalidating =
                apiClient.readingCache.now().difference(time) >=
                ReadingCacheRepository.imageFreshness;
          },
          onRevalidated: (result) {
            if (revision != _revision ||
                generation != apiClient.readingCache.imageGeneration) {
              return;
            }
            revalidated = true;
            if (result.bytes != null && cacheImage) {
              _store(key, result.bytes!, apiClient.readingCache.now());
            } else if (result.error?.statusCode == 404 ||
                result.error?.isAuthenticationFailure == true) {
              _cache.remove(key);
            }
            for (final listener in _listeners.remove(key) ?? []) {
              listener(result);
            }
          },
        )
        .then((bytes) {
          if (cacheImage &&
              !revalidated &&
              revision == _revision &&
              generation == apiClient.readingCache.imageGeneration &&
              identical(_pending[key], future)) {
            _store(key, bytes, updatedAt);
          }
          return bytes;
        })
        .whenComplete(() {
          if (identical(_pending[key], future)) {
            _pending.remove(key);
            if (!revalidating) _listeners.remove(key);
          }
        });
    _pending[key] = future;
    return future;
  }

  void clear() {
    _revision++;
    _cache.clear();
    _pending.clear();
    _listeners.clear();
  }

  void _store(String key, Uint8List bytes, DateTime updatedAt) {
    _cache.remove(key);
    _cache[key] = CachedBytes(bytes, updatedAt);
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  int? _generation;
  int _revision = 0;
  int get revision => _revision;
}
