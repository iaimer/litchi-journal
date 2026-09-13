import 'package:flutter/material.dart';

import '../models/tag_config.dart';
import '../theme/app_theme.dart';
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

class JournalTimelineRow extends StatelessWidget {
  final String time;
  final String content;
  final List<String> tags;
  final Color accentColor;
  final TagConfig? tagConfig;
  final bool isFirst;
  final bool isLast;
  final Widget? trailing;

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 4,
        top: 4,
        right: journalFabSafetyInset(context),
        bottom: 4,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Text(
                time,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            _JournalTimelineRail(
              color: accentColor,
              isFirst: isFirst,
              isLast: isLast,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(content, style: theme.textTheme.bodyMedium),
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
      ),
    );
  }
}

class _JournalTimelineRail extends StatelessWidget {
  final Color color;
  final bool isFirst;
  final bool isLast;

  const _JournalTimelineRail({
    required this.color,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!isFirst)
            Positioned(
              top: 0,
              left: 3,
              width: 1,
              height: 7,
              child: ColoredBox(color: color.withAlpha(88)),
            ),
          if (!isLast)
            Positioned(
              top: 7,
              left: 3,
              width: 1,
              bottom: 0,
              child: ColoredBox(color: color.withAlpha(88)),
            ),
          Positioned(
            top: 3,
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
