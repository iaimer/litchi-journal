import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import 'generic_section_card.dart';

class ReviewCard extends StatelessWidget {
  final ReviewSection section;
  final Future<void> Function(String rawLine)? onTimelineDelete;

  const ReviewCard({
    super.key,
    required this.section,
    this.onTimelineDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GenericSectionCard(
      section: section,
      onTimelineDelete: onTimelineDelete,
    );
  }
}
