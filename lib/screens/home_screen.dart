import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/diary_document.dart';
import '../models/diary_entry.dart';
import '../models/habit_settings.dart';
import '../models/image_settings.dart';
import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../screens/settings_page.dart';
import '../services/ai_config_repository.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/draft_repository.dart';
import '../services/entry_line_builder.dart';
import '../services/habit_settings_repository.dart';
import '../services/habit_stats_service.dart';
import '../services/image_compress_service.dart';
import '../services/image_settings_repository.dart';
import '../services/markdown_parser.dart';
import '../services/polisher_service.dart';
import '../services/tag_repository.dart';
import '../services/tag_settings_helper.dart';
import '../services/tag_settings_repository.dart';
import '../widgets/anxiety_composer.dart';
import '../widgets/diary_markdown_view.dart';
import '../widgets/entry_type.dart';
import '../widgets/entry_type_selector.dart';
import '../widgets/quick_note_composer.dart';
import '../widgets/section_card.dart';

class HomeScreen extends StatefulWidget {
  final ApiClient apiClient;
  final HabitSettingsRepository? habitSettingsRepo;
  final Future<void> Function()? imageUploadHandler;

  const HomeScreen({
    super.key,
    required this.apiClient,
    this.habitSettingsRepo,
    this.imageUploadHandler,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DiaryEntry? _diary;
  DateTime? _diaryDate;
  bool _loading = true;
  String? _error;
  TagConfig? _tagConfig;
  TagSettings? _tagSettings;
  bool _tagConfigFailed = false;
  EntryType _selectedEntryType = EntryType.quickNote;
  final _draftRepository = DraftRepository();
  final _imageSettingsRepository = ImageSettingsRepository();
  final _imagePicker = ImagePicker();
  final _scrollController = ScrollController();
  bool _imageUploading = false;
  bool _generatingCoach = false;
  HabitSettings? _habitSettings;
  Set<String> _activeHabitKeys = const {
    'water',
    'steps',
    'reading',
    'language',
    'supplements',
  };

  /// 只含 enabled 标签、name 替换为 displayName 的 TagConfig。
  /// 用于 QuickNoteComposer（新建记录不需要隐藏标签）。
  TagConfig? get _effectiveTagConfig {
    if (_tagConfig == null || _tagSettings == null) return _tagConfig;
    return TagSettingsHelper.effectiveTagConfig(_tagConfig!, _tagSettings!);
  }

  @override
  void initState() {
    super.initState();
    _loadDiary();
    _loadTagConfig();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTagConfig() async {
    try {
      final repo = TagRepository(apiClient: widget.apiClient);
      final tagSettingsRepo = TagSettingsRepository();
      final config = await repo.loadTagConfig();
      final settings = await tagSettingsRepo.loadTagSettings(config);
      if (!mounted) return;
      setState(() {
        _tagConfig = config;
        _tagSettings = settings;
        _tagConfigFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _tagConfigFailed = true);
    }
  }

  Future<void> _loadDiary() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final date = DateTime.now();
      var diary = await widget.apiClient.getDiary(date);

      if (diary == null) {
        await widget.apiClient.ensureDiary(date);
        diary = await widget.apiClient.getDiary(date);
      }

      // 加载习惯设置
      final settingsRepo =
          widget.habitSettingsRepo ?? HabitSettingsRepository();
      final settings = await settingsRepo.load();

      if (!mounted) return;
      setState(() {
        _diary = diary;
        _diaryDate = date;
        _loading = false;
        _habitSettings = settings;
        _activeHabitKeys = settings.activeKeys.toSet();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败';
        _loading = false;
      });
    }
  }

  Future<void> _reloadHabitSettings() async {
    try {
      final settingsRepo =
          widget.habitSettingsRepo ?? HabitSettingsRepository();
      final settings = await settingsRepo.load();
      if (!mounted) return;
      setState(() {
        _habitSettings = settings;
        _activeHabitKeys = settings.activeKeys.toSet();
      });
    } catch (_) {
      // 静默失败，保持现有过滤状态
    }
  }

  Future<void> _loadDiarySilently() async {
    try {
      final diary = await widget.apiClient.getDiary(_activeDate);
      if (!mounted) return;
      // 日记内容更新后清除习惯统计日缓存，避免显示旧数据
      HabitStatsService.clearDayCache();
      setState(() => _diary = diary);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存，但刷新失败')));
    }
  }

  Future<bool> _appendEntry(
    EntryType type,
    DateTime date,
    String content,
    List<String> tags,
  ) async {
    Future<bool> call() {
      switch (type) {
        case EntryType.quickNote:
          return widget.apiClient.appendQuickNote(date, content, tags: tags);
        case EntryType.reflection:
          return widget.apiClient.appendReflection(date, content, tags: tags);
        case EntryType.happiness:
          return widget.apiClient.appendHappiness(date, content, tags: tags);
        case EntryType.anxiety:
          return widget.apiClient.appendAnxiety(date, content, tags: tags);
      }
    }

    var success = await call();
    if (!success) {
      await widget.apiClient.ensureDiary(date);
      success = await call();
    }
    return success;
  }

  Future<bool> _handleHabitUpdate(HabitStatus status) async {
    try {
      final ok = await widget.apiClient.updateHabits(
        _activeDate,
        water: status.water,
        steps: status.steps,
        reading: status.reading,
        language: status.language,
        supplements: status.supplements,
      );
      if (ok && mounted) _loadDiarySilently();
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<PolishResult> _handlePolish(
    String content,
    EntryType entryType,
  ) async {
    final aiRepo = AIConfigRepository();
    final aiConfig = await aiRepo.loadAIConfig();

    if (!aiConfig.isUsable) {
      throw Exception('AI 润色未启用，请在初始设置中配置');
    }

    final tagConfig = _tagConfig;
    if (tagConfig == null) {
      throw Exception('标签配置暂不可用');
    }

    final service = PolisherService();
    try {
      final result = await service.polish(
        content: content,
        entryType: entryType,
        tagConfig: tagConfig,
        config: aiConfig,
        tagSettings: _tagSettings,
      );
      return result;
    } finally {
      service.dispose();
    }
  }

  Future<String> _handleAnxietyPolish(String content) async {
    final aiRepo = AIConfigRepository();
    final aiConfig = await aiRepo.loadAIConfig();

    if (!aiConfig.isUsable) {
      throw Exception('请先在设置中启用并配置 AI 润色');
    }

    final service = PolisherService();
    try {
      return await service.polishPlainText(content: content, config: aiConfig);
    } finally {
      service.dispose();
    }
  }

  Future<void> _handleEntryDelete(String sectionKey, String rawLine) async {
    final ok = await widget.apiClient.deleteEntry(
      _activeDate,
      section: sectionKey,
      line: rawLine,
    );
    if (!ok) throw Exception('删除失败');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已删除')));
    _loadDiarySilently();
  }

  Future<void> _handleEntryEdit(
    String sectionKey,
    String rawLine,
    String content,
    List<String> tags,
  ) async {
    final replacement = rebuildTimelineLine(
      rawLine: rawLine,
      content: content,
      tags: tags,
    );
    final ok = await widget.apiClient.editEntry(
      _activeDate,
      section: sectionKey,
      target: rawLine,
      replacement: replacement,
    );
    if (!ok) throw Exception('更新失败');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已更新')));
    _loadDiarySilently();
  }

  Future<bool> _replaceAnxiety(String content) async {
    var success = await widget.apiClient.replaceAnxiety(_activeDate, content);
    if (!success) {
      await widget.apiClient.ensureDiary(_activeDate);
      success = await widget.apiClient.replaceAnxiety(_activeDate, content);
    }
    return success;
  }

  Future<void> _handleAnxietySubmit(String content, List<String> tags) async {
    final success = await _replaceAnxiety(content);
    if (!success) throw Exception('保存失败');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存')));
    _loadDiarySilently();
  }

  bool get _isAnxietyEdit {
    final answers = _anxietyInitialAnswers;
    return answers != null;
  }

  List<String>? get _anxietyInitialAnswers {
    if (_diary == null || _diary!.raw.isEmpty) return null;

    final document = const MarkdownParser().parse(_diary!.raw);
    final anxietySections = document.sections
        .whereType<AnxietySection>()
        .toList();
    if (anxietySections.isEmpty) return null;
    final anxietySection = anxietySections.first;

    final rawText = anxietySection.contents
        .map((c) => c is MarkdownContent ? c.text : '')
        .join('\n');
    final answers = AnxietyComposer.parseAnswers(rawText);

    final hasRealAnswers = answers.any((a) => a.trim().isNotEmpty);
    return hasRealAnswers ? answers : null;
  }

  Widget _buildAnxietyInput() {
    final isEdit = _isAnxietyEdit;
    final initialAnswers = _anxietyInitialAnswers;
    return AnxietyComposer(
      onSubmit: _handleAnxietySubmit,
      onPolish: _handleAnxietyPolish,
      date: _activeDate,
      draftRepository: _draftRepository,
      initialAnswers: initialAnswers,
      isEdit: isEdit,
      onClose: () {
        setState(() => _selectedEntryType = EntryType.quickNote);
      },
    );
  }

  Future<void> _handleEntrySubmit(String content, List<String> tags) async {
    final success = await _appendEntry(
      _selectedEntryType,
      _activeDate,
      content,
      tags,
    );
    if (!success) throw Exception('保存失败');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存')));
    _loadDiarySilently();
  }

  Future<void> _handleImageUpload() async {
    if (_imageUploading) return;

    final imageSettings = await _loadImageSettings();
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: imageSettings.maxLongSidePx.toDouble(),
      maxHeight: imageSettings.maxLongSidePx.toDouble(),
      imageQuality: imageSettings.initialQuality,
    );
    if (file == null) return;

    setState(() => _imageUploading = true);

    try {
      final bytes = await file.readAsBytes();
      final compressService = ImageCompressService.fromSettings(imageSettings);
      final base64 = compressService.compressToBase64(bytes);

      await widget.apiClient.uploadImage(
        _activeDate,
        base64,
        imagePrefix: imageSettings.filenamePrefix,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已添加照片')));
      _loadDiarySilently();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('上传失败，请重试')));
    } finally {
      if (mounted) setState(() => _imageUploading = false);
    }
  }

  Future<ImageSettings> _loadImageSettings() async {
    try {
      return await _imageSettingsRepository.load();
    } catch (_) {
      return ImageSettings.defaults();
    }
  }

  Future<void> _startImageUpload() async {
    final handler = widget.imageUploadHandler;
    if (handler != null) {
      await handler();
      return;
    }
    await _handleImageUpload();
  }

  Future<void> _handleGenerateCoach() async {
    if (_generatingCoach || _diary == null || _diary!.raw.isEmpty) return;

    setState(() => _generatingCoach = true);

    try {
      final aiRepo = AIConfigRepository();
      final config = await aiRepo.loadAIConfig();
      if (!config.isUsable) throw Exception('请先在设置中启用AI并配置API');

      // Build diary context (same as Web client)
      final sections = <String>[];

      void addSection(String title, List<String> items) {
        if (items.isNotEmpty) {
          sections.addAll(['【$title】', ...items]);
        }
      }

      final document = const MarkdownParser().parse(_diary!.raw);
      for (final section in document.sections) {
        if (section is QuickNoteSection) {
          addSection('随手记', _timelineRawLines(section.contents));
        } else if (section is HappinessSection) {
          addSection('小确幸', _timelineRawLines(section.contents));
        } else if (section is AnxietySection) {
          addSection('焦虑时刻', _markdownLines(section.contents));
        } else if (section is ReviewSection) {
          addSection('觉察', _timelineRawLines(section.contents));
        } else if (section is TomorrowSection) {
          addSection('明日寄语', _markdownLines(section.contents));
        }
      }

      final diaryContext = sections.isEmpty ? '今天暂无日记内容' : sections.join('\n');

      final service = PolisherService();
      try {
        final result = await service.generateCoach(
          diaryContext: diaryContext,
          config: config,
        );
        final parts = PolisherService.splitCoachResultLikeWeb(result);
        final lizhiContent = parts.lizhiContent;
        final actionContent = parts.actionContent;

        if (lizhiContent.isEmpty) {
          throw Exception('生成结果为空，请重试');
        }

        final ok = await widget.apiClient.replaceLizhiSays(
          _activeDate,
          lizhiContent,
        );
        if (!ok) throw Exception('保存人生教练失败');

        if (actionContent.isNotEmpty) {
          final tomorrowOk = await widget.apiClient.replaceTomorrowSection(
            _activeDate,
            actionContent,
          );
          if (!tomorrowOk) throw Exception('保存明日寄语失败');
        }
      } finally {
        service.dispose();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('教练反馈已生成')));
      _loadDiarySilently();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '生成失败: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingCoach = false);
    }
  }

  List<String> _timelineRawLines(List<DiaryContent> contents) {
    return contents
        .whereType<TimelineContent>()
        .map((content) => content.rawLine)
        .where(_isUsableContextLine)
        .toList();
  }

  List<String> _markdownLines(List<DiaryContent> contents) {
    final lines = <String>[];
    for (final content in contents) {
      if (content is MarkdownContent) {
        lines.addAll(content.text.split('\n'));
      }
    }
    return lines.where(_isUsableContextLine).toList();
  }

  bool _isUsableContextLine(String line) {
    final trimmed = line.trim();
    return trimmed.isNotEmpty &&
        trimmed != '-' &&
        trimmed != '- ' &&
        !trimmed.contains('<!--');
  }

  String _todayString() {
    final now = _activeDate;
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${now.year}年${now.month}月${now.day}日 星期${weekdays[now.weekday - 1]}';
  }

  DateTime get _activeDate => _diaryDate ?? DateTime.now();

  Future<void> _showQuickRecordSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('快速记录', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _buildQuickRecordItem(
                    icon: '✍️',
                    title: '随手记',
                    key: const Key('quick_record_quick_note'),
                    onTap: () => _selectQuickEntry(EntryType.quickNote),
                  ),
                  _buildQuickRecordItem(
                    icon: '✨',
                    title: '小确幸',
                    key: const Key('quick_record_happiness'),
                    onTap: () => _selectQuickEntry(EntryType.happiness),
                  ),
                  _buildQuickRecordItem(
                    icon: '💡',
                    title: '觉察',
                    key: const Key('quick_record_reflection'),
                    onTap: () => _selectQuickEntry(EntryType.reflection),
                  ),
                  _buildQuickRecordItem(
                    icon: '😰',
                    title: '焦虑四问',
                    key: const Key('quick_record_anxiety'),
                    onTap: () => _selectQuickEntry(EntryType.anxiety),
                  ),
                  _buildQuickRecordItem(
                    icon: '📸',
                    title: '添加图片',
                    key: const Key('quick_record_image'),
                    onTap: _selectImageUpload,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickRecordItem({
    required String icon,
    required String title,
    required Key key,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      key: key,
      leading: Text(icon, style: const TextStyle(fontSize: 22)),
      title: Text(title, style: theme.textTheme.bodyMedium),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      minLeadingWidth: 28,
      onTap: onTap,
    );
  }

  void _selectQuickEntry(EntryType type) {
    Navigator.of(context).pop();
    setState(() => _selectedEntryType = type);
    _scrollToComposer();
  }

  void _selectImageUpload() {
    Navigator.of(context).pop();
    _startImageUpload();
  }

  void _scrollToComposer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        centerTitle: false,
        title: Text(
          _todayString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    apiConfig: ApiConfig(
                      baseUrl: widget.apiClient.baseUrl,
                      token: '',
                    ),
                    tokenConfigured: widget.apiClient.hasToken,
                  ),
                ),
              );
              // 从设置页返回后，重新加载标签设置和习惯设置
              await _loadTagConfig();
              _reloadHabitSettings();
            },
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        key: const Key('quick_record_fab'),
        tooltip: '快速记录',
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed: _showQuickRecordSheet,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDiary,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_diary != null && _diary!.raw.isNotEmpty) ...[
                    DiaryMarkdownView(
                      markdown: _diary!.raw,
                      onHabitUpdate: _handleHabitUpdate,
                      onEntryDelete: _handleEntryDelete,
                      onEntryEdit: _handleEntryEdit,
                      tagConfig: _tagConfig,
                      tagSettings: _tagSettings,
                      apiClient: widget.apiClient,
                      date: _activeDate,
                      onGenerateCoach: _handleGenerateCoach,
                      generatingCoach: _generatingCoach,
                      activeHabitKeys: _activeHabitKeys,
                      habitSettings: _habitSettings ?? HabitSettings.defaults,
                    ),
                  ] else ...[
                    Text(
                      '今日还没有日记内容',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Card(
                    color: theme.colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '添加照片',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _imageUploading
                                ? null
                                : _startImageUpload,
                            child: _imageUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('选择图片'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: '快速记录',
                    children: [
                      EntryTypeSelector(
                        selected: _selectedEntryType,
                        onChanged: (type) {
                          setState(() => _selectedEntryType = type);
                        },
                      ),
                      const SizedBox(height: 10),
                      if (_selectedEntryType == EntryType.anxiety) ...[
                        _buildAnxietyInput(),
                      ] else
                        KeyedSubtree(
                          key: ValueKey('composer_${_selectedEntryType.name}'),
                          child: QuickNoteComposer(
                            onSubmit: _handleEntrySubmit,
                            onPolish: _handlePolish,
                            date: _activeDate,
                            entryType: _selectedEntryType,
                            draftRepository: _draftRepository,
                            tagConfig: _effectiveTagConfig,
                            tagHint: _tagConfigFailed ? '标签暂不可用' : null,
                            placeholder: _selectedEntryType.placeholder,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 96),
                ],
              ),
            ),
    );
  }
}
