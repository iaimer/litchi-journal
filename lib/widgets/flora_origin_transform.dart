import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 在绘制阶段使用真实内容尺寸，面板高度变化不需要额外的测量帧。
class FloraOriginTransform extends SingleChildRenderObjectWidget {
  final Rect? source;
  final double progress;
  final bool hitTestDuringTransition;

  const FloraOriginTransform({
    super.key,
    required this.source,
    required this.progress,
    this.hitTestDuringTransition = false,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderFloraOriginTransform(source, progress, hitTestDuringTransition);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderFloraOriginTransform renderObject,
  ) {
    renderObject.update(source, progress, hitTestDuringTransition);
  }
}

class RenderFloraOriginTransform extends RenderProxyBox {
  Rect? _source;
  double _progress;
  bool _hitTestDuringTransition;

  RenderFloraOriginTransform(
    this._source,
    this._progress,
    this._hitTestDuringTransition,
  );

  void update(Rect? source, double progress, bool hitTestDuringTransition) {
    if (source == _source &&
        progress == _progress &&
        hitTestDuringTransition == _hitTestDuringTransition) {
      return;
    }
    _hitTestDuringTransition = hitTestDuringTransition;
    _source = source;
    _progress = progress;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Matrix4 get _matrix {
    final source = _source;
    if (source == null || size.isEmpty) return Matrix4.identity();
    final target = localToGlobal(Offset.zero) & size;
    return Matrix4.identity()
      ..translateByDouble(
        (source.left - target.left) * (1 - _progress),
        (source.top - target.top) * (1 - _progress),
        0,
        1,
      )
      ..scaleByDouble(
        lerpDouble(source.width / size.width, 1, _progress)!,
        lerpDouble(source.height / size.height, 1, _progress)!,
        1,
        1,
      );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushTransform(needsCompositing, offset, _matrix, super.paint);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_matrix);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_progress < 1 && !_hitTestDuringTransition) return false;
    return result.addWithPaintTransform(
      transform: _matrix,
      position: position,
      hitTest: (result, local) => super.hitTest(result, position: local),
    );
  }
}
