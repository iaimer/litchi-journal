import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/flora_dock.dart';
import '../widgets/flora_page_route.dart';
import '../widgets/flora_app_bar.dart';
import '../widgets/flora_origin.dart';

import '../widgets/flora_icon.dart';
import '../widgets/flora_success_snackbar.dart';
import '../widgets/flora_skeleton.dart';

import '../models/default_tag_config.dart';
import '../models/diary_document.dart';
import '../models/diary_entry.dart';
import '../models/focus_timer.dart';
import '../models/habit_settings.dart';
import '../models/polish_result.dart';
import '../models/quick_capture_submission.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../screens/anxiety_screen.dart';
import '../screens/focus_timer_screen.dart';
import '../screens/quick_capture_screen.dart';
import '../screens/settings_page.dart';
import '../services/ai_config_repository.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/draft_repository.dart';
import '../services/entry_line_builder.dart';
import '../services/habit_settings_repository.dart';
import '../services/habit_completion_sound.dart';
import '../services/focus_timer_controller.dart';
import '../services/habit_stats_service.dart';
import '../services/markdown_parser.dart';
import '../services/polisher_service.dart';
import '../services/tag_repository.dart';
import '../services/tag_settings_helper.dart';
import '../services/tag_settings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/anxiety_composer.dart';
import '../widgets/diary_markdown_view.dart';
import '../widgets/diary_date_title.dart';
import '../widgets/entry_type.dart';
import '../widgets/habit_card.dart';
import '../widgets/habit_icon.dart';
import '../widgets/quick_record_backdrop.dart';
import '../widgets/quick_record_fan.dart';
import '../widgets/reading_cache_status.dart';
import '../widgets/flora_error_state.dart';

typedef TodayImagePicker = QuickCaptureImagePicker;
typedef TodayImageCompressor = QuickCaptureImageCompressor;

class HomeScreen extends StatefulWidget {
  final ApiClient apiClient;
  final HabitSettingsRepository? habitSettingsRepo;
  final TodayImagePicker? imagePicker;
  final TodayImageCompressor? imageCompressor;
  final ValueChanged<ApiConfig>? onApiConfigChanged;
  final bool active;

  const HomeScreen({
    super.key,
    required this.apiClient,
    this.habitSettingsRepo,
    this.imagePicker,
    this.imageCompressor,
    this.onApiConfigChanged,
    this.active = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

String buildCoachDiaryContext(String rawDiary) {
  final sections = <String>[];

  void addSection(String title, List<String> items) {
    if (items.isNotEmpty) {
      sections.addAll(['【$title】', ...items]);
    }
  }

  final document = const MarkdownParser().parse(rawDiary);
  for (final section in document.sections) {
    if (section is QuickNoteSection) {
      addSection('随手记', _timelineRawLines(section.contents));
    } else if (section is HappinessSection) {
      addSection('小确幸', _timelineRawLines(section.contents));
    } else if (section is AnxietySection) {
      addSection('焦虑时刻', _anxietyAnswerLines(section.contents));
    } else if (section is ReviewSection) {
      addSection('觉察', _timelineRawLines(section.contents));
    }
  }

  return sections.isEmpty ? '今天暂无日记内容' : sections.join('\n');
}

List<String> _timelineRawLines(List<DiaryContent> contents) {
  return contents
      .whereType<TimelineContent>()
      .map((content) => content.rawLine)
      .where(_isUsableContextLine)
      .toList();
}

List<String> _anxietyAnswerLines(List<DiaryContent> contents) {
  final answers = <String>[];
  for (final content in contents) {
    if (content is MarkdownContent) {
      answers.addAll(AnxietyComposer.parseAnswers(content.text));
    }
  }
  return answers
      .map((answer) => answer.trim())
      .where(_isUsableContextLine)
      .toList();
}

bool _isUsableContextLine(String line) {
  final trimmed = line.trim();
  return trimmed.isNotEmpty &&
      trimmed != '-' &&
      trimmed != '- ' &&
      !trimmed.contains('<!--');
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _diaryLoadTimeout = Duration(seconds: 12);

  DiaryEntry? _diary;
  DateTime? _diaryDate;
  int _diaryRefreshSerial = 0;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _cachedAt;
  bool _verified = false;
  String? _warmedConnection;
  TagConfig? _tagConfig;
  TagSettings? _tagSettings;
  final _draftRepository = DraftRepository();
  final _scrollController = ScrollController();
  final _habitCompletionSound = HabitCompletionSound();
  late final FocusTimerController _focusTimerController;
  bool _generatingCoach = false;
  bool _quickRecordExpanded = false;
  int _menuDismissRevision = 0;
  HabitSettings? _habitSettings;
  Set<String> _activeHabitKeys = const {
    'water',
    'steps',
    'reading',
    'language',
    'supplements',
  };

  /// 自定义 checkbox 习惯的当前状态。
  Map<String, bool> _customCheckboxStates = {};
  Map<String, int> _customDurationStates = {};

  /// 当前设备可用标签、name 替换为 displayName 的 TagConfig。
  /// 用于快速记录入口（新建记录不需要隐藏标签）。
  TagConfig get _effectiveTagConfig {
    final tagConfig = _tagConfig ?? DefaultTagConfig.value;
    if (_tagSettings == null) return tagConfig;
    return TagSettingsHelper.effectiveTagConfig(tagConfig, _tagSettings!);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusTimerController = FocusTimerController();
    unawaited(_focusTimerController.load());
    _habitCompletionSound.preload();
    _loadDiary();
    _loadTagConfig();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = FloraDockScope.maybeOf(context)?.menuDismissRevision ?? 0;
    if (revision == _menuDismissRevision) return;
    _menuDismissRevision = revision;
    // Dock 已执行对应操作；这里只同步收起菜单，不重建首页。
    _quickRecordExpanded = false;
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.apiClient, widget.apiClient)) {
      _diaryRefreshSerial++;
      _diary = null;
      _cachedAt = null;
      _verified = false;
      _loadTagConfig();
      _loadDiary();
    } else if (widget.active && !oldWidget.active) {
      _loadDiary();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.active &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      _loadDiary();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimerController.dispose();
    _scrollController.dispose();
    unawaited(_habitCompletionSound.dispose());
    super.dispose();
  }

  Future<void> _loadTagConfig() async {
    final client = widget.apiClient;
    try {
      final repo = TagRepository(apiClient: widget.apiClient);
      final tagSettingsRepo = TagSettingsRepository();
      final config = await repo.loadTagConfig();
      final settings = await tagSettingsRepo.loadTagSettings(config);
      if (!mounted || !identical(client, widget.apiClient)) return;
      setState(() {
        _tagConfig = config;
        _tagSettings = settings;
      });
    } catch (_) {
      if (!mounted || !identical(client, widget.apiClient)) return;
      setState(() {
        _tagConfig = DefaultTagConfig.value;
        _tagSettings = TagSettings.fromTagConfig(DefaultTagConfig.value);
      });
    }
  }

  Future<void> _loadDiary() async {
    final requestId = ++_diaryRefreshSerial;
    final client = widget.apiClient;
    final date = DateTime.now();
    final hasVisibleContent =
        _diary != null &&
        _diaryDate != null &&
        ApiClient.formatDate(_diaryDate!) == ApiClient.formatDate(date);
    setState(() {
      if (!hasVisibleContent) _diary = null;
      _loading = !hasVisibleContent;
      _refreshing = hasVisibleContent;
      _error = null;
      _verified = false;
      _quickRecordExpanded = false;
    });

    try {
      final settingsRepo =
          widget.habitSettingsRepo ?? HabitSettingsRepository();
      final settings = await settingsRepo.load().timeout(
        const Duration(seconds: 1),
        onTimeout: () => HabitSettings.defaults,
      );
      var diary = await client
          .getDiary(
            date,
            onCached: (cached) {
              if (!mounted ||
                  requestId != _diaryRefreshSerial ||
                  hasVisibleContent) {
                return;
              }
              _showDiary(
                cached.value,
                date,
                settings,
                verified: false,
                updatedAt: cached.updatedAt,
              );
            },
          )
          .timeout(_diaryLoadTimeout);

      if (diary == null) {
        if (!mounted || requestId != _diaryRefreshSerial) return;
        diary = await _createConfirmedMissingDiary(client, date);
      }

      if (!mounted || requestId != _diaryRefreshSerial) return;
      _showDiary(
        diary,
        date,
        settings,
        verified: true,
        updatedAt: DateTime.now(),
      );
      _warmReadingCache(client, date);
    } catch (e) {
      if (!mounted || requestId != _diaryRefreshSerial) return;
      _showDiaryLoadFailure(e);
    }
  }

  Future<DiaryEntry> _createConfirmedMissingDiary(
    ApiClient client,
    DateTime date,
  ) async {
    final created = await client.ensureDiary(date).timeout(_diaryLoadTimeout);
    if (!created) throw const ApiException('今日日记创建失败，请重试');
    final diary = await client.getDiary(date).timeout(_diaryLoadTimeout);
    if (diary == null) throw const ApiException('今日日记暂时无法读取，请重试');
    return diary;
  }

  void _showDiary(
    DiaryEntry? diary,
    DateTime date,
    HabitSettings settings, {
    required bool verified,
    required DateTime updatedAt,
  }) {
    setState(() {
      _diary = diary;
      _diaryDate = date;
      _loading = false;
      _refreshing = !verified;
      _verified = verified && diary != null;
      _cachedAt = updatedAt;
      _habitSettings = settings;
      _activeHabitKeys = settings.activeKeys.toSet();
      _customCheckboxStates = _readCustomCheckboxStates(diary, settings);
      _customDurationStates = _readCustomDurationStates(diary, settings);
    });
  }

  void _showDiaryLoadFailure(Object error) {
    setState(() {
      if (error is ApiException && error.isAuthenticationFailure) {
        _diary = null;
        _cachedAt = null;
        _error = '认证失败，请检查连接设置后重试';
      } else {
        _error = _diary == null ? '此日记尚未缓存，连接服务器后可查看' : null;
      }
      _loading = false;
      _refreshing = false;
    });
  }

  void _warmReadingCache(ApiClient client, DateTime date) {
    if (_warmedConnection == client.readingCacheNamespace) return;
    _warmedConnection = client.readingCacheNamespace;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(client, widget.apiClient)) {
        unawaited(client.warmRecentDiaries(date));
      }
    });
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

  Map<String, bool> _readCustomCheckboxStates(
    DiaryEntry? diary,
    HabitSettings settings,
  ) {
    if (diary == null || diary.raw.isEmpty) return {};

    final document = const MarkdownParser().parse(diary.raw);
    HabitSection? habitSection;
    for (final section in document.sections) {
      if (section is HabitSection) {
        habitSection = section;
        break;
      }
    }
    if (habitSection == null) return {};

    final states = <String, bool>{};
    for (final item in habitSection.habits) {
      if (item.habitKey != null) continue;
      final key = settings.customHabitKeyForLabel(item.label);
      if (key != null) states[key] = item.checked;
    }
    return states;
  }

  Map<String, int> _readCustomDurationStates(
    DiaryEntry? diary,
    HabitSettings settings,
  ) {
    if (diary == null || diary.raw.isEmpty) return {};
    final document = const MarkdownParser().parse(diary.raw);
    for (final section in document.sections) {
      if (section is! HabitSection) continue;
      final states = <String, int>{};
      for (final item in section.habits) {
        if (item.habitKey != null || item.kind != HabitKind.duration) continue;
        final key = settings.customHabitKeyForLabel(item.label);
        if (key != null) states[key] = item.value ?? 0;
      }
      return states;
    }
    return {};
  }

  Future<void> _loadDiarySilently() async {
    final requestId = ++_diaryRefreshSerial;
    try {
      final diary = await widget.apiClient.getDiary(_activeDate);
      if (!mounted || requestId != _diaryRefreshSerial) return;
      // 日记内容更新后清除习惯统计日缓存，避免显示旧数据
      HabitStatsService.clearDayCache();
      setState(() {
        _diary = diary;
        _verified = diary != null;
        _cachedAt = DateTime.now();
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestId != _diaryRefreshSerial) return;
      setState(() {
        _verified = false;
        if (error is ApiException && error.isAuthenticationFailure) {
          _diary = null;
          _cachedAt = null;
          _error = '认证失败，请检查连接设置后重试';
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存，但刷新失败')));
    }
  }

  Future<bool> _appendEntry(
    EntryType type,
    DateTime date,
    String content,
    List<String> tags, {
    String? time,
    String? entryId,
    String? operationId,
  }) async {
    Future<bool> call() {
      switch (type) {
        case EntryType.quickNote:
          return widget.apiClient.appendQuickNote(
            date,
            content,
            tags: tags,
            time: time,
            entryId: entryId,
            operationId: operationId,
          );
        case EntryType.reflection:
          return widget.apiClient.appendReflection(
            date,
            content,
            tags: tags,
            time: time,
          );
        case EntryType.happiness:
          return widget.apiClient.appendHappiness(
            date,
            content,
            tags: tags,
            time: time,
            entryId: entryId,
            operationId: operationId,
          );
        case EntryType.anxiety:
          return widget.apiClient.appendAnxiety(
            date,
            content,
            tags: tags,
            time: time,
          );
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
      final ok = await _updateHabitsAPI(status);
      if (ok && mounted) _loadDiarySilently();
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _handleWaterQuickAmountsChanged(List<int> amounts) async {
    try {
      final values = [...amounts]..sort();
      if (values.length != 3 ||
          values.toSet().length != 3 ||
          values.any(
            (value) => value <= 0 || value > HabitSettings.maxCounterTarget,
          )) {
        return false;
      }
      final settings = (_habitSettings ?? HabitSettings.defaults).copyWith(
        waterQuickAmounts: values,
      );
      final repo = widget.habitSettingsRepo ?? HabitSettingsRepository();
      await repo.save(settings);
      if (!mounted) return true;
      setState(() => _habitSettings = settings);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _updateHabitsAPI(
    HabitStatus status, {
    Map<String, bool>? customStates,
    Map<String, int>? durationStates,
  }) async {
    if (!_verified) return false;
    return widget.apiClient.updateHabits(
      _activeDate,
      water: status.water,
      steps: status.steps,
      reading: status.reading,
      language: status.language,
      supplements: status.supplements,
      extraCheckboxes: _buildExtraCheckboxes(customStates),
      readingMinutes: status.readingMinutes > 0 ? status.readingMinutes : null,
      languageMinutes: status.languageMinutes > 0
          ? status.languageMinutes
          : null,
      extraDurations: _buildExtraDurations(durationStates),
    );
  }

  Future<bool> _handleCustomCheckboxToggle(
    HabitStatus status,
    Map<String, bool> states,
  ) async {
    try {
      final ok = await _updateHabitsAPI(status, customStates: states);
      if (ok) {
        _customCheckboxStates = Map.from(states);
        if (mounted) _loadDiarySilently();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _handleCustomDurationUpdate(
    HabitStatus status,
    Map<String, bool> checkboxStates,
    Map<String, int> durationStates,
  ) async {
    try {
      final ok = await _updateHabitsAPI(
        status,
        customStates: checkboxStates,
        durationStates: durationStates,
      );
      if (ok) {
        _customCheckboxStates = Map.from(checkboxStates);
        _customDurationStates = Map.from(durationStates);
        if (mounted) _loadDiarySilently();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _handleDurationUpdate(
    HabitTimerTarget target,
    int minutes,
    bool replace,
  ) async {
    if (!_verified) return false;
    try {
      final result = await widget.apiClient.updateHabitDuration(
        target.diaryDate,
        habitKey: target.habitKey,
        label: target.markdownLabel,
        rawLine: target.rawLine,
        minutes: minutes,
        replace: replace,
        dailyTargetMinutes: target.dailyTargetMinutes,
      );
      if (result == null) return false;
      if (mounted) _loadDiarySilently();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _handleStartDuration(HabitTimerTarget target) async {
    if (!_verified) return false;
    final current = _focusTimerController.session;
    if (current != null) {
      if (current.habitKey != target.habitKey) return false;
      await _openFocusTimer();
      return true;
    }
    final started = await _focusTimerController.start(target);
    if (!started) return false;
    await _openFocusTimer();
    return true;
  }

  Future<void> _openFocusTimer() async {
    if (!mounted || _focusTimerController.session == null) return;
    await Navigator.of(context).push<bool>(
      FloraPageRoute(
        builder: (_) => FocusTimerScreen(
          controller: _focusTimerController,
          onSave: _saveFocusDuration,
          onPositiveFeedback: _habitCompletionSound.play,
        ),
      ),
    );
  }

  Future<bool> _saveFocusDuration(
    FocusTimerSession session,
    int minutes,
  ) async {
    if (!_verified) return false;
    final result = await widget.apiClient.updateHabitDuration(
      session.diaryDate,
      habitKey: session.habitKey,
      label: session.markdownLabel,
      rawLine: session.rawLine,
      minutes: minutes,
      replace: false,
      dailyTargetMinutes: session.dailyTargetMinutes,
    );
    if (result == null) return false;
    if (mounted) _loadDiarySilently();
    return true;
  }

  Map<String, Map<String, dynamic>> _buildExtraCheckboxes(
    Map<String, bool>? customStates,
  ) {
    final settings = _habitSettings ?? HabitSettings.defaults;
    final states = customStates ?? _customCheckboxStates;
    final result = <String, Map<String, dynamic>>{};
    for (final entry in settings.extraHabits.entries) {
      final key = entry.key;
      if (!settings.isActive(key) ||
          settings.trackingTypeFor(key) == HabitTrackingType.duration) {
        continue;
      }
      result[key] = {
        'checked': states[key] ?? false,
        'label': '📝 ${settings.displayNameFor(key)}',
      };
    }
    return result;
  }

  Map<String, Map<String, dynamic>> _buildExtraDurations(
    Map<String, int>? customStates,
  ) {
    final settings = _habitSettings ?? HabitSettings.defaults;
    final states = customStates ?? _customDurationStates;
    final result = <String, Map<String, dynamic>>{};
    for (final entry in settings.extraHabits.entries) {
      final key = entry.key;
      if (!settings.isActive(key) ||
          settings.trackingTypeFor(key) != HabitTrackingType.duration) {
        continue;
      }
      final minutes = states[key] ?? 0;
      result[key] = {
        'minutes': minutes,
        'label': '📝 ${settings.displayNameFor(key)}',
        'rawLine': _customDurationRawLine(key),
        'checked': _durationIsComplete(settings, key, minutes),
      };
    }
    return result;
  }

  bool _durationIsComplete(HabitSettings settings, String key, int minutes) {
    final target = settings.durationDailyTargetFor(key);
    return target == null ? minutes > 0 : minutes >= target;
  }

  String _customDurationRawLine(String key) {
    final settings = _habitSettings ?? HabitSettings.defaults;
    final names = <String>{
      settings.displayNameFor(key),
      ...(settings.customHabitAliases[key] ?? const <String>[]),
    };
    final raw = _diary?.raw;
    if (raw == null) return '';
    for (final line in raw.split('\n')) {
      if (!line.contains('分钟')) continue;
      if (names.any(line.contains)) return line;
    }
    return '';
  }

  Future<PolishResult> _handlePolish(
    String content,
    EntryType entryType,
  ) async {
    final aiRepo = AIConfigRepository();
    final aiConfig = await aiRepo.loadAIConfig();

    if (!aiConfig.isUsable) {
      throw Exception('润色功能尚未配置，请前往设置');
    }

    if (_tagConfig == null) {
      throw Exception('标签配置暂不可用');
    }

    final service = PolisherService();
    try {
      final result = await service.polish(
        content: content,
        entryType: entryType,
        tagConfig: _effectiveTagConfig,
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
      throw Exception('润色功能尚未配置，请前往设置');
    }

    final service = PolisherService();
    try {
      return await service.polishPlainText(content: content, config: aiConfig);
    } finally {
      service.dispose();
    }
  }

  Future<void> _handleEntryDelete(
    String sectionKey,
    String rawLine, {
    String? expectedRaw,
  }) async {
    final ok = await widget.apiClient.deleteEntry(
      _activeDate,
      section: sectionKey,
      line: rawLine,
      expectedRaw: expectedRaw,
    );
    if (!ok) throw Exception('删除失败');
    if (!mounted) return;
    showFloraSuccessSnackBar(context, '已删除');
    _loadDiarySilently();
  }

  Future<void> _handleEntryEdit(
    String sectionKey,
    String rawLine,
    String content,
    List<String> tags,
    String time, {
    String? entryId,
    String? expectedRaw,
  }) async {
    final replacement = rebuildTimelineLine(
      rawLine: rawLine,
      content: content,
      tags: tags,
      time: time,
    );
    final ok = await widget.apiClient.editEntry(
      _activeDate,
      section: sectionKey,
      target: rawLine,
      replacement: replacement,
      entryId: entryId,
      expectedRaw: expectedRaw,
    );
    if (!ok) throw Exception('更新失败');
    if (!mounted) return;
    showFloraSuccessSnackBar(context, '已更新');
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

  Future<void> _handleQuickCaptureSave(
    EntryType type,
    QuickCaptureSubmission submission,
  ) async {
    final success = await _appendEntry(
      type,
      _activeDate,
      submission.content,
      submission.tags,
      time: submission.time,
      entryId: submission.entryId,
      operationId: submission.operationId,
    );
    if (!success) throw Exception('保存失败');
  }

  Future<void> _handleGenerateCoach() async {
    if (_generatingCoach || _diary == null || _diary!.raw.isEmpty) return;

    setState(() => _generatingCoach = true);

    try {
      final aiRepo = AIConfigRepository();
      final config = await aiRepo.loadAIConfig();
      if (!config.isUsable) throw Exception('今日回顾尚未配置，请前往设置');

      final diaryContext = buildCoachDiaryContext(_diary!.raw);

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
        if (!ok) throw Exception('保存今日回顾失败');

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
      showFloraSuccessSnackBar(context, '今日回顾已保存');
      _loadDiarySilently();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PolisherService.readableCoachError(e))),
      );
    } finally {
      if (mounted) setState(() => _generatingCoach = false);
    }
  }

  DateTime get _activeDate => _diaryDate ?? DateTime.now();

  Widget _buildQuickRecordFab(ThemeData theme) {
    return QuickRecordFan(
      expanded: _quickRecordExpanded,
      mainButtonKey: const Key('quick_record_fab'),
      tooltip: '快速记录',
      onToggle: () {
        setState(() => _quickRecordExpanded = !_quickRecordExpanded);
      },
      actions: [
        QuickRecordFanAction(
          icon: const FloraIcon(FloraIcons.fabWrite, size: 19),
          title: '随手记',
          key: const Key('quick_record_quick_note'),
          angleDegrees: 180,
          onTap: () => _selectQuickEntry(EntryType.quickNote),
        ),
        QuickRecordFanAction(
          icon: const FloraIcon(FloraIcons.fabInsight, size: 19),
          title: '觉察',
          key: const Key('quick_record_reflection'),
          angleDegrees: 155,
          onTap: () => _selectQuickEntry(EntryType.reflection),
        ),
        QuickRecordFanAction(
          icon: const FloraIcon(FloraIcons.fabHappy, size: 19),
          title: '小确幸',
          key: const Key('quick_record_happiness'),
          angleDegrees: 130,
          onTap: () => _selectQuickEntry(EntryType.happiness),
        ),
        QuickRecordFanAction(
          icon: const FloraIcon(FloraIcons.fabAnxiety, size: 19),
          title: '焦虑四问',
          key: const Key('quick_record_anxiety'),
          angleDegrees: 105,
          onTap: () => _selectQuickEntry(EntryType.anxiety),
        ),
      ],
    );
  }

  void _selectQuickEntry(EntryType type) {
    if (type == EntryType.anxiety) {
      setState(() => _quickRecordExpanded = false);
      _openAnxietyCapture();
      return;
    }

    setState(() => _quickRecordExpanded = false);
    _openQuickCapture(type);
  }

  Future<void> _openAnxietyCapture() async {
    final saved = await Navigator.of(context).push<bool>(
      FloraPageRoute(
        builder: (_) => AnxietyScreen(
          date: _activeDate,
          draftRepository: _draftRepository,
          initialAnswers: _anxietyInitialAnswers,
          isEdit: _isAnxietyEdit,
          onPolish: _handleAnxietyPolish,
          onSubmit: (content, _) async {
            final success = await _replaceAnxiety(content);
            if (!success) throw Exception('保存失败');
          },
        ),
      ),
    );

    if (!mounted || saved != true) return;
    showFloraSuccessSnackBar(context, '已保存');
    _loadDiarySilently();
  }

  Future<void> _openQuickCapture(EntryType type) async {
    final result = await Navigator.of(context).push<QuickCaptureResult>(
      FloraPageRoute(
        builder: (_) => QuickCaptureScreen(
          entryType: type,
          openedAt: DateTime.now(),
          tagConfig: _effectiveTagConfig,
          apiClient: widget.apiClient,
          photoDate: _activeDate,
          imagePicker: widget.imagePicker,
          imageCompressor: widget.imageCompressor,
          onPolish: _handlePolish,
          onSave: (submission) {
            return _handleQuickCaptureSave(type, submission);
          },
        ),
      ),
    );

    if (!mounted || result == null || result == QuickCaptureResult.discarded) {
      return;
    }
    if (result == QuickCaptureResult.saved) {
      showFloraSuccessSnackBar(context, '已保存');
    }
    _loadDiarySilently();
  }

  Widget _buildFocusTimerStrip(ThemeData theme) {
    return AnimatedBuilder(
      animation: _focusTimerController,
      builder: (context, _) {
        final session = _focusTimerController.session;
        if (session == null) return const SizedBox.shrink();
        final color = Color(session.colorArgb);
        final seconds = _focusTimerController.elapsedSeconds();
        final hours = seconds ~/ 3600;
        final minutes = (seconds % 3600) ~/ 60;
        final rest = seconds % 60;
        final elapsed =
            '${hours.toString().padLeft(2, '0')}'
            ':${minutes.toString().padLeft(2, '0')}'
            ':${rest.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            button: true,
            label: '继续${session.displayName}专注，已计时 $elapsed',
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(FloraRadius.md),
              child: FloraInkWell(
                onTap: _openFocusTimer,
                borderRadius: BorderRadius.circular(FloraRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      HabitIcon(session.icon, size: 19, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        elapsed,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      FloraIcon(
                        FloraIcons.chevronRight,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeLoading() {
    return FloraSkeletonRegion(
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, _headerInset + 16, 16, 96),
        children: [
          const FloraSkeletonBox(width: 180, height: 16),
          const SizedBox(height: 24),
          FloraSkeletonBox(
            width: double.infinity,
            height: 18,
            radius: FloraRadius.md,
          ),
          const SizedBox(height: 12),
          FloraSkeletonBox(
            width: double.infinity,
            height: 18,
            radius: FloraRadius.md,
          ),
          const SizedBox(height: 12),
          FloraSkeletonBox(
            width: MediaQuery.sizeOf(context).width * 0.68,
            height: 18,
            radius: FloraRadius.md,
          ),
          const SizedBox(height: 28),
          FloraSkeletonBox(
            width: double.infinity,
            height: 64,
            radius: FloraRadius.md,
          ),
          const SizedBox(height: 12),
          FloraSkeletonBox(
            width: double.infinity,
            height: 64,
            radius: FloraRadius.md,
          ),
        ],
      ),
    );
  }

  double get _headerInset =>
      CompactDiaryDateTitle.preferredToolbarHeight(context, _activeDate) +
      MediaQuery.paddingOf(context).top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourceRaw = _diary?.raw;
    return PopScope<void>(
      canPop: !_quickRecordExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _quickRecordExpanded) {
          setState(() => _quickRecordExpanded = false);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FloraAppBar(
          glassBackground: true,
          toolbarHeight: CompactDiaryDateTitle.preferredToolbarHeight(
            context,
            _activeDate,
          ),
          centerTitle: false,
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: CompactDiaryDateTitle(date: _activeDate),
          actions: [
            IconButton(
              icon: const FloraIcon(FloraIcons.settings, size: 24),
              onPressed: () async {
                if (_quickRecordExpanded) {
                  setState(() => _quickRecordExpanded = false);
                }
                await Navigator.of(context).push(
                  FloraPageRoute(
                    builder: (_) => SettingsPage(
                      apiConfig: ApiConfig(
                        baseUrl: widget.apiClient.baseUrl,
                        token: '',
                      ),
                      apiClient: widget.apiClient,
                      tokenConfigured: widget.apiClient.hasToken,
                      onApiConfigChanged: widget.onApiConfigChanged,
                    ),
                  ),
                );
                // 从设置页返回后，重新加载标签设置和习惯设置
                await _loadTagConfig();
                _reloadHabitSettings();
                if (mounted) _loadDiary();
              },
            ),
          ],
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        floatingActionButton: ExcludeSemantics(
          excluding: !_verified,
          child: IgnorePointer(
            ignoring: !_verified,
            child: Opacity(
              opacity: _verified ? 1 : 0.4,
              child: _buildQuickRecordFab(theme),
            ),
          ),
        ),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        floatingActionButtonLocation: FloraDockScope.maybeOf(context) == null
            ? FloatingActionButtonLocation.endFloat
            : FloraDockFabLocation(FloraDockScope.maybeOf(context)!.fabBottom),
        body: SafeArea(
          top: false,
          bottom: false,
          child: QuickRecordBackdrop(
            expanded: _quickRecordExpanded,
            bannerBottom: _headerInset,
            onDismiss: () => setState(() => _quickRecordExpanded = false),
            child: _loading
                ? _buildHomeLoading()
                : Theme(
                    data: theme.copyWith(
                      canvasColor: theme.scaffoldBackgroundColor,
                    ),
                    child: RefreshIndicator(
                      onRefresh: _loadDiary,
                      edgeOffset: _headerInset,
                      child: ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          _headerInset,
                          16,
                          FloraDockScope.maybeOf(context)?.clearance ?? 0,
                        ),
                        children: [
                          if (_refreshing)
                            const SizedBox(
                              height: 2,
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          const SizedBox(height: 16),
                          if (!_verified && _diary != null)
                            ReadingCacheStatus(
                              updatedAt: _cachedAt,
                              refreshing: _refreshing,
                              onRetry: _loadDiary,
                            ),
                          _buildFocusTimerStrip(theme),
                          if (_diary?.raw.isNotEmpty == true) ...[
                            DiaryMarkdownView(
                              readOnly: !_verified,
                              showTodayPlaceholders: true,
                              markdown: _diary?.raw ?? '',
                              onHabitUpdate: _handleHabitUpdate,
                              onEntryDelete: _verified
                                  ? (section, line) => _handleEntryDelete(
                                      section,
                                      line,
                                      expectedRaw: sourceRaw,
                                    )
                                  : null,
                              onEntryEdit: !_verified
                                  ? null
                                  : (section, line, content, tags, time) =>
                                        _handleEntryEdit(
                                          section,
                                          line,
                                          content,
                                          tags,
                                          time,
                                          expectedRaw: sourceRaw,
                                        ),
                              onEntryEditWithEntryId: !_verified
                                  ? null
                                  : (
                                      section,
                                      rawLine,
                                      content,
                                      tags,
                                      time,
                                      id,
                                    ) => _handleEntryEdit(
                                      section,
                                      rawLine,
                                      content,
                                      tags,
                                      time,
                                      entryId: id,
                                      expectedRaw: sourceRaw,
                                    ),
                              onEntryEditCompleted: _loadDiarySilently,
                              onEntryPolish: _verified ? _handlePolish : null,
                              tagConfig: _tagConfig,
                              tagSettings: _tagSettings,
                              apiClient: widget.apiClient,
                              date: _activeDate,
                              onGenerateCoach: _handleGenerateCoach,
                              generatingCoach: _generatingCoach,
                              activeHabitKeys: _activeHabitKeys,
                              habitSettings:
                                  _habitSettings ?? HabitSettings.defaults,
                              onCustomCheckboxToggle:
                                  _handleCustomCheckboxToggle,
                              onPositiveFeedback: _habitCompletionSound.play,
                              onWaterQuickAmountsChanged:
                                  _handleWaterQuickAmountsChanged,
                              onStartDuration: _handleStartDuration,
                              onDurationUpdate: _handleDurationUpdate,
                              onCustomDurationUpdate:
                                  _handleCustomDurationUpdate,
                              imagePicker: widget.imagePicker,
                              imageCompressor: widget.imageCompressor,
                            ),
                          ] else if (_error != null) ...[
                            FloraErrorState(
                              message: _error!,
                              onRetry: _loadDiary,
                            ),
                          ] else ...[
                            Text(
                              '今日还没有日记内容',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            HabitCard(
                              readOnly: !_verified,
                              key: const ValueKey('habit_card'),
                              section: HabitSection.empty(),
                              onUpdate: _handleHabitUpdate,
                              activeHabitKeys: _activeHabitKeys,
                              habitSettings:
                                  _habitSettings ?? HabitSettings.defaults,
                              onCustomCheckboxToggle:
                                  _handleCustomCheckboxToggle,
                              onPositiveFeedback: _habitCompletionSound.play,
                              onWaterQuickAmountsChanged:
                                  _handleWaterQuickAmountsChanged,
                              onStartDuration: _handleStartDuration,
                              onDurationUpdate: _handleDurationUpdate,
                              onCustomDurationUpdate:
                                  _handleCustomDurationUpdate,
                              diaryDate: _activeDate,
                            ),
                          ],
                          const SizedBox(height: 96),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
