import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import 'generic_section_card.dart';

class ReviewCard extends StatelessWidget {
  final ReviewSection section;
  final Future<void> Function(String rawLine)? onTimelineDelete;
  final Future<void> Function(
      String rawLine, String content, List<String> tags)? onTimelineEdit;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;

  const ReviewCard({
    super.key,
    required this.section,
    this.onTimelineDelete,
    this.onTimelineEdit,
    this.tagConfig,
    this.tagSettings,
  });

  @override
  Widget build(BuildContext context) {
    return GenericSectionCard(
      section: section,
      onTimelineDelete: onTimelineDelete,
      onTimelineEdit: onTimelineEdit,
      tagConfig: tagConfig,
      tagSettings: tagSettings,
    );
  }
}
