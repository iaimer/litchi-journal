import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_config.dart';
import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../widgets/entry_type.dart';
import 'polish_result_parser.dart';

class PolisherService {
  final http.Client _http;

  PolisherService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Future<PolishResult> polish({
    required String content,
    required EntryType entryType,
    required TagConfig tagConfig,
    required AIConfig config,
  }) async {
    if (!config.isUsable) {
      throw Exception('AI 润色未启用或配置不完整');
    }
    if (content.trim().isEmpty) {
      throw Exception('内容为空');
    }

    final systemPrompt = _buildSystemPrompt(
      entryType: entryType,
      tagConfig: tagConfig,
      customPrompt: config.polishPrompt,
    );

    final response = await _http.post(
      Uri.parse('${config.baseUrl}/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': config.model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': '原文：$content'},
        ],
        'max_tokens': 2000,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI 润色请求失败 (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('AI 未返回润色结果');
    }

    final message =
        (choices[0] as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    final rawContent = message?['content'] as String?;
    if (rawContent == null || rawContent.trim().isEmpty) {
      throw Exception('AI 润色结果为空');
    }

    return const PolishResultParser().parse(rawContent, tagConfig);
  }

  String _buildSystemPrompt({
    required EntryType entryType,
    required TagConfig tagConfig,
    String? customPrompt,
  }) {
    final defaultPrompt = _buildDefaultPolishPrompt(
      entryType: entryType,
      tagConfig: tagConfig,
    );

    final trimmed = customPrompt?.trim();
    if (trimmed == null || trimmed.isEmpty) return defaultPrompt;

    return '$defaultPrompt\n\n【用户补充要求】\n$trimmed';
  }

  String _buildDefaultPolishPrompt({
    required EntryType entryType,
    required TagConfig tagConfig,
  }) {
    final domainsSection = tagConfig.domains.map((d) {
      final topics =
          d.topics.map((t) => '  - ${t.name}').join('\n');
      return '- ${d.name}:\n$topics';
    }).join('\n');

    final methodsSection =
        tagConfig.methods.map((m) => '- ${m.name}').join('\n');

    final hint = switch (entryType) {
      EntryType.quickNote => '这是一条随手记录。',
      EntryType.reflection => '这是一条觉察与迭代记录。',
      EntryType.happiness => '这是一条小确幸记录。',
      EntryType.anxiety => '这是焦虑时刻的一个回答。',
    };

    return '''
你是一个日记润色助手。请将用户输入的内容进行润色。

$hint

【润色规则】
1. 使用自然、温和、清晰的中文润色用户原文。
2. 保留用户原意，不要改变事实。
3. 不要编造用户没有说过的内容。
4. 不要过度文学化，不要写成鸡汤。
5. 保持适合日记回看的表达。
6. 输出润色后的正文即可。

【固定标签规则】
7. 可以在末尾附上 2-3 个 hashtag。
8. hashtag 必须从以下可选标签中选择，不允许创造新标签。
9. 标签必须尽量符合：
   - 1 个领域 domain
   - 1 个主题 topic
   - 0-1 个方法 method

【可选领域及主题】
$domainsSection

【可选方法】
$methodsSection
''';
  }

  void dispose() {
    _http.close();
  }
}
