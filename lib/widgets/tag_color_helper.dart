import 'package:flutter/material.dart';

import '../models/tag_config.dart';

class TagChipColors {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const TagChipColors({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });
}

class TagChipList extends StatelessWidget {
  final List<String> tags;
  final TagConfig? tagConfig;
  final Color? moduleAccentColor;

  const TagChipList({
    super.key,
    required this.tags,
    required this.tagConfig,
    this.moduleAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor =
        moduleAccentColor ?? TagChipModuleAccent.maybeOf(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags
          .map((tag) {
            final colors = tagChipColorsFor(
              label: tag,
              tagConfig: tagConfig,
              theme: theme,
              moduleAccentColor: accentColor,
            );
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.backgroundColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.borderColor, width: 0.6),
              ),
              child: Text(
                tag,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textColor,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class TagChipModuleAccent extends InheritedWidget {
  final Color accentColor;

  const TagChipModuleAccent({
    super.key,
    required this.accentColor,
    required super.child,
  });

  static Color? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TagChipModuleAccent>()
        ?.accentColor;
  }

  @override
  bool updateShouldNotify(TagChipModuleAccent oldWidget) {
    return oldWidget.accentColor != accentColor;
  }
}

enum TagColorRole { module, domain, topic, method, unknown }

const _domainPalette = [
  Color(0xFFFF6B6B),
  Color(0xFFFF9F43),
  Color(0xFFFFD43B),
  Color(0xFF51CF66),
  Color(0xFF20C997),
  Color(0xFF4DABF7),
  Color(0xFF9775FA),
  Color(0xFFF06595),
];

const _topicColor = Color(0xFFF2C94C);
const _methodColor = Color(0xFF9775FA);

TagChipColors tagChipColorsFor({
  required String label,
  required TagConfig? tagConfig,
  required ThemeData theme,
  bool selected = false,
  Color? moduleAccentColor,
}) {
  if (moduleAccentColor != null) {
    return _chipColors(
      baseColor: moduleAccentColor,
      theme: theme,
      selected: selected,
      role: TagColorRole.module,
    );
  }

  final roleColor = _roleColorFor(label, tagConfig);
  if (roleColor == null) {
    return _chipColors(
      baseColor: theme.colorScheme.primary,
      theme: theme,
      selected: selected,
      role: TagColorRole.unknown,
    );
  }

  return _chipColors(
    baseColor: roleColor.color,
    theme: theme,
    selected: selected,
    role: roleColor.role,
  );
}

_TagRoleColor? _roleColorFor(String label, TagConfig? tagConfig) {
  if (tagConfig == null) return null;
  final normalized = _normalizeTagLabel(label);
  if (normalized.isEmpty) return null;

  for (var i = 0; i < tagConfig.domains.length; i++) {
    final domain = tagConfig.domains[i];
    final domainColor = _domainPalette[i % _domainPalette.length];
    if (domain.name == normalized) {
      return _TagRoleColor(TagColorRole.domain, domainColor);
    }
    for (final topic in domain.topics) {
      if (topic.name == normalized) {
        return const _TagRoleColor(TagColorRole.topic, _topicColor);
      }
    }
  }

  for (final method in tagConfig.methods) {
    if (method.name == normalized) {
      return const _TagRoleColor(TagColorRole.method, _methodColor);
    }
  }

  return null;
}

TagChipColors _chipColors({
  required Color baseColor,
  required ThemeData theme,
  required bool selected,
  required TagColorRole role,
}) {
  final isDark = theme.brightness == Brightness.dark;
  final backgroundAlpha = switch (role) {
    TagColorRole.module => isDark ? 38 : 22,
    TagColorRole.domain => isDark ? 44 : 24,
    TagColorRole.topic => isDark ? 32 : 16,
    TagColorRole.method => isDark ? 38 : 20,
    TagColorRole.unknown => isDark ? 32 : 18,
  };
  final borderAlpha = switch (role) {
    TagColorRole.module => isDark ? 128 : 88,
    TagColorRole.domain => isDark ? 132 : 92,
    TagColorRole.topic => isDark ? 96 : 64,
    TagColorRole.method => isDark ? 120 : 80,
    TagColorRole.unknown => isDark ? 88 : 56,
  };
  final effectiveBackgroundAlpha = selected
      ? (isDark ? 92 : 46)
      : backgroundAlpha;
  final effectiveBorderAlpha = selected ? (isDark ? 190 : 150) : borderAlpha;
  final backgroundColor = baseColor.withAlpha(effectiveBackgroundAlpha);
  final textColor = _readableColor(baseColor, [
    Color.alphaBlend(backgroundColor, theme.colorScheme.surface),
    Color.alphaBlend(backgroundColor, theme.scaffoldBackgroundColor),
  ], isDark);

  return TagChipColors(
    backgroundColor: backgroundColor,
    borderColor: baseColor.withAlpha(effectiveBorderAlpha),
    textColor: textColor,
  );
}

Color _readableColor(Color color, List<Color> backgrounds, bool isDark) {
  final hsl = HSLColor.fromColor(color);
  final preferredLightness = isDark
      ? hsl.lightness.clamp(0.66, 0.82).toDouble()
      : hsl.lightness.clamp(0.30, 0.42).toDouble();
  final direction = isDark ? 1 : -1;
  var best = hsl.withLightness(preferredLightness).toColor();
  var bestRatio = _worstContrastRatio(best, backgrounds);

  for (var step = 0; step <= 70; step++) {
    final lightness = (preferredLightness + direction * step * 0.01)
        .clamp(0.04, 0.96)
        .toDouble();
    final candidate = hsl.withLightness(lightness).toColor();
    final ratio = _worstContrastRatio(candidate, backgrounds);
    if (ratio > bestRatio) {
      best = candidate;
      bestRatio = ratio;
    }
    if (ratio >= 4.5) return candidate;
  }

  return best;
}

double _worstContrastRatio(Color foreground, List<Color> backgrounds) {
  var worst = double.infinity;
  for (final background in backgrounds) {
    final ratio = _contrastRatio(foreground, background);
    if (ratio < worst) worst = ratio;
  }
  return worst;
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

String _normalizeTagLabel(String label) {
  var result = label.trim();
  while (result.startsWith('#')) {
    result = result.substring(1).trimLeft();
  }
  return result;
}

class _TagRoleColor {
  final TagColorRole role;
  final Color color;

  const _TagRoleColor(this.role, this.color);
}
