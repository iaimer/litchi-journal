import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/diary_document.dart';
import '../models/diary_entry.dart';
import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../screens/settings_screen.dart';
import '../services/ai_config_repository.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/draft_repository.dart';
import '../services/entry_line_builder.dart';
import '../services/image_compress_service.dart';
import '../services/markdown_parser.dart';
import '../services/polisher_service.dart';
import '../services/tag_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/anxiety_composer.dart';
import '../widgets/diary_markdown_view.dart';
import '../widgets/entry_type.dart';
import '../widgets/entry_type_selector.dart';
import '../widgets/quick_note_composer.dart';
import '../widgets/section_card.dart';

class HomeScreen extends StatefulWidget {
  final ApiClient apiClient;

  const HomeScreen({super.key, required this.apiClient});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DiaryEntry? _diary;
  bool _loading = true;
  String? _error;
  TagConfig? _tagConfig;
  bool _tagConfigFailed = false;
  EntryType _selectedEntryType = EntryType.quickNote;
  final _draftRepository = DraftRepository();
  final _imagePicker = ImagePicker();
  bool _imageUploading = false;
  bool _generatingCoach = false;

  @override
  void initState() {
    super.initState();
    _loadDiary();
    _loadTagConfig();
  }

  Future<void> _loadTagConfig() async {
    try {
      final repo = TagRepository(apiClient: widget.apiClient);
      final config = await repo.loadTagConfig();
      if (!mounted) return;
      setState(() {
        _tagConfig = config;
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

      if (!mounted) return;
      setState(() {
        _diary = diary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败';
        _loading = false;
      });
    }
  }

  Future<void> _loadDiarySilently() async {
    try {
      final diary = await widget.apiClient.getDiary(DateTime.now());
      if (!mounted) return;
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
        DateTime.now(),
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
      DateTime.now(),
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
      DateTime.now(),
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
    var success = await widget.apiClient.replaceAnxiety(
      DateTime.now(),
      content,
    );
    if (!success) {
      await widget.apiClient.ensureDiary(DateTime.now());
      success = await widget.apiClient.replaceAnxiety(DateTime.now(), content);
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
      date: DateTime.now(),
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
      DateTime.now(),
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

    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 70,
    );
    if (file == null) return;

    setState(() => _imageUploading = true);

    try {
      final bytes = await file.readAsBytes();
      final compressService = const ImageCompressService();
      final base64 = compressService.compressToBase64(bytes);

      await widget.apiClient.uploadImage(DateTime.now(), base64);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已添加照片')));
      _loadDiarySilently();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上传失败: $e')));
    } finally {
      if (mounted) setState(() => _imageUploading = false);
    }
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

        if (actionContent.isNotEmpty) {
          final ok = await widget.apiClient.replaceTomorrowSection(
            DateTime.now(),
            actionContent,
          );
          if (!ok) throw Exception('保存明日寄语失败');
        }

        final ok = await widget.apiClient.replaceLizhiSays(
          DateTime.now(),
          lizhiContent,
        );
        if (!ok) throw Exception('保存人生教练失败');
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
    final now = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${now.year}年${now.month}月${now.day}日 星期${weekdays[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        centerTitle: false,
        title: Text(_todayString(), style: theme.textTheme.headlineLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    apiConfig: ApiConfig(
                      baseUrl: widget.apiClient.baseUrl,
                      token: '',
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDiary,
              child: ListView(
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
                      apiClient: widget.apiClient,
                      date: DateTime.now(),
                      onGenerateCoach: _handleGenerateCoach,
                      generatingCoach: _generatingCoach,
                    ),
                  ] else ...[
                    const Text(
                      '今日还没有日记内容',
                      style: TextStyle(color: AppColors.textSecondary),
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
                          const Icon(
                            Icons.add_a_photo_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '添加照片',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _imageUploading
                                ? null
                                : _handleImageUpload,
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
                            date: DateTime.now(),
                            entryType: _selectedEntryType,
                            draftRepository: _draftRepository,
                            tagConfig: _tagConfig,
                            tagHint: _tagConfigFailed ? '标签暂不可用' : null,
                            placeholder: _selectedEntryType.placeholder,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
