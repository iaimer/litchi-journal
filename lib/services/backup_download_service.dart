import 'dart:io';

import 'package:flutter/services.dart';

/// 通过 Android DownloadManager 将备份保存到公共“下载/荔枝日记备份”目录。
///
/// 使用原生下载队列是为了让下载在 App 退出后仍能继续，并由系统负责通知和
/// 网络重试。非 Android 平台由调用方显示不支持提示。
class BackupDownloadService {
  static const channelName = 'litchi_journal/backup_download';

  final MethodChannel _channel;
  final bool _isAndroid;

  BackupDownloadService({MethodChannel? channel, bool? isAndroid})
    : _channel = channel ?? const MethodChannel(channelName),
      _isAndroid = isAndroid ?? Platform.isAndroid;

  Future<int?> enqueue({
    required String url,
    required String authorization,
    required String fileName,
  }) async {
    if (!_isAndroid) {
      throw UnsupportedError('当前平台不支持直接保存到手机');
    }
    final result = await _channel.invokeMethod<dynamic>('enqueue', {
      'url': url,
      'authorization': authorization,
      'fileName': fileName,
    });
    return result is num ? result.toInt() : null;
  }

  Future<BackupDownloadStatus?> query(int downloadId) async {
    if (!_isAndroid) return null;
    final result = await _channel.invokeMapMethod<String, dynamic>('query', {
      'downloadId': downloadId,
    });
    return result == null ? null : BackupDownloadStatus.fromMap(result);
  }

  Future<BackupDownloadStatus?> queryLatest() async {
    if (!_isAndroid) return null;
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'queryLatest',
    );
    return result == null ? null : BackupDownloadStatus.fromMap(result);
  }

  Future<void> clearLatest() async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('clearLatest');
  }

  static String fileName(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'litchi-journal-diary-${date.year}${two(date.month)}'
        '${two(date.day)}-${two(date.hour)}${two(date.minute)}${two(date.second)}.zip';
  }
}

enum BackupDownloadState { pending, running, paused, success, failed }

class BackupDownloadStatus {
  final int downloadId;
  final BackupDownloadState state;
  final String? error;
  final int downloadedBytes;
  final int totalBytes;

  const BackupDownloadStatus({
    required this.downloadId,
    required this.state,
    required this.downloadedBytes,
    required this.totalBytes,
    this.error,
  });

  bool get isTerminal =>
      state == BackupDownloadState.success ||
      state == BackupDownloadState.failed;

  factory BackupDownloadStatus.fromMap(Map<String, dynamic> value) {
    final id = value['downloadId'];
    if (id is! num) throw const FormatException('下载状态无效');
    return BackupDownloadStatus(
      downloadId: id.toInt(),
      state: switch (value['state']) {
        'running' => BackupDownloadState.running,
        'paused' => BackupDownloadState.paused,
        'success' => BackupDownloadState.success,
        'failed' => BackupDownloadState.failed,
        _ => BackupDownloadState.pending,
      },
      error: value['error'] as String?,
      downloadedBytes: _wholeInt(value['downloadedBytes']),
      totalBytes: _wholeInt(value['totalBytes']),
    );
  }

  static int _wholeInt(Object? value) {
    if (value is! num || value.toInt() != value) return -1;
    return value.toInt();
  }
}
