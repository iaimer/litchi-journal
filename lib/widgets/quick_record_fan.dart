import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'flora_icon.dart';

class QuickRecordFanAction {
  final Widget icon;
  final String title;
  final Key key;
  final double angleDegrees;
  final VoidCallback onTap;

  const QuickRecordFanAction({
    required this.icon,
    required this.title,
    required this.key,
    required this.angleDegrees,
    required this.onTap,
  });
}

/// 今天与历史补录共用的扇形入口，只负责展示与转发操作。
class QuickRecordFan extends StatefulWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final Key mainButtonKey;
  final String tooltip;
  final List<QuickRecordFanAction> actions;

  const QuickRecordFan({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.mainButtonKey,
    required this.tooltip,
    required this.actions,
  });

  @override
  State<QuickRecordFan> createState() => _QuickRecordFanState();
}

class _QuickRecordFanState extends State<QuickRecordFan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _skipMotion = false;

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
  void didUpdateWidget(covariant QuickRecordFan oldWidget) {
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
    return SizedBox.square(
      dimension: 210,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _buildFan(_controller.value),
      ),
    );
  }

  Widget _buildFan(double progress) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        if (widget.expanded || progress > 0)
          for (final action in widget.actions) _buildAction(action, progress),
        _buildMainButton(progress),
      ],
    );
  }

  Widget _buildMainButton(double progress) {
    final theme = Theme.of(context);
    return FloatingActionButton(
      key: widget.mainButtonKey,
      tooltip: widget.tooltip,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      shape: const CircleBorder(),
      onPressed: widget.onToggle,
      child: Transform.rotate(
        angle: progress * math.pi / 4,
        child: const FloraIcon(FloraIcons.add, size: 24),
      ),
    );
  }

  Widget _buildAction(QuickRecordFanAction action, double progress) {
    const mainCenter = 28.0;
    const hitSize = 48.0;
    final angle = action.angleDegrees * math.pi / 180;
    final offset = Offset(120 * math.cos(angle), -120 * math.sin(angle));
    final interactive = widget.expanded && progress > 0;
    return Positioned(
      right: mainCenter - hitSize / 2,
      bottom: mainCenter - hitSize / 2,
      child: Transform.translate(
        offset: offset * progress,
        child: IgnorePointer(
          ignoring: !interactive,
          child: ExcludeSemantics(
            excluding: !interactive,
            child: Opacity(
              opacity: progress,
              child: _FanActionButton(
                key: action.key,
                action: action,
                enabled: interactive,
                visualScale: 0.85 + 0.15 * progress,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FanActionButton extends StatelessWidget {
  final QuickRecordFanAction action;
  final bool enabled;
  final double visualScale;

  const _FanActionButton({
    super.key,
    required this.action,
    required this.enabled,
    required this.visualScale,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: action.title,
      child: ExcludeFocus(
        excluding: !enabled,
        child: Semantics(
          label: action.title,
          button: true,
          child: SizedBox.square(
            dimension: 48,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: enabled ? action.onTap : null,
              child: Center(
                child: Transform.scale(
                  scale: visualScale,
                  child: SizedBox.square(
                    dimension: 42,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 2,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: enabled ? action.onTap : null,
                        child: Center(child: action.icon),
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
}
