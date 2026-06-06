import 'package:flutter/material.dart';

import '../models/diary_document.dart';
import 'generic_section_card.dart';

class ReviewCard extends StatelessWidget {
  final ReviewSection section;

  const ReviewCard({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return GenericSectionCard(section: section);
  }
}
