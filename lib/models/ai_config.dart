class AIConfig {
  final bool enabled;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String? polishPrompt;

  const AIConfig({
    this.enabled = false,
    this.name = '',
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
      name: json['name'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? '',
      polishPrompt: json['polishPrompt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        if (polishPrompt != null) 'polishPrompt': polishPrompt,
      };

  @override
  String toString() =>
      'AIConfig(enabled: $enabled, name: $name, baseUrl: $baseUrl, model: $model, polishPrompt: ${polishPrompt != null ? 'set' : 'null'})';
}

class AIPreset {
  final String name;
  final String baseUrl;
  final String model;

  const AIPreset({
    required this.name,
    required this.baseUrl,
    required this.model,
  });
}

const aiPresets = [
  AIPreset(
    name: 'OpenAI API',
    baseUrl: 'https://api.openai.com',
    model: 'gpt-4o-mini',
  ),
  AIPreset(
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    model: 'deepseek-chat',
  ),
  AIPreset(
    name: 'Moonshot',
    baseUrl: 'https://api.moonshot.cn',
    model: 'moonshot-v1-8k',
  ),
  AIPreset(
    name: '本地 Ollama',
    baseUrl: 'http://localhost:11434',
    model: 'qwen2.5:7b',
  ),
];
