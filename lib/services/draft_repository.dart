import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../widgets/entry_type.dart';

class QuickDraft {
  final String content;
  final List<String> tags;
  final DateTime? updatedAt;

  const QuickDraft({
    required this.content,
    required this.tags,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'content': content,
        'tags': tags,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory QuickDraft.fromJson(Map<String, dynamic> json) => QuickDraft(
        content: json['content'] as String? ?? '',
        tags: (json['tags'] as List?)?.cast<String>() ?? [],
        updatedAt: _parseDateTime(json['updatedAt']),
      );
}

class AnxietyDraft {
  final int step;
  final List<String> answers;
  final DateTime? updatedAt;

  const AnxietyDraft({
    required this.step,
    required this.answers,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'step': step,
        'answers': answers,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory AnxietyDraft.fromJson(Map<String, dynamic> json) => AnxietyDraft(
        step: json['step'] as int? ?? 0,
        answers: (json['answers'] as List?)?.cast<String>() ?? [],
        updatedAt: _parseDateTime(json['updatedAt']),
      );
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}

abstract class DraftStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _SecureStorage extends DraftStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class DraftRepository {
  static const _ttl = Duration(minutes: 2);

  final DraftStorage _storage;
  final DateTime Function() _now;

  DraftRepository({
    DraftStorage? storage,
    DateTime Function()? now,
  })  : _storage = storage ?? _SecureStorage(),
        _now = now ?? (() => DateTime.now());

  static String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _key(DateTime date, EntryType entryType) {
    return 'draft_${_formatDate(date)}_${entryType.name}';
  }

  Future<void> saveQuickDraft({
    required DateTime date,
    required EntryType entryType,
    required String content,
    required List<String> tags,
  }) async {
    if (content.isEmpty && tags.isEmpty) {
      await clearDraft(date: date, entryType: entryType);
      return;
    }
    final draft = QuickDraft(
      content: content,
      tags: tags,
      updatedAt: _now(),
    );
    await _storage.write(
      _key(date, entryType),
      jsonEncode(draft.toJson()),
    );
  }

  Future<QuickDraft?> loadQuickDraft({
    required DateTime date,
    required EntryType entryType,
  }) async {
    final json = await _storage.read(_key(date, entryType));
    if (json == null || json.isEmpty) return null;
    try {
      final draft =
          QuickDraft.fromJson(jsonDecode(json) as Map<String, dynamic>);
      if (_isExpired(draft.updatedAt)) {
        await clearDraft(date: date, entryType: entryType);
        return null;
      }
      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAnxietyDraft({
    required DateTime date,
    required int step,
    required List<String> answers,
  }) async {
    if (answers.every((a) => a.isEmpty)) {
      await clearDraft(date: date, entryType: EntryType.anxiety);
      return;
    }
    final draft = AnxietyDraft(
      step: step,
      answers: answers,
      updatedAt: _now(),
    );
    await _storage.write(
      _key(date, EntryType.anxiety),
      jsonEncode(draft.toJson()),
    );
  }

  Future<AnxietyDraft?> loadAnxietyDraft({
    required DateTime date,
  }) async {
    final json = await _storage.read(_key(date, EntryType.anxiety));
    if (json == null || json.isEmpty) return null;
    try {
      final draft =
          AnxietyDraft.fromJson(jsonDecode(json) as Map<String, dynamic>);
      if (_isExpired(draft.updatedAt)) {
        await clearDraft(date: date, entryType: EntryType.anxiety);
        return null;
      }
      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraft({
    required DateTime date,
    required EntryType entryType,
  }) async {
    await _storage.delete(_key(date, entryType));
  }

  bool _isExpired(DateTime? updatedAt) {
    if (updatedAt == null) return true;
    return _now().difference(updatedAt) > _ttl;
  }
}
