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
  final bool attachmentAboveTags;
  final bool busy;
  final VoidCallback? onPressed;

  const JournalEntryActionSlot({
    super.key,
    required this.alignToTags,
    this.attachmentAboveTags = false,
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
                ? EdgeInsets.only(top: attachmentAboveTags ? 2 : 6)
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
        padding: alignToTags && !attachmentAboveTags
            ? const EdgeInsets.only(top: 4)
            : EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        iconSize: 16,
        tooltip: '更多操作',
        icon: const FloraIcon(FloraIcons.more, size: 18),
        onPressed: onPressed,
      ),
    );
  }
}

class JournalTimelineRow extends StatefulWidget {
  final String time;
  final String content;
  final List<String> tags;
  final Color accentColor;
  final TagConfig? tagConfig;
  final bool isFirst;

  /// The final row ends its rail at the last visible content, not the action slot.
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
  State<JournalTimelineRow> createState() => _JournalTimelineRowState();
}

class _JournalTimelineRowState extends State<JournalTimelineRow> {
  final _stackKey = GlobalKey();
  final _contentKey = GlobalKey();
  final _attachmentKey = GlobalKey();
  final _tagsKey = GlobalKey();
  double? _terminalRailBottom;
  bool _measurementScheduled = false;

  @override
  void didUpdateWidget(JournalTimelineRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLast != widget.isLast ||
        oldWidget.content != widget.content ||
        oldWidget.tags != widget.tags ||
        oldWidget.attachment != widget.attachment) {
      _terminalRailBottom = null;
    }
  }

  GlobalKey get _terminalAnchorKey {
    if (widget.tags.isNotEmpty) return _tagsKey;
    if (widget.attachment != null) return _attachmentKey;
    return _contentKey;
  }

  void _scheduleRailMeasurement() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted || !widget.isLast) return;

      final anchorObject = _terminalAnchorKey.currentContext
          ?.findRenderObject();
      final stackObject = _stackKey.currentContext?.findRenderObject();
      if (anchorObject is! RenderBox || stackObject is! RenderBox) return;

      final bottom = anchorObject
          .localToGlobal(
            Offset(0, anchorObject.size.height),
            ancestor: stackObject,
          )
          .dy;
      if (_terminalRailBottom != null &&
          (_terminalRailBottom! - bottom).abs() < 0.5) {
        return;
      }
      setState(() => _terminalRailBottom = bottom);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLast) _scheduleRailMeasurement();
    return Padding(
      padding: EdgeInsets.only(left: 4, right: journalFabSafetyInset(context)),
      child: Stack(
        key: _stackKey,
        children: [_buildRail(), _buildEntry(Theme.of(context))],
      ),
    );
  }

  Widget _buildRail() => Positioned(
    left: 48,
    top: 0,
    bottom: 0,
    width: 8,
    child: _JournalTimelineRail(
      color: widget.accentColor,
      isFirst: widget.isFirst,
      isLast: widget.isLast,
      terminalBottom: widget.isLast ? _terminalRailBottom : null,
    ),
  );

  Widget _buildEntry(ThemeData theme) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            widget.time,
            style: theme.textTheme.bodySmall?.copyWith(
              color: widget.accentColor,
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
          child: _buildContent(theme),
        ),
      ),
    ],
  );

  Widget _buildContent(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.content, key: _contentKey, style: theme.textTheme.bodyMedium),
      if (widget.attachment != null) ...[
        const SizedBox(height: FloraSpacing.sm),
        KeyedSubtree(key: _attachmentKey, child: widget.attachment!),
        if (widget.tags.isNotEmpty || widget.trailing != null)
          const SizedBox(height: FloraSpacing.md),
      ],
      if (widget.tags.isNotEmpty || widget.trailing != null)
        _buildMetadataRow(),
    ],
  );

  Widget _buildMetadataRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.tags.isNotEmpty)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: widget.attachment == null ? 2 : 0),
            child: TagChipList(
              key: _tagsKey,
              tags: widget.tags,
              tagConfig: widget.tagConfig,
              moduleAccentColor: widget.accentColor,
            ),
          ),
        )
      else
        const Spacer(),
      ?widget.trailing,
    ],
  );
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
          Expanded(child: _buildContent(theme)),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(content, style: theme.textTheme.bodyMedium),
      if (attachment != null) ...[
        const SizedBox(height: FloraSpacing.sm),
        attachment!,
        if (tags.isNotEmpty || trailing != null)
          const SizedBox(height: FloraSpacing.md),
      ],
      if (tags.isNotEmpty || trailing != null) _buildMetadataRow(),
    ],
  );

  Widget _buildMetadataRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (tags.isNotEmpty)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: attachment == null ? 2 : 0),
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
  );
}

class _JournalTimelineRail extends StatelessWidget {
  final Color color;
  final bool isFirst;
  final bool isLast;
  final double? terminalBottom;

  const _JournalTimelineRail({
    required this.color,
    required this.isFirst,
    required this.isLast,
    required this.terminalBottom,
  });

  @override
  Widget build(BuildContext context) {
    final lineTop = isFirst ? 11.0 : 0.0;
    return SizedBox(
      width: 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: lineTop,
            left: 3,
            width: 1,
            bottom: terminalBottom == null && !isLast ? 0 : null,
            height: isLast
                ? terminalBottom == null
                      ? 0
                      : (terminalBottom! - lineTop).clamp(0.0, double.infinity)
                : null,
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
