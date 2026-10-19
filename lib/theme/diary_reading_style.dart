import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/appearance_settings.dart';

/// 阅读字号独立于全局文字主题，避免放大习惯列表、编辑框和菜单。
@immutable
class DiaryReadingStyle extends ThemeExtension<DiaryReadingStyle> {
  final double fontSize;

  const DiaryReadingStyle({this.fontSize = 16});

  static DiaryReadingStyle of(BuildContext context) =>
      Theme.of(context).extension<DiaryReadingStyle>() ??
      const DiaryReadingStyle();

  static ThemeData applyTo(ThemeData theme, {required int fontSize}) =>
      theme.copyWith(
        extensions: [
          ...theme.extensions.values.where(
            (value) => value is! DiaryReadingStyle,
          ),
          DiaryReadingStyle(
            fontSize: AppearanceSettings.normalizeReadingFontSize(
              fontSize,
            ).toDouble(),
          ),
        ],
      );

  TextStyle body(ThemeData theme) =>
      theme.textTheme.bodyMedium!.copyWith(fontSize: fontSize, height: 1.6);

  TextStyle heading(ThemeData theme) => theme.textTheme.titleLarge!.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  TextStyle metadata(ThemeData theme) =>
      theme.textTheme.bodySmall!.copyWith(fontSize: 14, height: 1.2);

  MarkdownStyleSheet markdown(ThemeData theme) {
    final base = MarkdownStyleSheet.fromTheme(theme);
    final paragraph = body(theme);
    final title = heading(theme);
    return base.copyWith(
      p: paragraph,
      h1: title,
      h2: title,
      h3: title,
      h4: title,
      h5: title,
      h6: title,
      listBullet: paragraph,
      blockquote: paragraph,
      strong: const TextStyle(fontWeight: FontWeight.bold),
      em: const TextStyle(fontStyle: FontStyle.italic),
      code: base.code?.copyWith(fontSize: fontSize, height: 1.6),
      a: TextStyle(color: theme.colorScheme.primary),
      tableBody: paragraph,
      tableHead: title,
    );
  }

  @override
  DiaryReadingStyle copyWith({double? fontSize}) =>
      DiaryReadingStyle(fontSize: fontSize ?? this.fontSize);

  @override
  DiaryReadingStyle lerp(DiaryReadingStyle? other, double t) => other == null
      ? this
      : DiaryReadingStyle(fontSize: fontSize + (other.fontSize - fontSize) * t);
}
