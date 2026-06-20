import 'package:flutter/material.dart';

import '../services/draft_repository.dart';
import '../widgets/anxiety_composer.dart';

class AnxietyScreen extends StatelessWidget {
  final DateTime date;
  final DraftRepository draftRepository;
  final List<String>? initialAnswers;
  final bool isEdit;
  final Future<void> Function(String content, List<String> tags) onSubmit;
  final Future<String> Function(String content) onPolish;

  const AnxietyScreen({
    super.key,
    required this.date,
    required this.draftRepository,
    required this.onSubmit,
    required this.onPolish,
    this.initialAnswers,
    this.isEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('焦虑四问')),
      body: SafeArea(
        top: false,
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AnxietyComposer(
            onSubmit: (content, tags) async {
              await onSubmit(content, tags);
              if (context.mounted) Navigator.of(context).pop(true);
            },
            onPolish: onPolish,
            date: date,
            draftRepository: draftRepository,
            initialAnswers: initialAnswers,
            isEdit: isEdit,
          ),
        ],
      ),
      ),
    );
  }
}
