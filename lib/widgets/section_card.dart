import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String? title;
  final Color? accentColor;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing;

  const SectionCard({
    super.key,
    this.title,
    this.accentColor,
    this.children = const [],
    this.padding,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final hasAccent = accentColor != null;
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = hasAccent
        ? Color.alphaBlend(
            accentColor!.withAlpha(isDark ? 26 : 16),
            theme.colorScheme.surface,
          )
        : theme.colorScheme.surface;
    final borderColor = hasAccent
        ? accentColor!.withAlpha(isDark ? 120 : 95)
        : theme.dividerColor;
    final headerTintColor = hasAccent
        ? accentColor!.withAlpha(isDark ? 48 : 38)
        : null;
    final titleColor = hasAccent
        ? _readableAccentColor(accentColor!, isDark)
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: hasAccent ? 1 : 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: headerTintColor,
                  border: Border(
                    bottom: BorderSide(
                      color: borderColor.withAlpha(hasAccent ? 90 : 255),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              ),
            ],
            Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _readableAccentColor(Color color, bool isDark) {
    final hsl = HSLColor.fromColor(color);
    if (isDark) {
      final lightness = hsl.lightness.clamp(0.62, 0.78).toDouble();
      return hsl.withLightness(lightness).toColor();
    }
    final lightness = hsl.lightness.clamp(0.34, 0.46).toDouble();
    return hsl.withLightness(lightness).toColor();
  }
}
