import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../widgets/entry_type.dart';

class QuickDraft {
  final String content;
  final List<String> tags;

  const QuickDraft({required this.content, required this.tags});

  Map<String, dynamic> toJson() => {'content': content, 'tags': tags};

  factory QuickDraft.fromJson(Map<String, dynamic> json) => QuickDraft(
        content: json['content'] as String? ?? '',
        tags: (json['tags'] as List?)?.cast<String>() ?? [],
      );
}

class AnxietyDraft {
  final int step;
  final List<String> answers;

  const AnxietyDraft({required this.step, required this.answers});

  Map<String, dynamic> toJson() => {'step': step, 'answers': answers};

  factory AnxietyDraft.fromJson(Map<String, dynamic> json) => AnxietyDraft(
        step: json['step'] as int? ?? 0,
        answers: (json['answers'] as List?)?.cast<String>() ?? [],
      );
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
  final DraftStorage _storage;

  DraftRepository({DraftStorage? storage})
      : _storage = storage ?? _SecureStorage();

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
    final draft = QuickDraft(content: content, tags: tags);
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
      return QuickDraft.fromJson(jsonDecode(json) as Map<String, dynamic>);
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
    final draft = AnxietyDraft(step: step, answers: answers);
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
      return AnxietyDraft.fromJson(jsonDecode(json) as Map<String, dynamic>);
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
}
