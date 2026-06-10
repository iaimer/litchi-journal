import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/memory_entry.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class MemoryCard extends StatefulWidget {
  final MemoryEntry entry;
  final ApiClient apiClient;
  final VoidCallback onTap;

  const MemoryCard({
    super.key,
    required this.entry,
    required this.apiClient,
    required this.onTap,
  });

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard> {
  Uint8List? _thumbnailBytes;
  bool _thumbLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final entry = widget.entry;
    if (entry.imageNames.isEmpty) {
      setState(() => _thumbLoading = false);
      return;
    }

    try {
      final result = await widget.apiClient.fetchDiaryImage(
        year: entry.date.year,
        month: entry.date.month,
        imageName: entry.imageNames.first,
      );
      final dataUrl = result['data'] as String?;
      if (dataUrl == null) throw Exception('图片数据为空');
      final commaIndex = dataUrl.indexOf(',');
      final base64 = commaIndex >= 0
          ? dataUrl.substring(commaIndex + 1)
          : dataUrl;
      final bytes = base64Decode(base64);
      if (!mounted) return;
      setState(() {
        _thumbnailBytes = bytes;
        _thumbLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _thumbLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期标题行
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    widget.entry.displayDate,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  Text(widget.entry.weekday, style: theme.textTheme.bodySmall),
                ],
              ),
            ),

            // 第一层：生活的乐趣（图片或小确幸）
            if (_hasJoyLayer) _buildJoyLayer(theme),

            // 第二层：成长的痕迹（觉察或随手记）
            if (widget.entry.growthText != null) _buildGrowthLayer(theme),

            // 第三层：当天总结（只有前两层都为空时才显示人生教练）
            if (_showCoachFallback) _buildCoachLayer(theme),

            // 底部内边距
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  bool get _hasJoyLayer =>
      widget.entry.imageNames.isNotEmpty || widget.entry.joyText != null;

  bool get _showCoachFallback =>
      widget.entry.imageNames.isEmpty &&
      widget.entry.joyText == null &&
      widget.entry.growthText == null &&
      widget.entry.coachSummary != null;

  Widget _buildJoyLayer(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 副标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '生活的乐趣',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.success,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 图片区域
        if (widget.entry.imageNames.isNotEmpty) _buildImageArea(theme),

        // 小确幸文本
        if (widget.entry.imageNames.isEmpty && widget.entry.joyText != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.entry.joyText!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildImageArea(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: double.infinity,
          height: 180,
          child: _buildImageContent(theme),
        ),
      ),
    );
  }

  Widget _buildImageContent(ThemeData theme) {
    if (_thumbLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_thumbnailBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _thumbnailBytes!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildImagePlaceholder(theme),
          ),
          // 多图计数 badge
          if (widget.entry.imageCount > 1)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.entry.imageCount} 张照片',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return _buildImagePlaceholder(theme);
  }

  Widget _buildImagePlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildGrowthLayer(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '成长的痕迹',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.entry.growthText!,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCoachLayer(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '当天总结',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.entry.coachSummary!,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
