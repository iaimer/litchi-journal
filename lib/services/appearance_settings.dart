import 'package:flutter/material.dart';

/// 外观设置数据模型。
class AppearanceSettings {
  final int schemaVersion;
  final DateTime updatedAt;
  final ThemeMode themeMode;

  AppearanceSettings({
    this.schemaVersion = 1,
    DateTime? updatedAt,
    this.themeMode = ThemeMode.system,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    final modeStr = json['themeMode'] as String? ?? 'system';
    return AppearanceSettings(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      themeMode: _parseThemeMode(modeStr),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'updatedAt': updatedAt.toIso8601String(),
        'themeMode': _themeModeString(themeMode),
      };

  AppearanceSettings copyWith({ThemeMode? themeMode}) {
    return AppearanceSettings(
      schemaVersion: schemaVersion,
      updatedAt: updatedAt,
      themeMode: themeMode ?? this.themeMode,
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
