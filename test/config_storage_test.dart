import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/models/ai_config.dart';
import 'package:litchi_journal_flutter/models/default_tag_config.dart';
import 'package:litchi_journal_flutter/models/tag_settings.dart';
import 'package:litchi_journal_flutter/services/ai_config_repository.dart';
import 'package:litchi_journal_flutter/services/appearance_settings.dart';
import 'package:litchi_journal_flutter/services/appearance_settings_repository.dart';
import 'package:litchi_journal_flutter/services/tag_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('默认配置仓库共享适配器后仍独立持久化，清除 AI 不影响其他配置', () async {
    FlutterSecureStorage.setMockInitialValues({'unrelated': '保留'});
    final appearance = AppearanceSettings(themeMode: ThemeMode.dark);
    final tags = TagSettings.fromTagConfig(DefaultTagConfig.value);
    await AIConfigRepository().saveAIConfig(const AIConfig(name: '测试配置'));
    await AppearanceSettingsRepository().save(appearance);
    await TagSettingsRepository().saveTagSettings(tags);

    expect((await AIConfigRepository().loadAIConfig()).name, '测试配置');
    expect(
      (await AppearanceSettingsRepository().load()).toJson(),
      appearance.toJson(),
    );
    expect(
      (await TagSettingsRepository().loadTagSettings(
        DefaultTagConfig.value,
      )).toJson(),
      tags.toJson(),
    );
    await AIConfigRepository().clearAIConfig();
    final stored = await const FlutterSecureStorage().readAll();
    expect(
      stored.keys,
      unorderedEquals(['appearance_settings', 'tag_settings', 'unrelated']),
    );
    expect(stored['unrelated'], '保留');
    expect((await AIConfigRepository().loadAIConfig()).name, isEmpty);
    expect(
      (await AppearanceSettingsRepository().load()).themeMode,
      ThemeMode.dark,
    );
  });
}
