import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  var writes = 0;
  int? failWrite;
  setUp(() {
    values.clear();
    writes = 0;
    failWrite = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = args['key'] as String;
          if (call.method == 'read') return values[key];
          if (call.method == 'delete') {
            values.remove(key);
            return null;
          }
          if (call.method == 'write') {
            writes++;
            if (writes == failWrite) {
              throw PlatformException(code: 'unavailable');
            }
            values[key] = args['value'] as String;
            return null;
          }
          throw StateError('Unexpected storage method');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('旧格式可读取，同时修改地址和Token不会保存半份配置', () async {
    final oldToken = 'o' * 32;
    final newToken = 'n' * 32;
    values.addAll({
      'api_base_url': 'https://old.example',
      'api_token': oldToken,
    });
    final legacy = await ApiConfig.load();
    expect(legacy!.baseUrl, 'https://old.example');
    expect(legacy.token == oldToken, isTrue);
    failWrite = 2;
    var saved = true;
    try {
      await ApiConfig(baseUrl: 'https://new.example', token: newToken).save();
    } catch (_) {
      saved = false;
    }
    final loaded = await ApiConfig.load();
    expect(
      loaded!.baseUrl,
      saved ? 'https://new.example' : 'https://old.example',
    );
    expect(loaded.token == (saved ? newToken : oldToken), isTrue);
  });

  test('损坏的新格式不回退到过期凭据', () async {
    values.addAll({
      'api_base_url': 'https://legacy.example',
      'api_token': 'l' * 32,
    });
    for (final damaged in ['{', '[]', '{"baseUrl":123,"token":"invalid"}']) {
      values['api_connection'] = damaged;
      expect(await ApiConfig.load(), isNull);
    }
  });

  test('保存失败保留原连接，清除不复活旧配置', () async {
    values.addAll({
      'api_base_url': 'https://legacy.example',
      'api_token': 'l' * 32,
      'unrelated': 'keep',
    });
    final current = ApiConfig(
      baseUrl: 'https://current.example',
      token: 'c' * 32,
    );
    await current.save();
    writes = 0;
    failWrite = 1;
    await expectLater(
      ApiConfig(baseUrl: 'https://new.example', token: 'n' * 32).save(),
      throwsA(isA<PlatformException>()),
    );
    expect((await ApiConfig.load())!.baseUrl, current.baseUrl);
    expect((await ApiConfig.load())!.token == current.token, isTrue);
    await ApiConfig.clear();
    expect(await ApiConfig.load(), isNull);
    expect(values['unrelated'], 'keep');
  });
}
