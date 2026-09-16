import 'dart:io';

import 'package:flutter/services.dart';

/// 通过 Android DownloadManager 将备份保存到公共“下载/荔枝日记备份”目录。
///
/// 使用原生下载队列是为了让下载在 App 退出后仍能继续，并由系统负责通知和
/// 网络重试。非 Android 平台由调用方显示不支持提示。
class BackupDownloadService {
  static const channelName = 'litchi_journal/backup_download';

  final MethodChannel _channel;

  BackupDownloadService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  Future<int?> enqueue({
    required String url,
    required String authorization,
    required String fileName,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前平台不支持直接保存到手机');
    }
    final result = await _channel.invokeMethod<dynamic>('enqueue', {
      'url': url,
      'authorization': authorization,
      'fileName': fileName,
    });
    return result is num ? result.toInt() : null;
  }

  static String fileName(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'litchi-journal-diary-${date.year}${two(date.month)}'
        '${two(date.day)}-${two(date.hour)}${two(date.minute)}${two(date.second)}.zip';
  }
}
