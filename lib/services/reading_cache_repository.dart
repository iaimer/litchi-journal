import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

enum ReadingCacheKind { data, image }

class CachedBytes {
  final Uint8List bytes;
  final DateTime updatedAt;
  const CachedBytes(this.bytes, this.updatedAt);
}

class ReadingCacheUsage {
  final int dataBytes;
  final int imageBytes;
  const ReadingCacheUsage(this.dataBytes, this.imageBytes);
  int get totalBytes => dataBytes + imageBytes;
}

/// 只保存 API 阅读副本。临时目录为应用私有缓存，不进入系统云备份。
class ReadingCacheRepository {
  static final shared = ReadingCacheRepository();
  static final disabled = ReadingCacheRepository(enabled: false);
  static const dataLimit = 50 * 1024 * 1024;
  static const imageLimit = 200 * 1024 * 1024;
  static const imageFreshness = Duration(days: 7);
  final Future<Directory> Function() _directoryProvider;
  final DateTime Function() now;
  final int maxDataBytes;
  final int maxImageBytes;
  final bool enabled;
  Future<void> _queue = Future.value();
  final Map<String, int> _versions = {};
  final Set<String> _invalidatedNames = {};
  final Set<String> _invalidatedPrefixes = {};
  final Set<ReadingCacheKind> _clearedKinds = {};
  final Set<String> _writtenAfterInvalidation = {};
  final Map<ReadingCacheKind, Map<String, ({int size, DateTime usedAt})>>
  _sizes = {};
  int _sequence = 0;
  int dataGeneration = 0;
  int imageGeneration = 0;

  ReadingCacheRepository({
    Future<Directory> Function()? directoryProvider,
    DateTime Function()? now,
    this.maxDataBytes = dataLimit,
    this.maxImageBytes = imageLimit,
    this.enabled = true,
  }) : _directoryProvider = directoryProvider ?? getTemporaryDirectory,
       now = now ?? DateTime.now;

  static String digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  String _name(String namespace, String key) =>
      '${digest(namespace)}-${digest(key)}.cache';
  int generation(ReadingCacheKind kind) =>
      kind == ReadingCacheKind.data ? dataGeneration : imageGeneration;

  /// 每个请求在读缓存前领取票据，清理或新请求会让旧响应失去写入权。
  CacheWriteTicket begin(ReadingCacheKind kind, String namespace, String key) {
    final name = '${kind.name}/${_name(namespace, key)}';
    final revision = ++_sequence;
    _versions[name] = revision;
    return CacheWriteTicket(kind, name, generation(kind), revision);
  }

  bool isCurrent(CacheWriteTicket ticket) =>
      generation(ticket.kind) == ticket.generation &&
      _versions[ticket.name] == ticket.revision;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Directory> _root() async {
    final parent = await _directoryProvider().timeout(
      const Duration(seconds: 1),
    );
    return Directory('${parent.path}/reading_cache_v1').create(recursive: true);
  }

  Future<Directory> _group(ReadingCacheKind kind) async {
    final root = await _root();
    return Directory('${root.path}/${kind.name}').create(recursive: true);
  }

  Future<CachedBytes?> read(
    ReadingCacheKind kind,
    String namespace,
    String key,
  ) async {
    if (!enabled) return null;
    final name = '${kind.name}/${_name(namespace, key)}';
    final startGeneration = generation(kind);
    if (!_isReadable(kind, name)) return null;
    try {
      return await _serial(() async {
        final group = await _group(kind);
        final file = File('${group.path}/${_name(namespace, key)}');
        if (!await file.exists()) return null;
        final envelope = await file.readAsBytes();
        if (envelope.length < 40) {
          await file.delete();
          return null;
        }
        final bytes = Uint8List.sublistView(envelope, 40);
        final checksum = sha256.convert(bytes).bytes;
        for (var index = 0; index < 32; index++) {
          if (envelope[index + 8] != checksum[index]) {
            await file.delete();
            return null;
          }
        }
        final timestamp = ByteData.sublistView(envelope, 0, 8).getInt64(0);
        await file.setLastModified(now());
        if (startGeneration != generation(kind) || !_isReadable(kind, name)) {
          return null;
        }
        _sizes[kind]?[file.path] = (size: envelope.length, usedAt: now());
        return CachedBytes(
          bytes,
          DateTime.fromMillisecondsSinceEpoch(timestamp),
        );
      });
    } catch (_) {
      // 缓存不可用时仍允许请求服务端，不透出本地路径。
      return null;
    }
  }

  bool _isReadable(ReadingCacheKind kind, String name) =>
      _writtenAfterInvalidation.contains(name) ||
      !(_clearedKinds.contains(kind) ||
          _invalidatedNames.contains(name) ||
          _invalidatedPrefixes.any(name.startsWith));

  Future<void> write(CacheWriteTicket ticket, Uint8List bytes) async {
    if (!enabled) return;
    try {
      await _serial(() async {
        if (!isCurrent(ticket)) return;
        final limit = ticket.kind == ReadingCacheKind.data
            ? maxDataBytes
            : maxImageBytes;
        final root = await _root();
        final file = File('${root.path}/${ticket.name}');
        await file.parent.create(recursive: true);
        if (bytes.length + 40 > limit) {
          _invalidatedNames.add(ticket.name);
          _writtenAfterInvalidation.remove(ticket.name);
          if (await file.exists()) await file.delete();
          _sizes[ticket.kind]?.remove(file.path);
          return;
        }
        final envelope = Uint8List(bytes.length + 40);
        ByteData.sublistView(
          envelope,
        ).setInt64(0, now().millisecondsSinceEpoch);
        envelope.setRange(8, 40, sha256.convert(bytes).bytes);
        envelope.setRange(40, envelope.length, bytes);
        final partial = File('${file.path}.part');
        await partial.writeAsBytes(envelope, flush: true);
        if (!isCurrent(ticket)) {
          await partial.delete();
          return;
        }
        await partial.rename(file.path);
        if (isCurrent(ticket)) _writtenAfterInvalidation.add(ticket.name);
        await _prune(ticket.kind, file, envelope.length, limit);
      });
    } catch (_) {
      // 落盘失败不能改变已成功的读取或保存结果。
    }
  }

  Future<List<File>> _files(Directory group) async =>
      (await group.list(followLinks: false).toList())
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.cache') ||
                file.path.endsWith('.cache.part'),
          )
          .toList();

  Future<void> _prune(
    ReadingCacheKind kind,
    File written,
    int size,
    int limit,
  ) async {
    var index = _sizes[kind];
    if (index == null) {
      index = {};
      for (final file in await _files(written.parent)) {
        final stat = await file.stat();
        index[file.path] = (size: stat.size, usedAt: stat.modified);
      }
      _sizes[kind] = index;
    }
    index[written.path] = (size: size, usedAt: now());
    var total = index.values.fold<int>(0, (sum, entry) => sum + entry.size);
    if (total <= limit) return;
    final entries = index.entries.toList()
      ..sort((a, b) => a.value.usedAt.compareTo(b.value.usedAt));
    for (final entry in entries) {
      if (total <= limit) break;
      final file = File(entry.key);
      if (await file.exists()) await file.delete();
      index.remove(entry.key);
      total -= entry.value.size;
    }
  }

  Future<void> remove(
    ReadingCacheKind kind,
    String namespace,
    String key,
  ) async {
    final ticket = begin(kind, namespace, key);
    _invalidatedNames.add(ticket.name);
    _writtenAfterInvalidation.remove(ticket.name);
    if (!enabled) return;
    try {
      await _serial(() async {
        final group = await _group(kind);
        final file = File('${group.path}/${_name(namespace, key)}');
        if (await file.exists()) await file.delete();
        _sizes[kind]?.remove(file.path);
      });
    } catch (_) {
      /* 失效票据已阻止旧响应重新落盘。 */
    }
  }

  Future<void> invalidateData(String namespace) async {
    dataGeneration++;
    final prefix = 'data/${digest(namespace)}-';
    _invalidatedPrefixes.add(prefix);
    _writtenAfterInvalidation.removeWhere((name) => name.startsWith(prefix));
    try {
      await _delete(ReadingCacheKind.data, prefix: digest(namespace));
    } catch (_) {
      /* 服务端保存成功不能受清理失败影响。 */
    }
  }

  Future<void> clear({bool imagesOnly = false}) async {
    imageGeneration++;
    if (!imagesOnly) dataGeneration++;
    _clearedKinds.add(ReadingCacheKind.image);
    if (!imagesOnly) _clearedKinds.add(ReadingCacheKind.data);
    _writtenAfterInvalidation.removeWhere(
      (name) => !imagesOnly || name.startsWith('image/'),
    );
    await _delete(ReadingCacheKind.image);
    if (!imagesOnly) await _delete(ReadingCacheKind.data);
  }

  Future<void> _delete(ReadingCacheKind kind, {String? prefix}) {
    if (!enabled) return Future.value();
    return _serial(() async {
      final group = await _group(kind);
      for (final file in await _files(group)) {
        final name = file.uri.pathSegments.last;
        if (prefix == null || name.startsWith('$prefix-')) {
          await file.delete();
          _sizes[kind]?.remove(file.path);
        }
      }
    });
  }

  Future<ReadingCacheUsage> usage() {
    if (!enabled) return Future.value(const ReadingCacheUsage(0, 0));
    return _serial(() async {
      Future<int> count(ReadingCacheKind kind) async {
        var total = 0;
        for (final file in await _files(await _group(kind))) {
          total += await file.length();
        }
        return total;
      }

      return ReadingCacheUsage(
        await count(ReadingCacheKind.data),
        await count(ReadingCacheKind.image),
      );
    });
  }
}

class CacheWriteTicket {
  final ReadingCacheKind kind;
  final String name;
  final int generation;
  final int revision;
  const CacheWriteTicket(this.kind, this.name, this.generation, this.revision);
}

class CachedReading<T> {
  final T value;
  final DateTime updatedAt;
  const CachedReading(this.value, this.updatedAt);
}
