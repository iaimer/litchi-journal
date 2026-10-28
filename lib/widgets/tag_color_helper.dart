import 'package:flutter/material.dart';

import '../models/tag_config.dart';
import '../theme/app_theme.dart';
import '../theme/diary_reading_style.dart';

const double readingTagMaxSize = 12;
const double readingTagMinSize = 10;
const double _tagHorizontalPadding = 13.2;
const double _tagSpacing = 4;

TextStyle _readingTagTextStyle(BuildContext context, double size) {
  final baseStyle = DiaryReadingStyle.of(
    context,
  ).metadata(Theme.of(context)).copyWith(fontSize: size);
  var style = DefaultTextStyle.of(context).style.merge(baseStyle);
  if (MediaQuery.boldTextOf(context)) {
    style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  return style.merge(
    TextStyle(
      height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
      letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
      wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
    ),
  );
}

double readingTagWidth(BuildContext context, List<String> tags, double size) {
  final style = _readingTagTextStyle(context, size);
  var width = (tags.length - 1).clamp(0, tags.length) * _tagSpacing;
  for (final tag in tags) {
    final painter = TextPainter(
      text: TextSpan(text: _tagDisplayLabel(tag), style: style),
      textDirection: Directionality.of(context),
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    width += painter.width + _tagHorizontalPadding;
    painter.dispose();
  }
  return width;
}

double readingTagFontSize(
  BuildContext context,
  List<String> tags,
  double width,
) {
  final preferred = MediaQuery.textScalerOf(
    context,
  ).scale(readingTagMaxSize).clamp(readingTagMinSize, readingTagMaxSize);
  if (readingTagWidth(context, tags, preferred) <= width) return preferred;
  var low = readingTagMinSize;
  var high = preferred;
  for (var i = 0; i < 12; i++) {
    final middle = (low + high) / 2;
    if (readingTagWidth(context, tags, middle) <= width) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return low;
}

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
  final bool singleLine;

  const TagChipList({
    super.key,
    required this.tags,
    required this.tagConfig,
    this.moduleAccentColor,
    this.singleLine = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor =
        moduleAccentColor ?? TagChipModuleAccent.maybeOf(context);
    if (!singleLine) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final tag in tags)
            _tag(context, tag, 14, null, null, accentColor: accentColor),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) =>
          _singleLine(context, constraints.maxWidth, accentColor),
    );
  }

  Widget _singleLine(BuildContext context, double width, Color? accentColor) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final size = readingTagFontSize(context, tags, width);
    final spacing = tags.length > 1
        ? _tagSpacing.clamp(0.0, width / (tags.length - 1))
        : 0.0;
    final available = (width - spacing * (tags.length - 1)).clamp(
      0.0,
      double.infinity,
    );
    final naturalWidths = tags
        .map((tag) => readingTagWidth(context, [tag], size))
        .toList(growable: false);
    final widths = _distributeWidths(naturalWidths, available);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tags.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          _tag(
            context,
            tags[i],
            size,
            widths[i],
            naturalWidths[i],
            accentColor: accentColor,
          ),
        ],
      ],
    );
  }

  List<double> _distributeWidths(List<double> natural, double available) {
    final widths = List<double>.filled(natural.length, 0);
    var remaining = available;
    final pending = <int>{for (var i = 0; i < natural.length; i++) i};
    while (pending.isNotEmpty) {
      final share = remaining / pending.length;
      final fitting = pending.where((i) => natural[i] <= share).toList();
      if (fitting.isEmpty) {
        for (final i in pending) {
          widths[i] = share;
        }
        break;
      }
      for (final i in fitting) {
        widths[i] = natural[i];
        remaining -= widths[i];
        pending.remove(i);
      }
    }
    return widths;
  }

  Widget _tag(
    BuildContext context,
    String tag,
    double size,
    double? width,
    double? naturalWidth, {
    Color? accentColor,
  }) {
    final theme = Theme.of(context);
    final colors = tagChipColorsFor(
      label: tag,
      tagConfig: tagConfig,
      theme: theme,
      moduleAccentColor: accentColor,
    );
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.backgroundColor,
          borderRadius: BorderRadius.circular(FloraRadius.pill),
          border: Border.all(color: colors.borderColor, width: 0.6),
        ),
        child: Semantics(
          label: _tagDisplayLabel(tag),
          child: ExcludeSemantics(
            child: Text(
              _tagDisplayLabel(tag),
              maxLines: singleLine ? 1 : null,
              softWrap: singleLine ? false : null,
              overflow:
                  width != null &&
                      naturalWidth != null &&
                      width + 0.01 < naturalWidth
                  ? TextOverflow.ellipsis
                  : null,
              textScaler: singleLine ? TextScaler.noScaling : null,
              style: _readingTagTextStyle(
                context,
                size,
              ).copyWith(color: colors.textColor),
            ),
          ),
        ),
      ),
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
    TagColorRole.module => isDark ? 24 : 12,
    TagColorRole.domain => isDark ? 44 : 24,
    TagColorRole.topic => isDark ? 32 : 16,
    TagColorRole.method => isDark ? 38 : 20,
    TagColorRole.unknown => isDark ? 32 : 18,
  };
  final borderAlpha = switch (role) {
    TagColorRole.module => isDark ? 76 : 48,
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

/// 模块主色用于装饰，文字按实际主题表面派生可读的同色系前景。
Color moduleTextColor(Color accentColor, ThemeData theme) => _readableColor(
  accentColor,
  [theme.colorScheme.surface, theme.scaffoldBackgroundColor],
  theme.brightness == Brightness.dark,
);

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

// 仅用于显示和测量，标签匹配与保存仍使用原始值。
String _tagDisplayLabel(String label) => label.replaceFirst(RegExp(r'^#+'), '');

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
