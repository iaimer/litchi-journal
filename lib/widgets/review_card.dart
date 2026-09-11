import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
import 'entry_type.dart';
import 'generic_section_card.dart';

class ReviewCard extends StatelessWidget {
  final ReviewSection section;
  final Color? accentColor;
  final Future<void> Function(String rawLine)? onTimelineDelete;
  final Future<void> Function(
    String rawLine,
    String content,
    List<String> tags,
    String time,
  )?
  onTimelineEdit;
  final TagConfig? tagConfig;
  final TagSettings? tagSettings;
  final DateTime? recordDate;
  final Future<PolishResult> Function(String content, EntryType entryType)?
  onPolish;

  const ReviewCard({
    super.key,
    required this.section,
    this.accentColor,
    this.onTimelineDelete,
    this.onTimelineEdit,
    this.tagConfig,
    this.tagSettings,
    this.recordDate,
    this.onPolish,
  });

  @override
  Widget build(BuildContext context) {
    return GenericSectionCard(
      section: section,
      accentColor: accentColor,
      onTimelineDelete: onTimelineDelete,
      onTimelineEdit: onTimelineEdit,
      tagConfig: tagConfig,
      tagSettings: tagSettings,
      recordDate: recordDate,
      onPolish: onPolish,
    );
  }
}
