class MemoryEntry {
  final DateTime date;
  final String displayDate;
  final String weekday;
  final List<String> imageNames;
  final int imageCount;
  final String? joyText;
  final String? growthText;
  final String? coachSummary;
  final bool hasAnyContent;

  const MemoryEntry({
    required this.date,
    required this.displayDate,
    required this.weekday,
    this.imageNames = const [],
    this.imageCount = 0,
    this.joyText,
    this.growthText,
    this.coachSummary,
    this.hasAnyContent = false,
  });
}
