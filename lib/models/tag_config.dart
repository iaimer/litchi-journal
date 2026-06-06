Map<String, dynamic> _castMap(dynamic source) {
  return Map<String, dynamic>.from(source is Map ? source : {});
}

class TagConfig {
  final List<TagDomain> domains;
  final List<TagMethod> methods;

  const TagConfig({
    required this.domains,
    required this.methods,
  });

  factory TagConfig.fromJson(Map<String, dynamic> json) {
    final rawDomains = json['domains'];
    final rawMethods = json['methods'];

    return TagConfig(
      domains: rawDomains is List
          ? rawDomains
              .map((d) => TagDomain.fromJson(_castMap(d)))
              .toList(growable: false)
          : [],
      methods: rawMethods is List
          ? rawMethods
              .map((m) => TagMethod.fromJson(_castMap(m)))
              .toList(growable: false)
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'domains': domains.map((d) => d.toJson()).toList(growable: false),
        'methods': methods.map((m) => m.toJson()).toList(growable: false),
      };
}

class TagDomain {
  final String id;
  final String name;
  final String? description;
  final int order;
  final List<TagTopic> topics;

  const TagDomain({
    required this.id,
    required this.name,
    this.description,
    required this.order,
    required this.topics,
  });

  factory TagDomain.fromJson(Map<String, dynamic> json) {
    final rawTopics = json['topics'];

    return TagDomain(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      order: json['order'] as int? ?? 0,
      topics: rawTopics is List
          ? rawTopics
              .map((t) => TagTopic.fromJson(_castMap(t)))
              .toList(growable: false)
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'order': order,
        'topics': topics.map((t) => t.toJson()).toList(growable: false),
      };
}

class TagTopic {
  final String id;
  final String name;
  final String? description;
  final int order;

  const TagTopic({
    required this.id,
    required this.name,
    this.description,
    required this.order,
  });

  factory TagTopic.fromJson(Map<String, dynamic> json) {
    return TagTopic(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'order': order,
      };
}

class TagMethod {
  final String id;
  final String name;
  final String? description;
  final int order;

  const TagMethod({
    required this.id,
    required this.name,
    this.description,
    required this.order,
  });

  factory TagMethod.fromJson(Map<String, dynamic> json) {
    return TagMethod(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'order': order,
      };
}
