import 'habit_visual_config.dart';

/// 习惯设置：管理习惯的显示状态和视觉配置。
///
/// 支持：
/// - statusMap: active / archived
/// - displayNameMap: 自定义显示名称
/// - iconMap: 自定义图标
/// - colorMap: 自定义颜色（存储为 int ARGB）
/// - extraHabits: 自定义习惯注册表（customKey → 初始显示名）
///
/// schemaVersion: 3（新增 extraHabits）
class HabitSettings {
  /// schema 版本，用于兼容旧配置。
  static const schemaVersion = 3;

  /// 习惯 key → isActive
  final Map<String, bool> statusMap;

  /// 习惯 key → 自定义显示名称
  final Map<String, String> displayNameMap;

  /// 习惯 key → 自定义图标
  final Map<String, String> iconMap;

  /// 习惯 key → 自定义颜色 ARGB int
  final Map<String, int> colorMap;

  /// 自定义习惯注册表：customKey → 初始显示名。
  /// 仅存储 key 和默认名。状态、图标、颜色仍用 statusMap / iconMap / colorMap 管理。
  final Map<String, String> extraHabits;

  const HabitSettings({
    required this.statusMap,
    this.displayNameMap = const {},
    this.iconMap = const {},
    this.colorMap = const {},
    this.extraHabits = const {},
  });

  /// 5 个默认习惯全部活跃，视觉配置使用默认值。
  static const defaults = HabitSettings(
    statusMap: {
      'water': true,
      'steps': true,
      'reading': true,
      'language': true,
      'supplements': true,
    },
  );

  // ── 状态查询 ──

  /// 该习惯当前是否活跃
  bool isActive(String key) => statusMap[key] ?? true;

  /// 所有活跃的 manageable 习惯 key 列表。
  /// 只统计 manageableKeys 中 status=true 的 key，过滤 orphan custom_xxx。
  List<String> get activeKeys {
    final manageable = manageableKeys.toSet();
    return statusMap.entries
        .where((e) => e.value && manageable.contains(e.key))
        .map((e) => e.key)
        .toList();
  }

  /// 活跃习惯数量
  int get activeCount => activeKeys.length;

  /// 所有可管理习惯的 key：5 个内置 + 所有已注册自定义习惯。
  /// 今日页用 activeKeys，设置页用此列表确保归档习惯不丢失。
  List<String> get manageableKeys =>
      [...HabitVisualConfig.defaults.keys, ...extraHabits.keys];

  // ── 视觉配置 ──

  /// 获取显示名称。优先自定义名 → extraHabits 初始名 → 默认。
  String displayNameFor(String key) =>
      displayNameMap[key] ??
      extraHabits[key] ??
      HabitVisualConfig.of(key).displayName;

  /// 获取图标，无自定义时返回默认。
  String iconFor(String key) => iconMap[key] ?? HabitVisualConfig.of(key).icon;

  /// 获取颜色，无自定义时返回默认。
  int colorFor(String key) =>
      colorMap[key] ?? HabitVisualConfig.of(key).color.toARGB32();

  // ── 修改方法 ──

  /// 更新单个习惯的全部字段。
  HabitSettings updateHabit({
    required String key,
    bool? active,
    String? displayName,
    String? icon,
    int? color,
  }) {
    final newStatus = Map<String, bool>.from(statusMap);
    if (active != null) newStatus[key] = active;

    final newDisplayName = Map<String, String>.from(displayNameMap);
    if (displayName != null) {
      final trimmed = displayName.trim();
      if (trimmed.isNotEmpty &&
          trimmed != HabitVisualConfig.of(key).displayName) {
        newDisplayName[key] = trimmed;
      } else {
        newDisplayName.remove(key);
      }
    }

    final newIcon = Map<String, String>.from(iconMap);
    if (icon != null) {
      if (icon != HabitVisualConfig.of(key).icon) {
        newIcon[key] = icon;
      } else {
        newIcon.remove(key);
      }
    }

    final newColor = Map<String, int>.from(colorMap);
    if (color != null) {
      if (color != HabitVisualConfig.of(key).color.toARGB32()) {
        newColor[key] = color;
      } else {
        newColor.remove(key);
      }
    }

    return HabitSettings(
      statusMap: newStatus,
      displayNameMap: newDisplayName,
      iconMap: newIcon,
      colorMap: newColor,
      extraHabits: extraHabits,
    );
  }

  /// 恢复单个习惯为默认值（名称、图标、颜色、状态）。
  HabitSettings resetHabit(String key) {
    final newStatus = Map<String, bool>.from(statusMap);
    newStatus[key] = true;

    final newDisplayName = Map<String, String>.from(displayNameMap);
    newDisplayName.remove(key);

    final newIcon = Map<String, String>.from(iconMap);
    newIcon.remove(key);

    final newColor = Map<String, int>.from(colorMap);
    newColor.remove(key);

    return HabitSettings(
      statusMap: newStatus,
      displayNameMap: newDisplayName,
      iconMap: newIcon,
      colorMap: newColor,
      extraHabits: extraHabits,
    );
  }

  /// 重置为只保留 5 个内置习惯。
  HabitSettings resetAll() => HabitSettings.defaults;

  /// 使用部分更新创建新副本。
  HabitSettings copyWith({
    Map<String, bool>? statusMap,
    Map<String, String>? displayNameMap,
    Map<String, String>? iconMap,
    Map<String, int>? colorMap,
    Map<String, String>? extraHabits,
  }) {
    return HabitSettings(
      statusMap: statusMap ?? this.statusMap,
      displayNameMap: displayNameMap ?? this.displayNameMap,
      iconMap: iconMap ?? this.iconMap,
      colorMap: colorMap ?? this.colorMap,
      extraHabits: extraHabits ?? this.extraHabits,
    );
  }

  // ── 序列化 ──

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'statusMap': statusMap,
    'displayNameMap': displayNameMap,
    'iconMap': iconMap,
    'colorMap': colorMap,
    'extraHabits': extraHabits,
  };

  factory HabitSettings.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 0;

    // 解析 statusMap
    final rawStatus = json['statusMap'] as Map<String, dynamic>? ?? {};
    final statusMap = <String, bool>{};
    for (final entry in rawStatus.entries) {
      statusMap[entry.key] = entry.value as bool? ?? true;
    }

    // 兼容旧配置（schemaVersion < 2）：缺失的 visual 字段自动补默认
    if (version < 2) {
      return HabitSettings(statusMap: statusMap);
    }

    // 版本 2 解析
    final settings = _parseV2(statusMap, json);

    // 版本 3：无 extraHabits 时默认 {}
    if (version < 3) return settings;

    final rawExtra = json['extraHabits'] as Map<String, dynamic>? ?? {};
    final extraHabits = <String, String>{};
    for (final entry in rawExtra.entries) {
      extraHabits[entry.key] = entry.value as String? ?? '';
    }

    return settings.copyWith(extraHabits: extraHabits);
  }

  static HabitSettings _parseV2(
    Map<String, bool> statusMap,
    Map<String, dynamic> json,
  ) {
    final rawDisplayName =
        json['displayNameMap'] as Map<String, dynamic>? ?? {};
    final displayNameMap = <String, String>{};
    for (final entry in rawDisplayName.entries) {
      displayNameMap[entry.key] = entry.value as String? ?? '';
    }

    final rawIcon = json['iconMap'] as Map<String, dynamic>? ?? {};
    final iconMap = <String, String>{};
    for (final entry in rawIcon.entries) {
      iconMap[entry.key] = entry.value as String? ?? '';
    }

    final rawColor = json['colorMap'] as Map<String, dynamic>? ?? {};
    final colorMap = <String, int>{};
    for (final entry in rawColor.entries) {
      colorMap[entry.key] = (entry.value as num?)?.toInt() ?? 0;
    }

    return HabitSettings(
      statusMap: statusMap,
      displayNameMap: displayNameMap,
      iconMap: iconMap,
      colorMap: colorMap,
    );
  }
}
