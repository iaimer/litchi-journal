class DiaryEntry {
  final String date;
  final String title;
  final String raw;
  final Map<String, List<String>> sections;

  DiaryEntry({
    required this.date,
    required this.title,
    required this.raw,
    required this.sections,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> rawSections = json['sections'] ?? {};

    return DiaryEntry(
      date: json['date'] as String? ?? '',
      title: json['title'] as String? ?? '',
      raw: json['raw'] as String? ?? '',
      sections: rawSections.map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      ),
    );
  }

  bool get isEmpty => date.isEmpty && title.isEmpty && raw.isEmpty;
}
