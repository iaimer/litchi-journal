import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 只接收本次系统选图器返回的路径，不扫描缓存，更不删除用户原图。
Future<void> deletePickerCacheFile(
  String path, {
  Directory? cacheDirectory,
}) async {
  try {
    final file = File(path);
    final name = file.uri.pathSegments.last;
    if (!name.startsWith('scaled_')) return;
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.file) {
      return;
    }
    final cache = cacheDirectory ?? await getTemporaryDirectory();
    if (await file.parent.resolveSymbolicLinks() !=
        await cache.resolveSymbolicLinks()) {
      return;
    }
    await file.delete();
  } catch (_) {
    // 缓存清理不改变服务器保存结果，系统仍可回收残余缓存。
  }
}
