class AIConfig {
  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String? polishPrompt;

  const AIConfig({
    this.enabled = false,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.polishPrompt,
  });

  bool get isUsable =>
      enabled && baseUrl.isNotEmpty && apiKey.isNotEmpty && model.isNotEmpty;

  factory AIConfig.fromJson(Map<String, dynamic> json) {
    return AIConfig(
      enabled: json['enabled'] as bool? ?? false,
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? '',
      polishPrompt: json['polishPrompt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        if (polishPrompt != null) 'polishPrompt': polishPrompt,
      };

  @override
  String toString() =>
      'AIConfig(enabled: $enabled, baseUrl: $baseUrl, model: $model, polishPrompt: ${polishPrompt != null ? 'set' : 'null'})';
}
