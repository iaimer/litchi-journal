import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 标签与回顾共用：高度从顶部揭示，下方内容随正常布局移动。
class FloraExpand extends StatefulWidget {
  final bool expanded;
  final Widget child;
  const FloraExpand({super.key, required this.expanded, required this.child});
  @override
  State<FloraExpand> createState() => _FloraExpandState();
}

class _FloraExpandState extends State<FloraExpand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.expanded ? 1 : 0,
  );
  bool _skip = false;
  final _contentKey = GlobalKey();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _skip =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    _move();
  }

  @override
  void didUpdateWidget(FloraExpand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) _move();
  }

  void _move() {
    final target = widget.expanded ? 1.0 : 0.0;
    if (_skip) {
      _controller.value = target;
      return;
    }
    final duration = widget.expanded ? FloraMotion.standard : FloraMotion.fast;
    _controller.animateTo(
      target,
      duration: duration * (target - _controller.value).abs(),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: !widget.expanded,
    child: ExcludeSemantics(
      excluding: !widget.expanded,
      child: IgnorePointer(
        ignoring: !widget.expanded,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Offstage(
            offstage: !widget.expanded && _controller.value == 0,
            child: child,
          ),
          child: SizeTransition(
            sizeFactor: _controller,
            alignment: Alignment.topCenter,
            child: _skip
                ? KeyedSubtree(key: _contentKey, child: widget.child)
                : AnimatedSize(
                    alignment: Alignment.topCenter,
                    duration: FloraMotion.standard,
                    reverseDuration: FloraMotion.fast,
                    curve: Curves.easeOutQuart,
                    child: KeyedSubtree(key: _contentKey, child: widget.child),
                  ),
          ),
        ),
      ),
    ),
  );
}
