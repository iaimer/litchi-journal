import 'package:flutter/material.dart';

/// 外观设置数据模型。
class AppearanceSettings {
  static const readingFontSizes = [14, 16, 18];
  final int schemaVersion;
  final DateTime updatedAt;
  final ThemeMode themeMode;
  final int readingFontSize;

  AppearanceSettings({
    this.schemaVersion = 1,
    DateTime? updatedAt,
    this.themeMode = ThemeMode.system,
    int readingFontSize = 16,
  }) : updatedAt = updatedAt ?? DateTime.now(),
       readingFontSize = normalizeReadingFontSize(readingFontSize);

  static int normalizeReadingFontSize(Object? value) =>
      value is int && readingFontSizes.contains(value) ? value : 16;

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    final modeStr = json['themeMode'] as String? ?? 'system';
    return AppearanceSettings(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      themeMode: _parseThemeMode(modeStr),
      readingFontSize: normalizeReadingFontSize(json['readingFontSize']),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'updatedAt': updatedAt.toIso8601String(),
    'themeMode': _themeModeString(themeMode),
    'readingFontSize': readingFontSize,
  };

  AppearanceSettings copyWith({ThemeMode? themeMode, int? readingFontSize}) {
    return AppearanceSettings(
      schemaVersion: schemaVersion,
      updatedAt: updatedAt,
      themeMode: themeMode ?? this.themeMode,
      readingFontSize: readingFontSize ?? this.readingFontSize,
    );
  }

  static ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
