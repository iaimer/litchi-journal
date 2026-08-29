class GalleryPage {
  final List<GalleryMonth> months;
  final String? nextCursor;

  const GalleryPage({required this.months, this.nextCursor});

  factory GalleryPage.fromJson(Map<String, dynamic> json) {
    final rawMonths = json['months'];
    final months = rawMonths is List
        ? rawMonths
              .whereType<Map<String, dynamic>>()
              .map(GalleryMonth.fromJson)
              .toList()
        : <GalleryMonth>[];
    return GalleryPage(
      months: months,
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class GalleryMonth {
  final int year;
  final int month;
  final int totalDays;
  final int totalImages;
  final List<GalleryDay> days;

  const GalleryMonth({
    required this.year,
    required this.month,
    required this.totalDays,
    required this.totalImages,
    required this.days,
  });

  factory GalleryMonth.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final days = rawDays is List
        ? rawDays
              .whereType<Map<String, dynamic>>()
              .map(GalleryDay.fromJson)
              .toList()
        : <GalleryDay>[];
    return GalleryMonth(
      year: _asInt(json['year']),
      month: _asInt(json['month']),
      totalDays: _asInt(json['totalDays']),
      totalImages: _asInt(json['totalImages']),
      days: days,
    );
  }

  DateTime get date => DateTime(year, month);

  static int _asInt(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}

class GalleryDay {
  final String date;
  final List<String> images;
  final bool hasContent;

  const GalleryDay({
    required this.date,
    required this.images,
    required this.hasContent,
  });

  factory GalleryDay.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    final images = rawImages is List
        ? rawImages
              .whereType<String>()
              .where((name) => name.isNotEmpty)
              .toList()
        : <String>[];
    return GalleryDay(
      date: json['date'] as String? ?? '',
      images: images,
      hasContent: json['hasContent'] as bool? ?? false,
    );
  }

  String? get firstImage => images.isEmpty ? null : images.first;

  DateTime get dateTime {
    final parts = date.split('-');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime(1970);
  }
}
