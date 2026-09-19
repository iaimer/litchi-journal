import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'flora_icon.dart';

enum FloraAnimatedIconName { emptyBook, successCheck }

class FloraAnimatedIcon extends StatefulWidget {
  const FloraAnimatedIcon({
    super.key,
    required this.name,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final FloraAnimatedIconName name;
  final double size;
  final Color? color;
  final String? semanticLabel;

  String get _animationAsset => switch (name) {
    FloraAnimatedIconName.emptyBook =>
      'assets/icons/lordicon/system-outline-4092-book.json',
    FloraAnimatedIconName.successCheck =>
      'assets/icons/lordicon/system-outline-37-check.json',
  };

  String get _staticIcon => switch (name) {
    FloraAnimatedIconName.emptyBook => FloraIcons.emptyPast,
    FloraAnimatedIconName.successCheck => FloraIcons.successCheck,
  };

  @override
  State<FloraAnimatedIcon> createState() => _FloraAnimatedIconState();
}

class _FloraAnimatedIconState extends State<FloraAnimatedIcon> {
  Future<LottieComposition>? _composition;
  bool _reduceMotion = true;
  bool _hasReadMotionPreference = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_hasReadMotionPreference && reduceMotion == _reduceMotion) return;

    _hasReadMotionPreference = true;
    _reduceMotion = reduceMotion;
    _composition = null;
    if (!reduceMotion) _loadAnimation();
  }

  @override
  void didUpdateWidget(covariant FloraAnimatedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name == widget.name) return;

    _composition = null;
    if (!_reduceMotion) _loadAnimation();
  }

  void _loadAnimation() {
    final bundle = DefaultAssetBundle.of(context);
    final composition = AssetLottie(
      widget._animationAsset,
      bundle: bundle,
    ).load(context: context);
    _composition = composition;

    // FutureBuilder stops observing this future if Reduce Motion is enabled
    // while the asset is still loading, so always consume late load failures.
    composition.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _buildFallback();
    final composition = _composition;
    final icon = _reduceMotion || composition == null
        ? fallback
        : FutureBuilder<LottieComposition>(
            future: composition,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done ||
                  snapshot.hasError ||
                  snapshot.data == null) {
                return fallback;
              }
              return Lottie(
                key: ValueKey(widget._animationAsset),
                composition: snapshot.data!,
                width: widget.size,
                height: widget.size,
                animate: true,
                delegates: widget.color == null
                    ? null
                    : LottieDelegates(
                        values: [
                          ValueDelegate.color(['**'], value: widget.color),
                          ValueDelegate.strokeColor([
                            '**',
                          ], value: widget.color),
                        ],
                      ),
                repeat: false,
                reverse: false,
              );
            },
          );

    return Semantics(
      container: widget.semanticLabel != null,
      image: widget.semanticLabel != null,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel == null,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(child: icon),
      ),
    );
  }

  Widget _buildFallback() =>
      FloraIcon(widget._staticIcon, size: widget.size, color: widget.color);
}
