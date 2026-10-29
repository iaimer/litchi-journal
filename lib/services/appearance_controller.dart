import 'package:flutter/material.dart';

import 'appearance_settings.dart';
import 'appearance_settings_repository.dart';

/// 全局外观控制器。
/// MaterialApp 通过 ListenableBuilder 监听此控制器以实时切换主题。
class AppearanceController extends ChangeNotifier {
  static final AppearanceController instance = AppearanceController();

  final AppearanceSettingsRepository _repo;
  AppearanceSettings _settings = AppearanceSettings();
  AppearanceSettings _savedSettings = AppearanceSettings();
  Future<void> _saveTail = Future.value();
  int _themeRevision = 0;
  int _readingRevision = 0;
  bool _initialized = false;

  AppearanceController({AppearanceSettingsRepository? repository})
    : _repo = repository ?? AppearanceSettingsRepository();

  Future<void> init() async {
    if (_initialized) return;
    _settings = await _repo.load();
    _savedSettings = _settings;
    _initialized = true;
    notifyListeners();
  }

  ThemeMode get themeMode => _settings.themeMode;

  int get readingFontSize => _settings.readingFontSize;

  Future<void> setThemeMode(ThemeMode mode) {
    final revision = ++_themeRevision;
    return _change((settings) => settings.copyWith(themeMode: mode), () {
      if (revision == _themeRevision) {
        _settings = _settings.copyWith(themeMode: _savedSettings.themeMode);
      }
    });
  }

  Future<void> setReadingFontSize(int size) {
    final revision = ++_readingRevision;
    return _change((settings) => settings.copyWith(readingFontSize: size), () {
      if (revision == _readingRevision) {
        _settings = _settings.copyWith(
          readingFontSize: _savedSettings.readingFontSize,
        );
      }
    });
  }

  Future<void> _change(
    AppearanceSettings Function(AppearanceSettings) change,
    VoidCallback rollback,
  ) {
    _settings = change(_settings);
    notifyListeners();
    final task = _saveTail.then((_) async {
      // 只合入本次字段，不能把其他尚未确认的乐观值一起写入。
      final next = change(_savedSettings);
      try {
        await _repo.save(next);
        _savedSettings = next;
      } catch (_) {
        rollback();
        notifyListeners();
        rethrow;
      }
    });
    // 保持后续写入可继续；原始异常仍由本次调用方显示固定提示。
    _saveTail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }
}
