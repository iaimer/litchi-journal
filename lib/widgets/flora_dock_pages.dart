import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'flora_origin_transform.dart';

/// 保留根页面实例，仅在绘制阶段把目标页从 Dock 图标附近展开。
class FloraDockPages extends StatefulWidget {
  final int selectedIndex;
  final Rect? origin;
  final List<Widget> children;
  const FloraDockPages({
    super.key,
    required this.selectedIndex,
    this.origin,
    required this.children,
  });
  @override
  State<FloraDockPages> createState() => _FloraDockPagesState();
}

class _FloraDockPagesState extends State<FloraDockPages>
    with SingleTickerProviderStateMixin {
  late int _incoming = widget.selectedIndex;
  int? _outgoing;
  Rect? _source;
  bool _skip = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
    duration: FloraMotion.slow,
  )..addStatusListener(_completed);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _skip =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    if (_skip) {
      _controller.value = 1;
      _incoming = widget.selectedIndex;
      _outgoing = null;
    }
  }

  @override
  void didUpdateWidget(FloraDockPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.isAnimating && widget.selectedIndex != _incoming) _start();
  }

  void _start() {
    _source = widget.origin;
    _outgoing = _skip || _source == null ? null : _incoming;
    _incoming = widget.selectedIndex;
    if (_outgoing != null) _controller.forward(from: 0);
  }

  void _completed(AnimationStatus status) {
    if (status != AnimationStatus.completed || _skip || !mounted) return;
    setState(() {
      _outgoing = null;
      if (widget.selectedIndex != _incoming) _start();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Rect? _startRect(Size size) {
    if (_source == null || size.isEmpty) return null;
    final width = math.min(48.0, size.width);
    final height = width / size.aspectRatio;
    return Rect.fromLTWH(
      _source!.center.dx - width / 2,
      _source!.top - height,
      width,
      height,
    );
  }

  Widget _page(int index, double progress, Size size) {
    final incoming = index == _incoming;
    final visible = incoming || index == _outgoing;
    final child = widget.children[index];
    return Offstage(
      key: ValueKey('dock_page_$index'),
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: ExcludeFocus(
          excluding: !incoming || _outgoing != null,
          child: ExcludeSemantics(
            excluding: !incoming || _outgoing != null,
            child: IgnorePointer(
              ignoring: !incoming || _outgoing != null,
              child: FloraOriginTransform(
                source: incoming ? _startRect(size) : null,
                progress: incoming ? progress : 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    incoming ? 16 * (1 - progress) : 0,
                  ),
                  child: Opacity(
                    opacity: incoming ? progress : 1,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final order = [
        for (var i = 0; i < widget.children.length; i++)
          if (i != _incoming && i != _outgoing) i,
        ?_outgoing,
        _incoming,
      ];
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = Curves.easeOutQuart.transform(_controller.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              for (final i in order) _page(i, progress, constraints.biggest),
            ],
          );
        },
      );
    },
  );
}
