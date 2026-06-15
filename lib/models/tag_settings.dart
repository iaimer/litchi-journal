import 'tag_config.dart';

/// 标签设置数据模型。
/// 管理每个标签的启用状态和自定义显示名称。
/// 稳定 key 使用 id，displayName 用于 UI 显示和未来 Markdown 写入。
class TagSettings {
  final int schemaVersion;
  final DateTime updatedAt;
  final List<DomainSetting> domainSettings;
  final List<MethodSetting> methodSettings;

  TagSettings({
    this.schemaVersion = 1,
    DateTime? updatedAt,
    required this.domainSettings,
    required this.methodSettings,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// 从 TagConfig 生成默认设置（全部启用，displayName = name）。
  factory TagSettings.fromTagConfig(TagConfig config) {
    return TagSettings(
      domainSettings: config.domains.map((d) => DomainSetting(
        key: d.id,
        defaultName: d.name,
        displayName: d.name,
        enabled: true,
        topics: d.topics.map((t) => TopicSetting(
          key: t.id,
          defaultName: t.name,
          displayName: t.name,
          enabled: true,
        )).toList(),
      )).toList(),
      methodSettings: config.methods.map((m) => MethodSetting(
        key: m.id,
        defaultName: m.name,
        displayName: m.name,
        enabled: true,
      )).toList(),
    );
  }

  /// 生成只含 enabled 标签的 TagConfig，name 替换为 displayName。
  TagConfig toEffectiveTagConfig(TagConfig source) {
    final domainMap = {
      for (final d in domainSettings.where((d) => d.enabled)) d.key: d,
    };
    final topicMap = {
      for (final d in domainSettings)
        for (final t in d.topics.where((t) => t.enabled)) t.key: t,
    };
    final methodMap = {
      for (final m in methodSettings.where((m) => m.enabled)) m.key: m,
    };

    return TagConfig(
      domains: source.domains
          .where((d) => domainMap.containsKey(d.id))
          .map((d) {
        final setting = domainMap[d.id]!;
        return TagDomain(
          id: d.id,
          name: setting.displayName,
          description: d.description,
          order: d.order,
          topics: d.topics
              .where((t) => topicMap.containsKey(t.id))
              .map((t) {
            final ts = topicMap[t.id]!;
            return TagTopic(
              id: t.id,
              name: ts.displayName,
              description: t.description,
              order: t.order,
            );
          }).toList(),
        );
      }).toList(),
      methods: source.methods
          .where((m) => methodMap.containsKey(m.id))
          .map((m) {
        final setting = methodMap[m.id]!;
        return TagMethod(
          id: m.id,
          name: setting.displayName,
          description: m.description,
          order: m.order,
        );
      }).toList(),
    );
  }

  factory TagSettings.fromJson(Map<String, dynamic> json) {
    return TagSettings(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      domainSettings: (json['domainSettings'] as List?)
              ?.map((d) =>
                  DomainSetting.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      methodSettings: (json['methodSettings'] as List?)
              ?.map((m) =>
                  MethodSetting.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'updatedAt': updatedAt.toIso8601String(),
        'domainSettings': domainSettings.map((d) => d.toJson()).toList(),
        'methodSettings': methodSettings.map((m) => m.toJson()).toList(),
      };
}

class DomainSetting {
  final String key;
  final String defaultName;
  String displayName;
  bool enabled;
  final List<TopicSetting> topics;

  DomainSetting({
    required this.key,
    required this.defaultName,
    required this.displayName,
    this.enabled = true,
    required this.topics,
  });

  factory DomainSetting.fromJson(Map<String, dynamic> json) {
    return DomainSetting(
      key: json['key'] as String? ?? '',
      defaultName: json['defaultName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      topics: (json['topics'] as List?)
              ?.map(
                  (t) => TopicSetting.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'defaultName': defaultName,
        'displayName': displayName,
        'enabled': enabled,
        'topics': topics.map((t) => t.toJson()).toList(),
      };
}

class TopicSetting {
  final String key;
  final String defaultName;
  String displayName;
  bool enabled;

  TopicSetting({
    required this.key,
    required this.defaultName,
    required this.displayName,
    this.enabled = true,
  });

  factory TopicSetting.fromJson(Map<String, dynamic> json) {
    return TopicSetting(
      key: json['key'] as String? ?? '',
      defaultName: json['defaultName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'defaultName': defaultName,
        'displayName': displayName,
        'enabled': enabled,
      };
}

class MethodSetting {
  final String key;
  final String defaultName;
  String displayName;
  bool enabled;

  MethodSetting({
    required this.key,
    required this.defaultName,
    required this.displayName,
    this.enabled = true,
  });

  factory MethodSetting.fromJson(Map<String, dynamic> json) {
    return MethodSetting(
      key: json['key'] as String? ?? '',
      defaultName: json['defaultName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'defaultName': defaultName,
        'displayName': displayName,
        'enabled': enabled,
      };
}
