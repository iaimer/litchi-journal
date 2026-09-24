import 'package:flutter/material.dart';

import '../models/tag_config.dart';
import '../theme/app_theme.dart';
import 'flora_icon.dart';
import 'tag_color_helper.dart';

double journalFabSafetyInset(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final bodyTextScale = mediaQuery.textScaler.scale(16) / 16;
  final compactLargeText = mediaQuery.size.width <= 360 && bodyTextScale > 1.15;
  return compactLargeText ? 72 : 0;
}

class JournalSection extends StatelessWidget {
  final String title;
  final Color accentColor;
  final List<Widget> children;
  final Widget? trailing;

  const JournalSection({
    super.key,
    required this.title,
    required this.accentColor,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FloraSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const SizedBox(width: 4, height: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: FloraSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ],
        ],
      ),
    );
  }
}

class JournalEntryActionSlot extends StatelessWidget {
  final bool alignToTags;
  final bool busy;
  final VoidCallback? onPressed;

  const JournalEntryActionSlot({
    super.key,
    required this.alignToTags,
    required this.busy,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!busy && onPressed == null) return const SizedBox.shrink();

    final alignment = alignToTags ? Alignment.topCenter : Alignment.center;
    if (busy) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: alignToTags
                ? const EdgeInsets.only(top: 6)
                : EdgeInsets.zero,
            child: const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        alignment: alignment,
        padding: alignToTags ? const EdgeInsets.only(top: 4) : EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        iconSize: 16,
        tooltip: '更多操作',
        icon: const FloraIcon(FloraIcons.more, size: 18),
        onPressed: onPressed,
      ),
    );
  }
}

class JournalTimelineRow extends StatelessWidget {
  final String time;
  final String content;
  final List<String> tags;
  final Color accentColor;
  final TagConfig? tagConfig;
  final bool isFirst;

  /// Retained for source compatibility; the rail now always reaches row end.
  final bool isLast;
  final Widget? trailing;
  final Widget? attachment;

  const JournalTimelineRow({
    super.key,
    required this.time,
    required this.content,
    required this.tags,
    required this.accentColor,
    required this.tagConfig,
    this.isFirst = false,
    this.isLast = false,
    this.trailing,
    this.attachment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 4, right: journalFabSafetyInset(context)),
      child: Stack(
        children: [
          Positioned(
            left: 48,
            top: 0,
            bottom: 0,
            width: 8,
            child: _JournalTimelineRail(color: accentColor, isFirst: isFirst),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    time,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(content, style: theme.textTheme.bodyMedium),
                      if (attachment != null) ...[
                        const SizedBox(height: FloraSpacing.sm),
                        attachment!,
                      ],
                      if (tags.isNotEmpty || trailing != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (tags.isNotEmpty)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: TagChipList(
                                    tags: tags,
                                    tagConfig: tagConfig,
                                    moduleAccentColor: accentColor,
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            ?trailing,
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class JournalListEntryRow extends StatelessWidget {
  final String content;
  final List<String> tags;
  final Color accentColor;
  final TagConfig? tagConfig;
  final bool showBullet;
  final Widget? trailing;
  final Widget? attachment;

  const JournalListEntryRow({
    super.key,
    required this.content,
    required this.tags,
    required this.accentColor,
    required this.tagConfig,
    this.showBullet = false,
    this.trailing,
    this.attachment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 4,
        top: 4,
        right: journalFabSafetyInset(context),
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBullet)
            SizedBox(
              width: 20,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '•',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accentColor,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content, style: theme.textTheme.bodyMedium),
                if (attachment != null) ...[
                  const SizedBox(height: FloraSpacing.sm),
                  attachment!,
                ],
                if (tags.isNotEmpty || trailing != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tags.isNotEmpty)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: TagChipList(
                              tags: tags,
                              tagConfig: tagConfig,
                              moduleAccentColor: accentColor,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      ?trailing,
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalTimelineRail extends StatelessWidget {
  final Color color;
  final bool isFirst;

  const _JournalTimelineRail({required this.color, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: isFirst ? 11 : 0,
            left: 3,
            width: 1,
            bottom: 0,
            child: ColoredBox(color: color.withAlpha(88)),
          ),
          Positioned(
            top: 7,
            left: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox(width: 8, height: 8),
            ),
          ),
        ],
      ),
    );
  }
}
