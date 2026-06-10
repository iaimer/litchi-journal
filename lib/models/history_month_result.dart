class HistoryMonthResult {
  final int year;
  final int month;
  final List<HistoryDayInfo> diaries;

  const HistoryMonthResult({
    required this.year,
    required this.month,
    required this.diaries,
  });

  factory HistoryMonthResult.fromJson(Map<String, dynamic> json) {
    final list = (json['diaries'] as List)
        .map((d) => HistoryDayInfo.fromJson(d as Map<String, dynamic>))
        .toList();
    return HistoryMonthResult(
      year: json['year'] as int,
      month: json['month'] as int,
      diaries: list,
    );
  }
}

class HistoryDayInfo {
  final String date;
  final bool hasImages;
  final String? firstImage;
  final int quickNotesCount;
  final bool exists;
  final bool hasContent;

  const HistoryDayInfo({
    required this.date,
    required this.hasImages,
    this.firstImage,
    required this.quickNotesCount,
    required this.exists,
    required this.hasContent,
  });

  factory HistoryDayInfo.fromJson(Map<String, dynamic> json) {
    return HistoryDayInfo(
      date: json['date'] as String,
      hasImages: json['hasImages'] as bool? ?? false,
      firstImage: json['firstImage'] as String?,
      quickNotesCount: json['quickNotesCount'] as int? ?? 0,
      exists: json['exists'] as bool? ?? false,
      hasContent: json['hasContent'] as bool? ?? false,
    );
  }
}
