import 'package:flutter/material.dart';

import 'flora_icon.dart';

import '../models/diary_document.dart';
import '../models/focus_timer.dart';
import '../models/habit_settings.dart';
import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../services/api_client.dart';
import '../services/markdown_parser.dart';
import '../theme/app_theme.dart';
import 'anxiety_card.dart';
import 'diary_section_title.dart';
import 'entry_type.dart';
import 'generic_section_card.dart';
import 'habit_card.dart';
import 'image_section_card.dart';
import 'journal_section.dart';
import 'quick_note_timeline.dart';
import 'review_card.dart';
import 'tag_color_helper.dart';
import '../screens/quick_capture_screen.dart';

class DiaryMarkdownView extends StatelessWidget {
  final String markdown;
  final Future<bool> Function(HabitStatus)? onHabitUpdate;
  final Future<void> Function(String sectionKey, String rawLine)? onEntryDelete;
  final Future<void> Function(
    String sectionKey,
    String rawLine,
    String content,
    List<String> tags,
    String time,
  )?
  onEntryEdit;
  final Future<void> Function(
    String sectionKey,
    String rawLine,
    String content,
    List<String> tags,
    String time,
    String? entryId,
  )?
  onEntryEditWithEntryId;
  final Future<void> Function()? onEntryEditCompleted;
  final Future<PolishResult> Function(String content, EntryType entryType)?
  onEntryPolish;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;
  final ApiClient? apiClient;
  final DateTime? date;
  final VoidCallback? onGenerateCoach;
  final bool generatingCoach;
  final bool readOnly;
  final Set<String> hiddenSections;

  /// 活跃习惯 key 集合（null = 显示全部）
  final Set<String>? activeHabitKeys;

  /// 习惯设置（用于自定义显示名称和图标）
  final HabitSettings? habitSettings;

  /// 自定义 checkbox 习惯状态变化回调。
  final Future<bool> Function(HabitStatus status, Map<String, bool> states)?
  onCustomCheckboxToggle;

  /// 正向习惯操作保存成功后的完成反馈。
  final VoidCallback? onPositiveFeedback;
  final Future<bool> Function(List<int> amounts)? onWaterQuickAmountsChanged;
  final Future<bool> Function(HabitTimerTarget target)? onStartDuration;
  final Future<bool> Function(
    HabitTimerTarget target,
    int minutes,
    bool replace,
  )?
  onDurationUpdate;
  final Future<bool> Function(
    HabitStatus status,
    Map<String, bool> checkboxStates,
    Map<String, int> durationStates,
  )?
  onCustomDurationUpdate;
  final QuickCaptureImagePicker? imagePicker;
  final QuickCaptureImageCompressor? imageCompressor;

  const DiaryMarkdownView({
    super.key,
    required this.markdown,
    this.onHabitUpdate,
    this.onEntryDelete,
    this.onEntryEdit,
    this.onEntryEditWithEntryId,
    this.onEntryEditCompleted,
    this.onEntryPolish,
    this.tagConfig,
    this.tagSettings,
    this.apiClient,
    this.date,
    this.onGenerateCoach,
    this.generatingCoach = false,
    this.readOnly = false,
    this.hiddenSections = const {},
    this.activeHabitKeys,
    this.habitSettings,
    this.onCustomCheckboxToggle,
    this.onPositiveFeedback,
    this.onWaterQuickAmountsChanged,
    this.onStartDuration,
    this.onDurationUpdate,
    this.onCustomDurationUpdate,
    this.imagePicker,
    this.imageCompressor,
  });

  @override
  Widget build(BuildContext context) {
    final document = const MarkdownParser().parse(markdown);
    final canGenerateCoach = !readOnly && onGenerateCoach != null;
    final canShowHabitFallback = !readOnly && onHabitUpdate != null;
    if (document.isEmpty && !canGenerateCoach && !canShowHabitFallback) {
      return const SizedBox.shrink();
    }

    final widgets = <Widget>[];
    final preamble = GenericDiarySection(
      title: '',
      contents: document.preamble,
    );

    if (!preamble.isEmpty) {
      widgets.add(
        GenericSectionCard(
          section: preamble,
          accentColor: _accentColorFor(preamble),
          tagConfig: tagConfig,
          tagSettings: tagSettings,
        ),
      );
    }

    var hasCoachSection = false;
    var hasHabitSection = false;
    for (final section in document.sections) {
      if (section is HabitSection) hasHabitSection = true;
      if (_isHiddenSection(section)) continue;
      if (section is CoachSection) hasCoachSection = true;
      if (section.isEmpty &&
          (section is! CoachSection || readOnly || onGenerateCoach == null)) {
        continue;
      }
      widgets.add(_buildSection(section, context));
    }

    final fallbackHabitSection = HabitSection.empty();
    if (canShowHabitFallback &&
        !hasHabitSection &&
        !_isHiddenSection(fallbackHabitSection)) {
      widgets.add(_buildSection(fallbackHabitSection, context));
    }

    if (canGenerateCoach && !hasCoachSection) {
      widgets.add(
        _buildCoachCard(
          const CoachSection(title: '今日回顾', contents: []),
          context,
        ),
      );
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  bool _isHiddenSection(DiarySection section) {
    if (hiddenSections.isEmpty) return false;
    final type = section.sectionType;
    final normalized = hiddenSections.map((s) => s.toLowerCase()).toSet();

    final hideHabit =
        normalized.contains('habit') ||
        normalized.contains('habits') ||
        hiddenSections.contains('习惯追踪') ||
        hiddenSections.contains('习惯打卡');
    if (type == 'habit' && hideHabit) return true;

    final hideTomorrow =
        normalized.contains('tomorrow') || hiddenSections.contains('明日寄语');
    if (type == 'tomorrow' && hideTomorrow) return true;

    return false;
  }

  Widget _buildSection(DiarySection section, BuildContext context) {
    switch (section) {
      case HabitSection():
        return HabitCard(
          key: const ValueKey('habit_card'),
          section: section,
          onUpdate: onHabitUpdate ?? (_) async => true,
          readOnly: readOnly,
          activeHabitKeys: activeHabitKeys,
          habitSettings: habitSettings,
          onCustomCheckboxToggle: onCustomCheckboxToggle,
          onPositiveFeedback: onPositiveFeedback,
          onWaterQuickAmountsChanged: onWaterQuickAmountsChanged,
          onStartDuration: onStartDuration,
          onDurationUpdate: onDurationUpdate,
          onCustomDurationUpdate: onCustomDurationUpdate,
          diaryDate: date,
        );
      case QuickNoteSection():
        final accentColor = _accentColorFor(section);
        return TagChipModuleAccent(
          accentColor: accentColor,
          child: QuickNoteTimeline(
            section: section,
            accentColor: accentColor,
            onDelete: onEntryDelete != null
                ? (note) => onEntryDelete!('quick_notes', note.rawLine)
                : null,
            onEdit: onEntryEdit != null
                ? (note, content, tags, time) => onEntryEdit!(
                    'quick_notes',
                    note.rawLine,
                    content,
                    tags,
                    time,
                  )
                : null,
            onEditWithEntryId: onEntryEditWithEntryId != null
                ? (note, content, tags, time, entryId) =>
                      onEntryEditWithEntryId!(
                        'quick_notes',
                        note.rawLine,
                        content,
                        tags,
                        time,
                        entryId,
                      )
                : null,
            onEditCompleted: onEntryEditCompleted,
            tagConfig: tagConfig,
            tagSettings: tagSettings,
            recordDate: date,
            onPolish: onEntryPolish,
            apiClient: apiClient,
            imagePicker: imagePicker,
            imageCompressor: imageCompressor,
          ),
        );
      case AnxietySection():
        return AnxietyCard(
          section: section,
          accentColor: _accentColorFor(section),
        );
      case HappinessSection():
        return GenericSectionCard(
          section: section,
          accentColor: _accentColorFor(section),
          onTimelineDelete: onEntryDelete != null
              ? (rawLine) => onEntryDelete!('happiness', rawLine)
              : null,
          onTimelineEdit: onEntryEdit != null
              ? (rawLine, content, tags, time) =>
                    onEntryEdit!('happiness', rawLine, content, tags, time)
              : null,
          onTimelineEditWithEntryId: onEntryEditWithEntryId != null
              ? (rawLine, content, tags, time, entryId) =>
                    onEntryEditWithEntryId!(
                      'happiness',
                      rawLine,
                      content,
                      tags,
                      time,
                      entryId,
                    )
              : null,
          onTimelineEditCompleted: onEntryEditCompleted,
          tagConfig: tagConfig,
          tagSettings: tagSettings,
          recordDate: date,
          onPolish: onEntryPolish,
          apiClient: apiClient,
          imagePicker: imagePicker,
          imageCompressor: imageCompressor,
        );
      case ReviewSection():
        return ReviewCard(
          section: section,
          accentColor: _accentColorFor(section),
          onTimelineDelete: onEntryDelete != null
              ? (rawLine) => onEntryDelete!('reflection', rawLine)
              : null,
          onTimelineEdit: onEntryEdit != null
              ? (rawLine, content, tags, time) =>
                    onEntryEdit!('reflection', rawLine, content, tags, time)
              : null,
          tagConfig: tagConfig,
          tagSettings: tagSettings,
          recordDate: date,
          onPolish: onEntryPolish,
        );
      case CoachSection():
        return _buildCoachCard(section, context);
      case TomorrowSection():
        if (section.contents.any(
          (c) => c is MarkdownContent && c.text.trim().isNotEmpty,
        )) {
          return _buildTomorrowCard(section, context);
        }
        return const SizedBox.shrink();
      case MediaSection():
        return _buildMediaSection(section, context);
      default:
        return GenericSectionCard(
          section: section,
          accentColor: _accentColorFor(section),
        );
    }
  }

  Widget _buildMediaSection(MediaSection section, BuildContext context) {
    if (apiClient != null && date != null) {
      return ImageSectionCard(
        section: section,
        accentColor: _accentColorFor(section),
        apiClient: apiClient!,
        date: date!,
        onDeleteImage: onEntryDelete != null
            ? (rawLine) => onEntryDelete!('images', rawLine)
            : null,
      );
    }
    return GenericSectionCard(
      section: section,
      accentColor: _accentColorFor(section),
    );
  }

  /// 根据 section type 返回模块 accentColor（UI 表现层色值，非模型数据）。
  static Color _accentColorFor(DiarySection section) {
    final rainbowColor = TodayRainbow.forSectionType(section.sectionType);
    if (rainbowColor != null) return rainbowColor;

    switch (section.sectionType) {
      case 'habit':
        return const Color(0xFF6BAED6); // 蓝色（HabitCard 自己覆盖 accentColor）
      default:
        return const Color(0xFFA89F96); // 暖灰：未归类模块
    }
  }

  static String _stripStorageListMarkers(String text) {
    return text
        .split('\n')
        .map((line) {
          var trimmed = line.trimLeft();
          if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
            return trimmed.substring(2);
          }
          return line;
        })
        .join('\n');
  }

  Widget _buildCoachCard(CoachSection section, BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = section.contents.any(
      (c) => c is MarkdownContent && c.text.trim().isNotEmpty,
    );

    final displayTitle = diarySectionDisplayTitle(section);
    final showButton = !readOnly && onGenerateCoach != null;

    final children = <Widget>[];
    for (final c in section.contents) {
      if (c is MarkdownContent && c.text.trim().isNotEmpty) {
        if (c.text.trim().startsWith('<!--')) continue;
        children.addAll(
          _buildCoachContentWidgets(theme, c.text, _accentColorFor(section)),
        );
      }
    }

    final accentColor = _accentColorFor(section);

    return JournalSection(
      title: displayTitle,
      accentColor: accentColor,
      trailing: showButton
          ? TextButton.icon(
              onPressed: generatingCoach ? null : onGenerateCoach,
              style: TextButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.padded,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(48, 48),
              ),
              icon: generatingCoach
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const FloraIcon(FloraIcons.coach, size: 14),
              label: Text(
                generatingCoach ? '生成中...' : (hasContent ? '更新回顾' : '生成回顾'),
                style: const TextStyle(fontSize: 13),
              ),
            )
          : null,
      children: [
        if (children.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(right: journalFabSafetyInset(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        if (!hasContent && !showButton)
          Padding(
            padding: EdgeInsets.only(right: journalFabSafetyInset(context)),
            child: Text(
              '还没有今日回顾',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildCoachContentWidgets(
    ThemeData theme,
    String rawText,
    Color accentColor,
  ) {
    final widgets = <Widget>[];
    // 先做展示层归一化，兼容新旧格式
    final normalizedLines = _normalizeCoachDisplayLines(rawText);
    var hasRenderedLine = false;

    for (final line in normalizedLines) {
      if (line.isEmpty) continue;

      if (_isCoachModuleTitle(line)) {
        final icon = _coachIconForTitle(line);
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: hasRenderedLine ? 16 : 0, bottom: 6),
            child: Row(
              children: [
                FloraIcon(icon!, size: 16, color: accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    line,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        hasRenderedLine = true;
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        );
        hasRenderedLine = true;
      }
    }

    return widgets;
  }

  /// 判断一行是否为人生教练模块标题。
  /// 展示层使用 Flora 图标，不把存储格式中的 emoji 直接显示出来。
  static bool _isCoachModuleTitle(String line) {
    return _coachIconForTitle(line) != null;
  }

  static String? _coachIconForTitle(String line) {
    return switch (line.trim()) {
      '模式识别' => FloraIcons.pin,
      '矛盾指出' => FloraIcons.warning,
      '批判性问题' => FloraIcons.question,
      '甜点' => FloraIcons.reward,
      '暖心鼓励' => FloraIcons.chatFeedback,
      _ => null,
    };
  }

  /// 人生教练展示层归一化。
  /// 将历史旧格式转换为展示用结构，不修改原文。
  ///
  /// 旧格式示例：
  ///   **模式识别**：今天两条线索并行。
  ///   **矛盾指出**：16:07 小宝能独立玩...
  ///   **批判性问题**：你在旁边...
  ///   **甜点**：4岁半能在陌生...
  ///
  /// 新格式示例：
  ///   📌 模式识别
  ///   ⚠️ 矛盾指出
  ///   💬 暖心鼓励
  static List<String> _normalizeCoachDisplayLines(String rawText) {
    final lines = rawText.split('\n');
    final result = <String>[];

    const oldTitlePatterns = <String, String>{
      '模式识别': '模式识别',
      '矛盾指出': '矛盾指出',
      '批判性问题': '批判性问题',
      '甜点': '甜点',
      '暖心鼓励': '暖心鼓励',
    };

    for (var line in lines) {
      line = _stripStorageListMarkers(line).trim();
      if (line.isEmpty) continue;

      final stripped = _stripCoachMarkdownArtifacts(line);
      final titleText = _stripLeadingCoachEmoji(stripped);

      if (_matchOldCoachTitle(titleText, oldTitlePatterns, result)) continue;

      if (_coachIconForTitle(titleText) != null) {
        result.add(titleText);
        continue;
      }

      result.add(stripped);
    }

    return result;
  }

  static String _stripCoachMarkdownArtifacts(String line) {
    return line
        .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
        .replaceAll('**', '')
        .replaceAll('__', '')
        .trim();
  }

  static String _stripLeadingCoachEmoji(String line) {
    var result = line.trim();
    for (final emoji in ['📌', '⚠️', '⚠', '💬', '❓', '🍰']) {
      if (result.startsWith(emoji)) {
        result = result.substring(emoji.length).trim();
        break;
      }
    }
    return result;
  }

  /// 检查一行是否为旧格式人生教练标题。
  /// 匹配成功则向 result 添加模块标题行和可能的正文，返回 true。
  static bool _matchOldCoachTitle(
    String text,
    Map<String, String> patterns,
    List<String> result,
  ) {
    for (final entry in patterns.entries) {
      if (text.startsWith(entry.key)) {
        final afterTitle = text.substring(entry.key.length).trim();
        result.add(entry.value);
        // 如果标题后还有内容（用 ：或 : 分隔），作为正文
        var rest = afterTitle;
        if (rest.startsWith('：') || rest.startsWith(':')) {
          rest = rest.substring(1).trim();
        }
        if (rest.isNotEmpty) {
          result.add(rest);
        }
        return true;
      }
    }
    return false;
  }

  Widget _buildTomorrowCard(TomorrowSection section, BuildContext context) {
    final theme = Theme.of(context);
    final contentTexts = <String>[];
    for (final c in section.contents) {
      if (c is MarkdownContent && c.text.trim().isNotEmpty) {
        if (!c.text.trim().startsWith('<!--')) {
          contentTexts.add(_stripStorageListMarkers(c.text));
        }
      }
    }
    if (contentTexts.isEmpty) return const SizedBox.shrink();

    return JournalSection(
      title: '明日寄语',
      accentColor: _accentColorFor(section),
      children: [
        Padding(
          padding: EdgeInsets.only(right: journalFabSafetyInset(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < contentTexts.length; index++) ...[
                Text(
                  contentTexts[index],
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
                if (index < contentTexts.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
