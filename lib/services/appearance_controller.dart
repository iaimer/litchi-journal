import 'package:flutter/material.dart';

import 'appearance_settings.dart';
import 'appearance_settings_repository.dart';

/// 全局外观控制器。
/// MaterialApp 通过 ListenableBuilder 监听此控制器以实时切换主题。
class AppearanceController extends ChangeNotifier {
  static final AppearanceController instance = AppearanceController._();

  final AppearanceSettingsRepository _repo = AppearanceSettingsRepository();
  AppearanceSettings? _settings;
  bool _initialized = false;

  AppearanceController._();

  Future<void> init() async {
    if (_initialized) return;
    _settings = await _repo.load();
    _initialized = true;
    notifyListeners();
  }

  ThemeMode get themeMode => _settings?.themeMode ?? ThemeMode.system;

  bool get isInitialized => _initialized;

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = (_settings ?? AppearanceSettings()).copyWith(themeMode: mode);
    await _repo.save(_settings!);
    notifyListeners();
  }
}
