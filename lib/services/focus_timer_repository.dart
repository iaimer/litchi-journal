import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/focus_timer.dart';

abstract class FocusTimerStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FocusTimerRepository {
  static const _key = 'focus_timer_session';

  final FocusTimerStorage _storage;

  FocusTimerRepository({FocusTimerStorage? storage})
    : _storage = storage ?? _SecureFocusTimerStorage();

  Future<FocusTimerSession?> load() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null || raw.isEmpty) return null;
      return FocusTimerSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      try {
        await clear();
      } catch (_) {
        // 损坏或不可用的本地存储不应阻塞首页加载。
      }
      return null;
    }
  }

  Future<void> save(FocusTimerSession session) async {
    await _storage.write(_key, jsonEncode(session.toJson()));
  }

  Future<void> clear() => _storage.delete(_key);

  /// 保存成功后清理会话。
  ///
  /// 删除失败时写入一个一次性无效标记，避免下次启动把已经写入服务端的
  /// 会话当成未保存内容再次提交。下次读取会清掉这个标记。
  Future<bool> clearAfterSave() async {
    try {
      await _storage.delete(_key);
      return true;
    } catch (_) {
      try {
        await _storage.write(_key, jsonEncode({'saved': true}));
      } catch (_) {
        // 无法写入标记时仍由 Controller 清理当前内存会话。
      }
      return false;
    }
  }
}

class _SecureFocusTimerStorage implements FocusTimerStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
