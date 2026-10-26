import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'flora_origin.dart';
import 'flora_glass.dart';
import 'flora_dock.dart';

import '../theme/app_theme.dart';
import 'flora_icon.dart';

class QuickRecordMenuAction {
  final Widget icon;
  final String title;
  final Key key;
  final VoidCallback onTap;

  const QuickRecordMenuAction({
    required this.icon,
    required this.title,
    required this.key,
    required this.onTap,
  });
}

/// 今天与历史补录共用的竖排入口，只负责展示与转发操作。
class QuickRecordMenu extends StatefulWidget {
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final Key mainButtonKey;
  final String tooltip;
  final List<QuickRecordMenuAction> actions;
  final double topInset;

  const QuickRecordMenu({
    super.key,
    required this.expanded,
    required this.onExpandedChanged,
    required this.mainButtonKey,
    required this.tooltip,
    required this.actions,
    this.topInset = 0,
  });

  @override
  State<QuickRecordMenu> createState() => _QuickRecordMenuState();
}

class _QuickRecordMenuState extends State<QuickRecordMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _skipMotion = false;
  BuildContext? _mainButtonContext;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: widget.expanded ? 1 : 0,
      duration: FloraMotion.standard,
      reverseDuration: FloraMotion.fast,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final skipMotion =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    if (_skipMotion == skipMotion) return;
    _skipMotion = skipMotion;
    _moveToTarget();
  }

  @override
  void didUpdateWidget(covariant QuickRecordMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) _moveToTarget();
  }

  void _moveToTarget() {
    final target = widget.expanded ? 1.0 : 0.0;
    if (_skipMotion) {
      _controller.value = target;
      return;
    }
    final distance = (target - _controller.value).abs();
    final fullDuration = widget.expanded
        ? FloraMotion.standard
        : FloraMotion.fast;
    final duration = Duration(
      microseconds: (fullDuration.inMicroseconds * distance).round(),
    );
    if (duration == Duration.zero) {
      _controller.value = target;
      return;
    }
    // 直接从当前值转向，不切换曲线映射或重置进度，避免中途反转跳位。
    if (widget.expanded) {
      _controller.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOutQuart,
      );
    } else {
      _controller.animateBack(
        target,
        duration: duration,
        curve: Curves.easeOutQuart,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom =
        FloraDockScope.maybeOf(context)?.fabBottom ?? media.padding.bottom + 16;
    final width = math.min(176.0, media.size.width - 32);
    final height = math.max(
      56.0,
      media.size.height -
          bottom -
          math.max(widget.topInset, media.padding.top) -
          8,
    );
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          _buildMainButton(),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _buildMenu(height),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton() => Builder(
    key: const ValueKey('quick_record_main_anchor'),
    builder: (mainContext) {
      _mainButtonContext = mainContext;
      return ExcludeFocus(
        excluding: widget.expanded,
        child: ExcludeSemantics(
          excluding: widget.expanded,
          child: IgnorePointer(
            ignoring: widget.expanded,
            child: Opacity(
              opacity: widget.expanded ? 0 : 1,
              child: FloatingActionButton(
                key: widget.mainButtonKey,
                tooltip: widget.tooltip,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: const CircleBorder(),
                onPressed: widget.expanded
                    ? null
                    : () => widget.onExpandedChanged(true),
                child: const FloraIcon(FloraIcons.add, size: 24),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _buildMenu(double maxHeight) {
    final progress = _controller.value;
    if (!widget.expanded && progress == 0) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: !widget.expanded,
      child: ExcludeFocus(
        excluding: !widget.expanded,
        child: ExcludeSemantics(
          excluding: !widget.expanded,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - progress)),
            child: Opacity(
              opacity: progress,
              child: TapRegion(
                onTapOutside: widget.expanded
                    ? (_) => widget.onExpandedChanged(false)
                    : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: FloraGlassSurface(
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: SingleChildScrollView(
                        primary: false,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.actions.map(_buildAction).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction(QuickRecordMenuAction action) => _MenuActionButton(
    key: action.key,
    action: action,
    enabled: widget.expanded,
    returnContext: () => _mainButtonContext,
  );
}

class _MenuActionButton extends StatelessWidget {
  final QuickRecordMenuAction action;
  final bool enabled;
  final BuildContext? Function() returnContext;

  const _MenuActionButton({
    super.key,
    required this.action,
    required this.enabled,
    required this.returnContext,
  });

  @override
  Widget build(BuildContext context) {
    final onTap = enabled
        ? () => FloraOrigin.run(
            context,
            action.onTap,
            returnContext: returnContext(),
          )
        : null;
    return Semantics(
      label: action.title,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: FloraInkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                action.icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    action.title,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
