import 'tag_config.dart';

/// 标签设置数据模型。
/// 管理每个标签的启用状态、自定义显示名称和本机删除状态。
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
      domainSettings: config.domains
          .map(
            (d) => DomainSetting(
              key: d.id,
              defaultName: d.name,
              displayName: d.name,
              enabled: true,
              description: d.description,
              topics: d.topics
                  .map(
                    (t) => TopicSetting(
                      key: t.id,
                      defaultName: t.name,
                      displayName: t.name,
                      enabled: true,
                      description: t.description,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
      methodSettings: config.methods
          .map(
            (m) => MethodSetting(
              key: m.id,
              defaultName: m.name,
              displayName: m.name,
              enabled: true,
              description: m.description,
            ),
          )
          .toList(),
    );
  }

  /// 生成当前设备实际可用的 TagConfig。
  ///
  /// 既保留远程配置中的元数据，也包含本机新增的标签。删除墓碑和未启用
  /// 的标签不会进入新记录，但仍保留在设置中供历史记录识别。
  TagConfig toEffectiveTagConfig(TagConfig source) {
    final sourceDomains = {
      for (final domain in source.domains) domain.id: domain,
    };
    final sourceMethods = {
      for (final method in source.methods) method.id: method,
    };
    final domains = <TagDomain>[];

    for (
      var domainIndex = 0;
      domainIndex < domainSettings.length;
      domainIndex++
    ) {
      final setting = domainSettings[domainIndex];
      if (!setting.enabled || setting.deleted) continue;

      final sourceDomain = sourceDomains[setting.key];
      final sourceTopics = {
        for (final topic in sourceDomain?.topics ?? const <TagTopic>[])
          topic.id: topic,
      };
      final topics = <TagTopic>[];
      for (
        var topicIndex = 0;
        topicIndex < setting.topics.length;
        topicIndex++
      ) {
        final topicSetting = setting.topics[topicIndex];
        if (!topicSetting.enabled || topicSetting.deleted) continue;
        final sourceTopic = sourceTopics[topicSetting.key];
        topics.add(
          TagTopic(
            id: topicSetting.key,
            name: topicSetting.displayName,
            description: sourceTopic?.description ?? topicSetting.description,
            order: sourceTopic?.order ?? topicIndex,
          ),
        );
      }

      domains.add(
        TagDomain(
          id: setting.key,
          name: setting.displayName,
          description: sourceDomain?.description ?? setting.description,
          order: sourceDomain?.order ?? domainIndex,
          topics: topics,
        ),
      );
    }

    final methods = <TagMethod>[];
    for (
      var methodIndex = 0;
      methodIndex < methodSettings.length;
      methodIndex++
    ) {
      final setting = methodSettings[methodIndex];
      if (!setting.enabled || setting.deleted) continue;
      final sourceMethod = sourceMethods[setting.key];
      methods.add(
        TagMethod(
          id: setting.key,
          name: setting.displayName,
          description: sourceMethod?.description ?? setting.description,
          order: sourceMethod?.order ?? methodIndex,
        ),
      );
    }

    return TagConfig(domains: domains, methods: methods);
  }

  factory TagSettings.fromJson(Map<String, dynamic> json) {
    return TagSettings(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      domainSettings:
          (json['domainSettings'] as List?)
              ?.map((d) => DomainSetting.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      methodSettings:
          (json['methodSettings'] as List?)
              ?.map((m) => MethodSetting.fromJson(m as Map<String, dynamic>))
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

  /// 本机删除墓碑。保留名称是为了编辑旧记录时不丢失历史标签。
  bool deleted;
  final List<TopicSetting> topics;

  /// 旧版本或远程配置中的可选说明，UI 不再展示或编辑。
  String? description;

  DomainSetting({
    required this.key,
    required this.defaultName,
    required this.displayName,
    this.enabled = true,
    this.deleted = false,
    required this.topics,
    this.description,
  });

  factory DomainSetting.fromJson(Map<String, dynamic> json) {
    return DomainSetting(
      key: json['key'] as String? ?? '',
      defaultName: json['defaultName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      deleted: json['deleted'] as bool? ?? false,
      description: json['description'] as String?,
      topics:
          (json['topics'] as List?)
              ?.map((t) => TopicSetting.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'defaultName': defaultName,
    'displayName': displayName,
    'enabled': enabled,
    'deleted': deleted,
    if (description != null) 'description': description,
    'topics': topics.map((t) => t.toJson()).toList(),
  };
}

class TopicSetting {
  final String key;
  final String defaultName;
  String displayName;
  bool enabled;

  /// 本机删除墓碑。保留名称是为了编辑旧记录时不丢失历史标签。
  bool deleted;

  /// 旧版本或远程配置中的可选说明，UI 不再展示或编辑。
  String? description;

  TopicSetting({
    required this.key,
    required this.defaultName,
    required this.displayName,
    this.enabled = true,
    this.deleted = false,
    this.description,
  });

  factory TopicSetting.fromJson(Map<String, dynamic> json) {
    return TopicSetting(
      key: json['key'] as String? ?? '',
      defaultName: json['defaultName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      deleted: json['deleted'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'defaultName': defaultName,
    'displayName': displayName,
    'enabled': enabled,
    'deleted': deleted,
    if (description != null) 'description': description,
  };
}

class MethodSetting {
  final String key;
  final String defaultName;
  String displayName;
  bool enabled;

  /// 本机删除墓碑。保留名称是为了编辑旧记录时不丢失历史标签。
  bool deleted;

  /// 旧版本或远程配置中的可选说明，UI 不再展示或编辑。
  String? description;

  MethodSetting({
    required this.key,
    required this.defaultName,
    required this.displayName,
    this.enabled = true,
    this.deleted = false,
    this.description,
  });

  factory MethodSetting.fromJson(Map<String, dynamic> json) {
    return MethodSetting(
      key: json['key'] as String? ?? '',
      defaultName: json['defaultName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      deleted: json['deleted'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'defaultName': defaultName,
    'displayName': displayName,
    'enabled': enabled,
    'deleted': deleted,
    if (description != null) 'description': description,
  };
}
