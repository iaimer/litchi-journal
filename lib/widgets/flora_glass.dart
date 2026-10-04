import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'flora_origin.dart';

class FloraGlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color? tint;
  final bool navigationSurface;

  const FloraGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(FloraRadius.lg)),
    this.tint,
    this.navigationSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final surface = tint ?? theme.colorScheme.surface;
    final fill = surface.withValues(
      alpha: highContrast
          ? 1
          : navigationSurface
          ? (dark
                ? FloraGlass.navigationDarkOpacity
                : FloraGlass.navigationLightOpacity)
          : (dark ? FloraGlass.darkOpacity : FloraGlass.lightOpacity),
    );
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(
          color: highContrast
              ? theme.colorScheme.outline
              : theme.colorScheme.onSurface.withValues(
                  alpha: dark ? 0.18 : 0.10,
                ),
          width: FloraGlass.borderWidth,
        ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: dark ? 0.18 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: highContrast
            ? content
            : BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: FloraGlass.blurSigma,
                  sigmaY: FloraGlass.blurSigma,
                ),
                child: content,
              ),
      ),
    );
  }
}

/// 全宽导航背景，前景标题保持清晰，背后滚动内容才参与模糊。
class FloraGlassHeader extends StatelessWidget {
  final Widget child;

  const FloraGlassHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: highContrast
              ? 1
              : dark
              ? FloraGlass.navigationDarkOpacity
              : FloraGlass.navigationLightOpacity,
        ),
      ),
      child: child,
    );
    return ClipRect(
      child: highContrast
          ? foreground
          : BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: FloraGlass.blurSigma,
                sigmaY: FloraGlass.blurSigma,
              ),
              child: foreground,
            ),
    );
  }
}

class FloraGlassIconButton extends StatelessWidget {
  final IconButton button;
  final Color? tint;

  const FloraGlassIconButton({super.key, required this.button, this.tint});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Center(
      child: FloraGlassSurface(
        tint: tint,
        borderRadius: BorderRadius.circular(FloraRadius.pill),
        child: SizedBox.square(
          dimension: 48,
          child: FloraOriginIconButton(button: button),
        ),
      ),
    ),
  );
}
