import 'package:flutter/material.dart';

import '../services/reading_cache_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/flora_dialog.dart';
import '../widgets/flora_error_state.dart';
import '../widgets/flora_origin.dart';
import '../widgets/flora_page_scaffold.dart';
import '../widgets/flora_skeleton.dart';
import '../widgets/flora_success_snackbar.dart';

class ReadingCachePage extends StatefulWidget {
  final ReadingCacheRepository repository;
  const ReadingCachePage({super.key, required this.repository});

  @override
  State<ReadingCachePage> createState() => _ReadingCachePageState();
}

class _ReadingCachePageState extends State<ReadingCachePage> {
  ReadingCacheUsage? _usage;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final usage = await widget.repository.usage();
      if (mounted) {
        setState(() {
          _usage = usage;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '无法读取缓存空间，请重试');
    }
  }

  Future<void> _clear(bool imagesOnly) async {
    if (_busy) return;
    final confirmed = await showFloraDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(imagesOnly ? '清除图片缓存？' : '清除全部阅读缓存？'),
        content: const Text(
          '只清理手机上的阅读副本，不删除服务器日记、照片、连接配置或草稿。清理后，部分内容需要联网才能再次查看。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.clear(imagesOnly: imagesOnly);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await _load();
      if (mounted && _error == null) showFloraSuccessSnackBar(context, '缓存已清除');
    } catch (_) {
      if (mounted) setState(() => _error = '部分缓存未清除，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _size(int bytes) {
    if (bytes == 0) return '0 MB';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(value),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = _usage;
    return FloraPageScaffold(
      title: '本地缓存',
      body: ListView(
        padding: const EdgeInsets.all(FloraSpacing.lg),
        children: [
          const Text('访问过的日记和照片会自动保存在手机，连接后检查更新。'),
          const SizedBox(height: 24),
          if (usage == null && _error == null)
            const FloraSkeletonRegion(
              child: Column(
                children: [
                  FloraSkeletonBox(width: double.infinity, height: 48),
                  SizedBox(height: 12),
                  FloraSkeletonBox(width: double.infinity, height: 48),
                ],
              ),
            ),
          if (usage != null) ...[
            _row('日记与索引', _size(usage.dataBytes)),
            _row('图片', _size(usage.imageBytes)),
            const Divider(height: 1),
            _row('合计', _size(usage.totalBytes)),
            const SizedBox(height: 24),
            _row('日记缓存上限', '50 MB'),
            _row('图片缓存上限', '200 MB'),
            Text(
              '空间不足时，自动清理较少使用的内容。缓存不是备份，被清理的内容需要重新联网获取。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (anchorContext) => OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => FloraOrigin.run(anchorContext, () => _clear(true)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_busy ? '正在清理…' : '清除图片缓存'),
              ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (anchorContext) => TextButton(
                onPressed: _busy
                    ? null
                    : () => FloraOrigin.run(anchorContext, () => _clear(false)),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('清除全部阅读缓存'),
              ),
            ),
            const SizedBox(height: 16),
            Text('仅清理手机副本，不删除服务器日记和照片。', style: theme.textTheme.bodySmall),
          ],
          if (_error != null)
            FloraErrorState(message: _error!, onRetry: _busy ? () {} : _load),
        ],
      ),
    );
  }
}
