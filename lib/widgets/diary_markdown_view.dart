import 'package:flutter/material.dart';

import 'flora_icon.dart';

import '../models/diary_document.dart';
import '../models/habit_settings.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import '../services/api_client.dart';
import '../services/markdown_parser.dart';
import 'anxiety_card.dart';
import 'generic_section_card.dart';
import 'habit_card.dart';
import 'image_section_card.dart';
import 'quick_note_timeline.dart';
import 'review_card.dart';
import 'section_card.dart';

class DiaryMarkdownView extends StatelessWidget {
  final String markdown;
  final Future<bool> Function(HabitStatus)? onHabitUpdate;
  final Future<void> Function(String sectionKey, String rawLine)? onEntryDelete;
  final Future<void> Function(
    String sectionKey,
    String rawLine,
    String content,
    List<String> tags,
  )?
  onEntryEdit;
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
  final Future<bool> Function(Map<String, bool> states)?
      onCustomCheckboxToggle;

  const DiaryMarkdownView({
    super.key,
    required this.markdown,
    this.onHabitUpdate,
    this.onEntryDelete,
    this.onEntryEdit,
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
          const CoachSection(title: '🧠 人生教练', contents: []),
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
        );
      case QuickNoteSection():
        return QuickNoteTimeline(
          section: section,
          onDelete: onEntryDelete != null
              ? (note) => onEntryDelete!('quick_notes', note.rawLine)
              : null,
          onEdit: onEntryEdit != null
              ? (note, content, tags) =>
                    onEntryEdit!('quick_notes', note.rawLine, content, tags)
              : null,
          tagConfig: tagConfig,
          tagSettings: tagSettings,
        );
      case AnxietySection():
        return AnxietyCard(section: section);
      case HappinessSection():
        return GenericSectionCard(
          section: section,
          onTimelineDelete: onEntryDelete != null
              ? (rawLine) => onEntryDelete!('happiness', rawLine)
              : null,
          onTimelineEdit: onEntryEdit != null
              ? (rawLine, content, tags) =>
                    onEntryEdit!('happiness', rawLine, content, tags)
              : null,
          tagConfig: tagConfig,
          tagSettings: tagSettings,
        );
      case ReviewSection():
        return ReviewCard(
          section: section,
          onTimelineDelete: onEntryDelete != null
              ? (rawLine) => onEntryDelete!('reflection', rawLine)
              : null,
          onTimelineEdit: onEntryEdit != null
              ? (rawLine, content, tags) =>
                    onEntryEdit!('reflection', rawLine, content, tags)
              : null,
          tagConfig: tagConfig,
          tagSettings: tagSettings,
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
        if (apiClient != null && date != null) {
          return ImageSectionCard(
            section: section,
            apiClient: apiClient!,
            date: date!,
            onDeleteImage: onEntryDelete != null
                ? (rawLine) => onEntryDelete!('images', rawLine)
                : null,
          );
        }
        return GenericSectionCard(section: section);
      default:
        return GenericSectionCard(section: section);
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

    // 归一化标题：历史旧格式「荔枝喵说」统一显示为「人生教练」
    final displayTitle = _normalizeCoachSectionTitle(section.title);
    final showButton = !readOnly && onGenerateCoach != null;

    final children = <Widget>[];
    for (final c in section.contents) {
      if (c is MarkdownContent && c.text.trim().isNotEmpty) {
        if (c.text.trim().startsWith('<!--')) continue;
        children.addAll(_buildCoachContentWidgets(theme, c.text));
      }
    }

    return SectionCard(
      title: displayTitle,
      trailing: showButton
          ? TextButton.icon(
              onPressed: generatingCoach ? null : onGenerateCoach,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
              icon: generatingCoach
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const FloraIcon(FloraIcons.coach, size: 14),
              label: Text(
                generatingCoach ? '生成中...' : (hasContent ? '重新生成' : '生成今日反馈'),
                style: const TextStyle(fontSize: 13),
              ),
            )
          : null,
      children: hasContent
          ? children
          : (showButton
                ? [const SizedBox.shrink()]
                : [
                    Text(
                      '暂无教练反馈',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ]),
    );
  }

  /// 归一化人生教练 section 标题。
  /// 历史旧标题「荔枝喵说」统一显示为「人生教练」。
  static String _normalizeCoachSectionTitle(String title) {
    if (title.contains('荔枝喵说')) {
      return '🧠 人生教练';
    }
    return title;
  }

  List<Widget> _buildCoachContentWidgets(ThemeData theme, String rawText) {
    final widgets = <Widget>[];
    // 先做展示层归一化，兼容新旧格式
    final normalizedLines = _normalizeCoachDisplayLines(rawText);

    for (final line in normalizedLines) {
      if (line.isEmpty) continue;

      if (_isCoachModuleTitle(line)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              line,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
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
      }
    }

    return widgets;
  }

  /// 判断一行是否为人生教练模块标题。
  /// 支持新格式（📌 模式识别）和旧格式（**模式识别**）。
  static bool _isCoachModuleTitle(String line) {
    return RegExp(r'^[📌⚠️💬❓🍰]\s').hasMatch(line);
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

    // 旧格式模式 → 展示用模块标题
    const oldTitlePatterns = <String, String>{
      '模式识别': '📌 模式识别',
      '矛盾指出': '⚠️ 矛盾指出',
      '批判性问题': '❓ 批判性问题',
      '甜点': '🍰 甜点',
    };

    for (var line in lines) {
      line = _stripStorageListMarkers(line).trim();
      if (line.isEmpty) continue;

      final stripped = _stripCoachMarkdownArtifacts(line);
      final titleText = _stripLeadingCoachEmoji(stripped);

      if (_matchOldCoachTitle(titleText, oldTitlePatterns, result)) continue;

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

    return SectionCard(
      title: section.title,
      accentColor: theme.colorScheme.primary,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contentTexts.map((text) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(text, style: theme.textTheme.bodyMedium),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
