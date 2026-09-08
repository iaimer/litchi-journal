import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/default_tag_config.dart';
import '../models/diary_entry.dart';
import '../models/image_settings.dart';
import '../models/image_upload_item.dart';
import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../services/ai_config_repository.dart';
import '../services/api_client.dart';
import '../services/draft_repository.dart';
import '../services/image_compress_service.dart';
import '../services/image_settings_repository.dart';
import '../services/polisher_service.dart';
import '../services/tag_repository.dart';
import '../services/tag_settings_helper.dart';
import '../services/tag_settings_repository.dart';
import '../widgets/diary_markdown_view.dart';
import '../widgets/entry_type.dart';
import '../widgets/historical_quick_record_fab.dart';
import 'quick_capture_screen.dart';

typedef HistoricalImagePicker =
    Future<List<XFile>> Function(ImageSettings settings);
typedef HistoricalImageCompressor =
    Future<String> Function(Uint8List bytes, ImageSettings settings);

/// 历史日记详情页。
/// 已有内容保持只读，只允许新增相片、随手记、觉察和小确幸。
class ReadOnlyDiaryScreen extends StatefulWidget {
  static const maxImageUploadPayloadChars = 9 * 1024 * 1024;

  final DateTime date;
  final ApiClient apiClient;
  final HistoricalImagePicker? imagePicker;
  final DraftRepository? draftRepository;
  final ImageSettingsRepository? imageSettingsRepository;
  final HistoricalImageCompressor? imageCompressor;

  const ReadOnlyDiaryScreen({
    super.key,
    required this.date,
    required this.apiClient,
    this.imagePicker,
    this.draftRepository,
    this.imageSettingsRepository,
    this.imageCompressor,
  });

  @override
  State<ReadOnlyDiaryScreen> createState() => _ReadOnlyDiaryScreenState();
}

class _ReadOnlyDiaryScreenState extends State<ReadOnlyDiaryScreen> {
  final _systemImagePicker = ImagePicker();
  late final DraftRepository _draftRepository;
  late final ImageSettingsRepository _imageSettingsRepository;

  DiaryEntry? _diary;
  TagConfig? _tagConfig;
  TagSettings? _tagSettings;
  bool _loading = true;
  bool _quickRecordExpanded = false;
  final List<ImageUploadItem> _imageUploads = [];
  bool _diaryReadyForImageUpload = false;
  String? _error;

  TagConfig get _effectiveTagConfig {
    final config = _tagConfig ?? DefaultTagConfig.value;
    final settings = _tagSettings;
    return settings == null
        ? config
        : TagSettingsHelper.effectiveTagConfig(config, settings);
  }

  @override
  void initState() {
    super.initState();
    _draftRepository = widget.draftRepository ?? DraftRepository();
    _imageSettingsRepository =
        widget.imageSettingsRepository ?? ImageSettingsRepository();
    _loadDiary();
    _loadTagConfig();
  }

  Future<void> _loadDiary() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final diary = await widget.apiClient.getDiary(widget.date);
      if (!mounted) return;
      setState(() {
        _diary = diary?.raw.isNotEmpty == true ? diary : null;
        _diaryReadyForImageUpload = diary != null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败，请检查网络后重试';
        _loading = false;
      });
    }
  }

  Future<void> _loadTagConfig() async {
    final config = await TagRepository(
      apiClient: widget.apiClient,
    ).loadTagConfig();
    final settings = await TagSettingsRepository().loadTagSettings(config);
    if (!mounted) return;
    setState(() {
      _tagConfig = config;
      _tagSettings = settings;
    });
  }

  String _dateLabel() {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final d = widget.date;
    return '${d.year}年${d.month}月${d.day}日 星期${weekdays[d.weekday - 1]}';
  }

  Future<bool> _appendEntry(
    EntryType type,
    String content,
    List<String> tags,
    String time,
  ) async {
    Future<bool> append() {
      return switch (type) {
        EntryType.quickNote => widget.apiClient.appendQuickNote(
          widget.date,
          content,
          tags: tags,
          time: time,
        ),
        EntryType.reflection => widget.apiClient.appendReflection(
          widget.date,
          content,
          tags: tags,
          time: time,
        ),
        EntryType.happiness => widget.apiClient.appendHappiness(
          widget.date,
          content,
          tags: tags,
          time: time,
        ),
        EntryType.anxiety => Future.value(false),
      };
    }

    var success = await append();
    if (!success) {
      final created = await widget.apiClient.ensureDiary(widget.date);
      if (!created) return false;
      success = await append();
    }
    return success;
  }

  Future<PolishResult> _polish(String content, EntryType entryType) async {
    final aiConfig = await AIConfigRepository().loadAIConfig();
    if (!aiConfig.isUsable) {
      throw Exception('AI 润色未启用，请先在设置中配置');
    }
    final service = PolisherService();
    try {
      return await service.polish(
        content: content,
        entryType: entryType,
        tagConfig: _effectiveTagConfig,
        config: aiConfig,
        tagSettings: _tagSettings,
      );
    } finally {
      service.dispose();
    }
  }

  Future<void> _openQuickCapture(EntryType type) async {
    setState(() => _quickRecordExpanded = false);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickCaptureScreen(
          entryType: type,
          openedAt: DateTime.now(),
          recordDate: widget.date,
          draftRepository: _draftRepository,
          tagConfig: _effectiveTagConfig,
          onPolish: _polish,
          onSave: (content, tags, time) async {
            final success = await _appendEntry(type, content, tags, time);
            if (!success) throw Exception('保存失败');
          },
        ),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已补录')));
    await _loadDiary();
  }

  Future<ImageSettings> _loadImageSettings() async {
    try {
      return await _imageSettingsRepository.load();
    } catch (_) {
      return ImageSettings.defaults();
    }
  }

  Future<List<XFile>> _pickImages(ImageSettings settings) {
    final picker = widget.imagePicker;
    if (picker != null) return picker(settings);
    return _systemImagePicker.pickMultiImage(
      maxWidth: settings.maxLongSidePx.toDouble(),
      maxHeight: settings.maxLongSidePx.toDouble(),
      imageQuality: settings.initialQuality,
      limit: 9,
    );
  }

  Future<void> _uploadImages() async {
    if (_hasActiveImageUpload) return;
    setState(() => _quickRecordExpanded = false);
    final settings = await _loadImageSettings();
    final images = await _pickImages(settings);
    if (images.isEmpty || !mounted) return;

    final newItems = images
        .map(
          (image) =>
              ImageUploadItem(id: ApiClient.generateUuidV4(), file: image),
        )
        .toList();
    setState(() => _imageUploads.addAll(newItems));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _uploadImageQueue(newItems, settings);
    });
  }

  bool get _hasActiveImageUpload => _imageUploads.any(
    (item) =>
        item.status == ImageUploadStatus.preparing ||
        item.status == ImageUploadStatus.uploading,
  );

  Future<void> _uploadImageQueue(
    List<ImageUploadItem> items,
    ImageSettings settings,
  ) async {
    var uploadedImages = 0;
    Object? uploadError;

    for (final item in items) {
      if (!mounted || !_imageUploads.contains(item)) continue;
      try {
        await _uploadImage(item, settings);
        uploadedImages++;
      } catch (error) {
        uploadError = error;
        break;
      }
    }

    if (!mounted) return;
    if (uploadedImages > 0) {
      await _loadDiary();
      if (!mounted) return;
      setState(
        () => _imageUploads.removeWhere(
          (item) => item.status == ImageUploadStatus.success,
        ),
      );
    }

    final message = uploadError == null
        ? '已补录 $uploadedImages 张相片'
        : '已成功 $uploadedImages 张，第 ${uploadedImages + 1} 张失败：'
              '${_uploadErrorMessage(uploadError)}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _uploadImage(
    ImageUploadItem item,
    ImageSettings settings,
  ) async {
    setState(() {
      item.status = ImageUploadStatus.preparing;
      item.sentBytes = 0;
      item.totalBytes = 0;
      item.errorMessage = null;
    });

    try {
      final bytes = await item.file.readAsBytes();
      final compressor = ImageCompressService.fromSettings(settings);
      final base64 =
          await (widget.imageCompressor?.call(bytes, settings) ??
              compressor.compressToBase64InBackground(bytes));
      if (base64.length > ReadOnlyDiaryScreen.maxImageUploadPayloadChars) {
        throw Exception('图片压缩后仍过大，请在图片设置中降低尺寸或质量');
      }
      if (!_diaryReadyForImageUpload) {
        _diaryReadyForImageUpload = await widget.apiClient.ensureDiary(
          widget.date,
        );
        if (!_diaryReadyForImageUpload) {
          throw Exception('无法创建这一天的日记');
        }
      }
      await widget.apiClient.uploadImage(
        widget.date,
        base64,
        operationId: item.id,
        imagePrefix: settings.filenamePrefix,
        onProgress: (sentBytes, totalBytes) {
          if (!mounted || !_imageUploads.contains(item)) return;
          setState(() {
            item.status = ImageUploadStatus.uploading;
            item.sentBytes = sentBytes;
            item.totalBytes = totalBytes;
          });
        },
      );
      if (mounted) setState(() => item.status = ImageUploadStatus.success);
    } catch (error) {
      if (mounted) {
        setState(() {
          item.status = ImageUploadStatus.failed;
          item.errorMessage = _uploadErrorMessage(error);
        });
      }
      rethrow;
    }
  }

  Future<void> _retryImageUpload(ImageUploadItem item) async {
    if (_hasActiveImageUpload || item.status != ImageUploadStatus.failed) {
      return;
    }
    final startIndex = _imageUploads.indexOf(item);
    if (startIndex < 0) return;
    final pendingItems = _imageUploads
        .skip(startIndex)
        .where(
          (candidate) =>
              candidate.status == ImageUploadStatus.selected ||
              candidate.status == ImageUploadStatus.failed,
        )
        .toList();
    await _uploadImageQueue(pendingItems, await _loadImageSettings());
  }

  void _removeImageUpload(ImageUploadItem item) {
    if (item.status != ImageUploadStatus.selected &&
        item.status != ImageUploadStatus.failed) {
      return;
    }
    setState(() => _imageUploads.remove(item));
  }

  bool _canRemoveImageUpload(ImageUploadItem item) {
    if (item.status != ImageUploadStatus.failed) return true;
    final itemIndex = _imageUploads.indexOf(item);
    if (itemIndex < 0) return false;
    return !_imageUploads
        .skip(itemIndex + 1)
        .any((item) => item.status == ImageUploadStatus.selected);
  }

  String _uploadErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? '请重试' : message;
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadDiary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 16),
          if (_error != null && _imageUploads.isEmpty)
            _buildError(theme)
          else if (_diary == null && _imageUploads.isEmpty)
            _buildEmpty(theme)
          else
            DiaryMarkdownView(
              markdown: _diary?.raw ?? '',
              onHabitUpdate: null,
              onEntryDelete: null,
              onEntryEdit: null,
              onGenerateCoach: null,
              apiClient: widget.apiClient,
              date: widget.date,
              readOnly: true,
              hiddenSections: const {'tomorrow', 'habits'},
              imageUploads: _imageUploads,
              onImageUploadRetry: _retryImageUpload,
              onImageUploadRemove: _removeImageUpload,
              canRemoveImageUpload: _canRemoveImageUpload,
            ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
          Text('这一天还没有留下记录', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '点击右下角，为这一天补一条。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 12),
          TextButton(onPressed: _loadDiary, child: const Text('重试')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(_dateLabel()),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Theme(
        data: theme.copyWith(canvasColor: theme.scaffoldBackgroundColor),
        child: _buildBody(theme),
      ),
      floatingActionButton: HistoricalQuickRecordFab(
        expanded: _quickRecordExpanded,
        onToggle: () {
          setState(() => _quickRecordExpanded = !_quickRecordExpanded);
        },
        onEntrySelected: _openQuickCapture,
        onImagesSelected: _uploadImages,
      ),
    );
  }
}
