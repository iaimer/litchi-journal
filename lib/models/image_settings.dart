/// 图片上传与命名设置。
class ImageSettings {
  static const currentSchemaVersion = 1;

  static const maxLongSideOptions = [1280, 1600, 2000, 2560];
  static const targetSizeMbOptions = [1, 2, 3, 5];
  static const initialQualityOptions = [50, 60, 70, 80, 90];
  static const minLongSideOptions = [600, 800, 1000];

  static const defaultMaxLongSidePx = 2000;
  static const defaultTargetSizeMb = 3;
  static const defaultInitialQuality = 70;
  static const defaultMinLongSidePx = 800;
  static const defaultFilenamePrefix = 'Image';

  final int schemaVersion;
  final DateTime updatedAt;
  final int maxLongSidePx;
  final int targetSizeMb;
  final int initialQuality;
  final int minLongSidePx;
  final String filenamePrefix;

  ImageSettings({
    this.schemaVersion = currentSchemaVersion,
    DateTime? updatedAt,
    this.maxLongSidePx = defaultMaxLongSidePx,
    this.targetSizeMb = defaultTargetSizeMb,
    this.initialQuality = defaultInitialQuality,
    this.minLongSidePx = defaultMinLongSidePx,
    this.filenamePrefix = defaultFilenamePrefix,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory ImageSettings.defaults() => ImageSettings();

  factory ImageSettings.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int?;
    if (schemaVersion != currentSchemaVersion) {
      return ImageSettings.defaults();
    }

    final prefix = (json['filenamePrefix'] as String?)?.trim();
    return ImageSettings(
      schemaVersion: schemaVersion!,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      maxLongSidePx: _optionOrDefault(
        json['maxLongSidePx'],
        maxLongSideOptions,
        defaultMaxLongSidePx,
      ),
      targetSizeMb: _optionOrDefault(
        json['targetSizeMb'],
        targetSizeMbOptions,
        defaultTargetSizeMb,
      ),
      initialQuality: _optionOrDefault(
        json['initialQuality'],
        initialQualityOptions,
        defaultInitialQuality,
      ),
      minLongSidePx: _optionOrDefault(
        json['minLongSidePx'],
        minLongSideOptions,
        defaultMinLongSidePx,
      ),
      filenamePrefix: isValidFilenamePrefix(prefix)
          ? prefix!
          : defaultFilenamePrefix,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'updatedAt': updatedAt.toIso8601String(),
    'maxLongSidePx': maxLongSidePx,
    'targetSizeMb': targetSizeMb,
    'initialQuality': initialQuality,
    'minLongSidePx': minLongSidePx,
    'filenamePrefix': filenamePrefix,
  };

  int get targetBytes => targetSizeMb * 1024 * 1024;

  ImageSettings copyWith({
    DateTime? updatedAt,
    int? maxLongSidePx,
    int? targetSizeMb,
    int? initialQuality,
    int? minLongSidePx,
    String? filenamePrefix,
  }) {
    return ImageSettings(
      schemaVersion: schemaVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      maxLongSidePx: maxLongSidePx ?? this.maxLongSidePx,
      targetSizeMb: targetSizeMb ?? this.targetSizeMb,
      initialQuality: initialQuality ?? this.initialQuality,
      minLongSidePx: minLongSidePx ?? this.minLongSidePx,
      filenamePrefix: filenamePrefix ?? this.filenamePrefix,
    );
  }

  static bool isValidFilenamePrefix(String? value) {
    final trimmed = value?.trim() ?? '';
    return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trimmed);
  }

  static int _optionOrDefault(Object? value, List<int> options, int fallback) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return options.contains(parsed) ? parsed! : fallback;
  }
}
