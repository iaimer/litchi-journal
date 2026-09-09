import 'habit_visual_config.dart';

/// 习惯在今天页上的记录方式。
enum HabitTrackingType { checkbox, counter, duration }

/// 习惯设置：管理习惯的显示状态和视觉配置。
///
/// 支持：
/// - statusMap: active / archived
/// - displayNameMap: 自定义显示名称
/// - iconMap: 自定义图标
/// - colorMap: 自定义颜色（存储为 int ARGB）
/// - targetMap: 内置计数习惯的每日目标（仅支持 water / steps）
/// - trackingTypeMap: 可切换习惯的记录方式（checkbox / duration）
/// - durationDailyTargetMap: 计时型习惯的每日目标（分钟）
/// - durationLifetimeTargetMap: 计时型习惯的长期目标（分钟）
/// - extraHabits: 自定义习惯注册表（customKey → 初始显示名）
/// - customHabitAliases: 自定义习惯历史名称（用于统计时匹配 Markdown）
///
/// schemaVersion: 7（新增计时型习惯配置）
class HabitSettings {
  /// schema 版本，用于兼容旧配置。
  static const schemaVersion = 7;

  /// 首页进度条使用的默认每日目标，目标仅属于现有内置计数习惯。
  static const defaultTargets = <String, int>{'water': 1500, 'steps': 6000};

  /// 与服务端计数写入上限保持一致，避免异常配置破坏首页布局。
  static const maxCounterTarget = 500000;
  static const maxDurationTarget = 500000;

  static const defaultWaterQuickAmounts = <int>[250, 475, 500];

  /// 习惯 key → isActive
  final Map<String, bool> statusMap;

  /// 习惯 key → 自定义显示名称
  final Map<String, String> displayNameMap;

  /// 习惯 key → 自定义图标
  final Map<String, String> iconMap;

  /// 习惯 key → 自定义颜色 ARGB int
  final Map<String, int> colorMap;

  /// 内置计数习惯 key → 每日目标。
  /// 只保存用户改过且不同于默认值的覆盖项。
  final Map<String, int> targetMap;

  /// 可切换习惯 key → 记录方式。
  /// 缺省规则：reading / language 为 duration，其他可切换习惯为 checkbox。
  final Map<String, HabitTrackingType> trackingTypeMap;

  /// 计时型习惯 key → 每日目标分钟数，未配置表示不设目标。
  final Map<String, int> durationDailyTargetMap;

  /// 计时型习惯 key → 长期累计目标分钟数，未配置表示不设目标。
  final Map<String, int> durationLifetimeTargetMap;

  /// 饮水快捷添加量，始终为 3 个升序、不重复的正整数。
  final List<int> waterQuickAmounts;

  /// 自定义习惯注册表：customKey → 初始显示名。
  /// 仅存储 key 和默认名。状态、图标、颜色仍用 statusMap / iconMap / colorMap 管理。
  final Map<String, String> extraHabits;

  /// 自定义习惯历史名称映射：customKey → [历史名称列表]。
  /// 包含当前名称和历史曾用名，新建时初始化为 [当前名称]，
  /// 重命名时将新名称追加到末尾。用于统计时按名称匹配 Markdown 行。
  final Map<String, List<String>> customHabitAliases;

  const HabitSettings({
    required this.statusMap,
    this.displayNameMap = const {},
    this.iconMap = const {},
    this.colorMap = const {},
    this.targetMap = const {},
    this.trackingTypeMap = const {},
    this.durationDailyTargetMap = const {},
    this.durationLifetimeTargetMap = const {},
    this.waterQuickAmounts = defaultWaterQuickAmounts,
    this.extraHabits = const {},
    this.customHabitAliases = const {},
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
  List<String> get manageableKeys => [
    ...HabitVisualConfig.defaults.keys,
    ...extraHabits.keys,
  ];

  // ── 视觉配置 ──

  /// 所有习惯的最终显示名称集合（trim 后）。
  /// 若 [excludeKey] 不为 null，排除该习惯的显示名称。
  Set<String> allDisplayNames({String? excludeKey}) {
    return manageableKeys
        .where((key) => key != excludeKey)
        .map((key) => displayNameFor(key).trim())
        .toSet();
  }

  /// 获取显示名称。优先自定义名 → extraHabits 初始名 → 默认。
  String displayNameFor(String key) =>
      displayNameMap[key] ??
      extraHabits[key] ??
      HabitVisualConfig.of(key).displayName;

  /// 从 Markdown 习惯行的 label 中匹配自定义习惯 key。
  ///
  /// 习惯行可能带有 `📝` 等图标前缀；重命名后的旧名称则通过 aliases
  /// 继续匹配。集中在设置模型中，避免首页和统计页各自使用不同口径。
  String? customHabitKeyForLabel(String label) {
    final normalized = _normalizeCustomHabitLabel(label);
    if (normalized.isEmpty) return null;

    for (final key in extraHabits.keys) {
      final names = <String>{
        displayNameFor(key),
        extraHabits[key] ?? '',
        ...(customHabitAliases[key] ?? const <String>[]),
      };
      if (names.any(
        (name) =>
            name.trim().isNotEmpty &&
            _normalizeCustomHabitLabel(name) == normalized,
      )) {
        return key;
      }
    }
    return null;
  }

  static String _normalizeCustomHabitLabel(String label) {
    final text = label.trim();
    for (var i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if ((codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||
          (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) ||
          (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
          (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
          (codeUnit >= 0x30 && codeUnit <= 0x39) ||
          codeUnit == 0x2F ||
          codeUnit == 0x2D) {
        return text.substring(i).trim();
      }
    }
    return text;
  }

  /// 获取图标，无自定义时返回默认。
  String iconFor(String key) => iconMap[key] ?? HabitVisualConfig.of(key).icon;

  /// 获取颜色，无自定义时返回默认。
  int colorFor(String key) =>
      colorMap[key] ?? HabitVisualConfig.of(key).color.toARGB32();

  /// 获取每日目标。checkbox 和自定义习惯没有目标，返回 null。
  int? targetFor(String key) {
    if (!defaultTargets.containsKey(key)) return null;
    final target = targetMap[key];
    return target != null && target > 0 && target <= maxCounterTarget
        ? target
        : defaultTargets[key];
  }

  /// 获取习惯记录方式。阅读和学语言在旧配置中也按计时型处理。
  HabitTrackingType trackingTypeFor(String key) {
    if (key == 'water' || key == 'steps') return HabitTrackingType.counter;
    if (!supportsDurationFor(key)) return HabitTrackingType.checkbox;
    final configured = trackingTypeMap[key];
    if (configured != null) return configured;
    if (key == 'reading' || key == 'language') {
      return HabitTrackingType.duration;
    }
    return HabitTrackingType.checkbox;
  }

  /// 目前只有阅读、学语言和自定义习惯支持累计时长。
  static bool supportsDurationFor(String key) {
    return key == 'reading' || key == 'language' || key.startsWith('custom_');
  }

  /// 获取计时型习惯每日目标，未设置时返回 null。
  int? durationDailyTargetFor(String key) {
    if (trackingTypeFor(key) != HabitTrackingType.duration) return null;
    return _validDurationTarget(durationDailyTargetMap[key]);
  }

  /// 获取计时型习惯长期目标，未设置时返回 null。
  int? durationLifetimeTargetFor(String key) {
    if (trackingTypeFor(key) != HabitTrackingType.duration) return null;
    return _validDurationTarget(durationLifetimeTargetMap[key]);
  }

  // ── 修改方法 ──

  /// 更新单个习惯的全部字段。
  HabitSettings updateHabit({
    required String key,
    bool? active,
    String? displayName,
    String? icon,
    int? color,
    int? target,
    HabitTrackingType? trackingType,
    int? durationDailyTargetMinutes,
    int? durationLifetimeTargetMinutes,
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

    final newTargets = Map<String, int>.from(targetMap);
    if (target != null && defaultTargets.containsKey(key)) {
      if (target > 0 &&
          target <= maxCounterTarget &&
          target != defaultTargets[key]) {
        newTargets[key] = target;
      } else {
        newTargets.remove(key);
      }
    }

    final newTrackingTypes = Map<String, HabitTrackingType>.from(
      trackingTypeMap,
    );
    if (trackingType != null &&
        supportsDurationFor(key) &&
        key != 'water' &&
        key != 'steps' &&
        trackingType != HabitTrackingType.counter) {
      final defaultType = key == 'reading' || key == 'language'
          ? HabitTrackingType.duration
          : HabitTrackingType.checkbox;
      if (trackingType == defaultType) {
        newTrackingTypes.remove(key);
      } else {
        newTrackingTypes[key] = trackingType;
      }
    } else if (trackingType != null) {
      newTrackingTypes.remove(key);
    }

    final newDurationDailyTargets = Map<String, int>.from(
      durationDailyTargetMap,
    );
    if (durationDailyTargetMinutes != null) {
      if (supportsDurationFor(key)) {
        _updateDurationTarget(
          newDurationDailyTargets,
          key,
          durationDailyTargetMinutes,
        );
      } else {
        newDurationDailyTargets.remove(key);
      }
    }

    final newDurationLifetimeTargets = Map<String, int>.from(
      durationLifetimeTargetMap,
    );
    if (durationLifetimeTargetMinutes != null) {
      if (supportsDurationFor(key)) {
        _updateDurationTarget(
          newDurationLifetimeTargets,
          key,
          durationLifetimeTargetMinutes,
        );
      } else {
        newDurationLifetimeTargets.remove(key);
      }
    }

    return HabitSettings(
      statusMap: newStatus,
      displayNameMap: newDisplayName,
      iconMap: newIcon,
      colorMap: newColor,
      targetMap: newTargets,
      trackingTypeMap: newTrackingTypes,
      durationDailyTargetMap: newDurationDailyTargets,
      durationLifetimeTargetMap: newDurationLifetimeTargets,
      waterQuickAmounts: waterQuickAmounts,
      extraHabits: extraHabits,
      customHabitAliases: customHabitAliases,
    );
  }

  /// 返回当前 customHabitAliases 中指定 key 的别名列表尾部追加 [newName] 的新副本。
  /// 如果 [newName] 已存在于别名列表中，不重复追加。
  /// [newName] 应在传入前已 trim。
  HabitSettings appendHabitAlias({
    required String key,
    required String newName,
  }) {
    if (newName.trim().isEmpty) return this;
    final newAliases = Map<String, List<String>>.from(customHabitAliases);
    final existing = List<String>.from(newAliases[key] ?? []);
    if (!existing.contains(newName.trim())) {
      newAliases[key] = [...existing, newName.trim()];
    }
    return copyWith(customHabitAliases: newAliases);
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

    final newTargets = Map<String, int>.from(targetMap);
    newTargets.remove(key);

    final newTrackingTypes = Map<String, HabitTrackingType>.from(
      trackingTypeMap,
    )..remove(key);
    final newDurationDailyTargets = Map<String, int>.from(
      durationDailyTargetMap,
    )..remove(key);
    final newDurationLifetimeTargets = Map<String, int>.from(
      durationLifetimeTargetMap,
    )..remove(key);

    return HabitSettings(
      statusMap: newStatus,
      displayNameMap: newDisplayName,
      iconMap: newIcon,
      colorMap: newColor,
      targetMap: newTargets,
      trackingTypeMap: newTrackingTypes,
      durationDailyTargetMap: newDurationDailyTargets,
      durationLifetimeTargetMap: newDurationLifetimeTargets,
      waterQuickAmounts: key == 'water'
          ? defaultWaterQuickAmounts
          : waterQuickAmounts,
      extraHabits: extraHabits,
      customHabitAliases: customHabitAliases,
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
    Map<String, int>? targetMap,
    Map<String, HabitTrackingType>? trackingTypeMap,
    Map<String, int>? durationDailyTargetMap,
    Map<String, int>? durationLifetimeTargetMap,
    List<int>? waterQuickAmounts,
    Map<String, String>? extraHabits,
    Map<String, List<String>>? customHabitAliases,
  }) {
    return HabitSettings(
      statusMap: statusMap ?? this.statusMap,
      displayNameMap: displayNameMap ?? this.displayNameMap,
      iconMap: iconMap ?? this.iconMap,
      colorMap: colorMap ?? this.colorMap,
      targetMap: targetMap ?? this.targetMap,
      trackingTypeMap: trackingTypeMap ?? this.trackingTypeMap,
      durationDailyTargetMap:
          durationDailyTargetMap ?? this.durationDailyTargetMap,
      durationLifetimeTargetMap:
          durationLifetimeTargetMap ?? this.durationLifetimeTargetMap,
      waterQuickAmounts: waterQuickAmounts ?? this.waterQuickAmounts,
      extraHabits: extraHabits ?? this.extraHabits,
      customHabitAliases: customHabitAliases ?? this.customHabitAliases,
    );
  }

  // ── 序列化 ──

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'statusMap': statusMap,
    'displayNameMap': displayNameMap,
    'iconMap': iconMap,
    'colorMap': colorMap,
    'targetMap': Map.fromEntries(
      targetMap.entries.where(
        (entry) =>
            defaultTargets.containsKey(entry.key) &&
            entry.value > 0 &&
            entry.value <= maxCounterTarget,
      ),
    ),
    'trackingTypeMap': {
      for (final entry in trackingTypeMap.entries)
        if (entry.key != 'water' && entry.key != 'steps')
          entry.key: entry.value.name,
    },
    'durationDailyTargetMap': _validTargetMap(durationDailyTargetMap),
    'durationLifetimeTargetMap': _validTargetMap(durationLifetimeTargetMap),
    'waterQuickAmounts': waterQuickAmounts,
    'extraHabits': extraHabits,
    'customHabitAliases': customHabitAliases,
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

    var v3Settings = settings.copyWith(extraHabits: extraHabits);

    // 版本 4：无 customHabitAliases 时默认 {}
    if (version < 4) return v3Settings;

    final rawAliases =
        json['customHabitAliases'] as Map<String, dynamic>? ?? {};
    final customHabitAliases = <String, List<String>>{};
    for (final entry in rawAliases.entries) {
      if (entry.value is List) {
        customHabitAliases[entry.key] = (entry.value as List)
            .whereType<String>()
            .toList();
      }
    }

    final v4Settings = v3Settings.copyWith(
      customHabitAliases: customHabitAliases,
    );

    // 版本 5：无 targetMap 时使用默认目标；只接受内置计数习惯的正整数。
    if (version < 5) return v4Settings;

    final targetMap = <String, int>{};
    final rawTargets = json['targetMap'];
    if (rawTargets is Map) {
      for (final entry in rawTargets.entries) {
        final key = entry.key;
        final value = entry.value is num ? (entry.value as num).toInt() : null;
        if (key is String &&
            defaultTargets.containsKey(key) &&
            value != null &&
            value > 0 &&
            value <= maxCounterTarget) {
          targetMap[key] = value;
        }
      }
    }

    final v5Settings = v4Settings.copyWith(targetMap: targetMap);
    if (version < 6) return v5Settings;

    final v6Settings = v5Settings.copyWith(
      waterQuickAmounts: _parseWaterQuickAmounts(json['waterQuickAmounts']),
    );
    if (version < 7) return v6Settings;

    final trackingTypeMap = _parseTrackingTypeMap(json['trackingTypeMap']);
    final durationDailyTargetMap = _parseDurationTargetMap(
      json['durationDailyTargetMap'],
    );
    final durationLifetimeTargetMap = _parseDurationTargetMap(
      json['durationLifetimeTargetMap'],
    );
    return v6Settings.copyWith(
      trackingTypeMap: trackingTypeMap,
      durationDailyTargetMap: durationDailyTargetMap,
      durationLifetimeTargetMap: durationLifetimeTargetMap,
    );
  }

  static int? _validDurationTarget(int? value) {
    if (value == null || value <= 0 || value > maxDurationTarget) return null;
    return value;
  }

  static void _updateDurationTarget(
    Map<String, int> targetMap,
    String key,
    int value,
  ) {
    final valid = _validDurationTarget(value);
    if (valid == null) {
      targetMap.remove(key);
    } else {
      targetMap[key] = valid;
    }
  }

  static Map<String, int> _validTargetMap(Map<String, int> source) {
    return Map.fromEntries(
      source.entries.where(
        (entry) =>
            _validDurationTarget(entry.value) != null &&
            entry.key != 'water' &&
            entry.key != 'steps',
      ),
    );
  }

  static Map<String, HabitTrackingType> _parseTrackingTypeMap(Object? raw) {
    if (raw is! Map) return {};
    final result = <String, HabitTrackingType>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! String) continue;
      if (!supportsDurationFor(entry.key as String)) continue;
      final type = HabitTrackingType.values.where(
        (candidate) => candidate.name == entry.value,
      );
      if (type.isEmpty || type.single == HabitTrackingType.counter) continue;
      result[entry.key as String] = type.single;
    }
    return result;
  }

  static Map<String, int> _parseDurationTargetMap(Object? raw) {
    if (raw is! Map) return {};
    final result = <String, int>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! num) continue;
      final value = (entry.value as num).toInt();
      if (entry.value != value) continue;
      final valid = _validDurationTarget(value);
      if (valid != null) result[entry.key as String] = valid;
    }
    return result;
  }

  static List<int> _parseWaterQuickAmounts(Object? raw) {
    if (raw is! List || raw.length != 3) return defaultWaterQuickAmounts;
    final numericValues = raw.whereType<num>().toList();
    if (numericValues.any((value) => value != value.toInt())) {
      return defaultWaterQuickAmounts;
    }
    final values = numericValues.map((value) => value.toInt()).toList();
    if (values.length != 3 ||
        values.any((value) => value <= 0 || value > maxCounterTarget) ||
        values.toSet().length != 3) {
      return defaultWaterQuickAmounts;
    }
    values.sort();
    return values;
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
