import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_config.dart';
import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../widgets/entry_type.dart';
import 'polish_result_parser.dart';

class PolisherService {
  static const defaultPolishPrompt = '''
你是一个日记润色助手。请将用户输入的内容进行润色。

【润色规则】
1. 使用自然、温和、清晰的中文润色用户原文。
2. 保留用户原意，不要改变事实。
3. 不要编造用户没有说过的内容。
4. 不要过度文学化，不要写成鸡汤。
5. 保持适合日记回看的表达。
6. 输出润色后的正文即可。''';

  static const defaultCoachPrompt = '''
你是一个人生教练，将根据用户今天的日记记录，给予结构化的指导。

【教练规则】
1. 识别用户今天的主要模式或趋势
2. 指出可能的矛盾或不一致之处
3. 给出一条可操作的行动建议
4. 以温暖鼓励的语气结束
5. 使用第二人称"你"
6. 控制在250-300字''';

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

    final chatUrl = PolisherService.chatUrl(config.baseUrl);

    final response = await _http.post(
      Uri.parse(chatUrl),
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
    final trimmed = customPrompt?.trim();
    final effectivePrompt =
        (trimmed != null && trimmed.isNotEmpty)
            ? trimmed
            : defaultPolishPrompt;

    final hint = switch (entryType) {
      EntryType.quickNote => '这是一条随手记录。',
      EntryType.reflection => '这是一条觉察与迭代记录。',
      EntryType.happiness => '这是一条小确幸记录。',
      EntryType.anxiety => '这是焦虑时刻的一个回答。',
    };

    final tagSection = _buildTagSection(tagConfig);

    return '$effectivePrompt\n\n$hint\n\n$tagSection';
  }

  static String _buildTagSection(TagConfig tagConfig) {
    final domainsSection = tagConfig.domains.map((d) {
      final topics =
          d.topics.map((t) => '  - ${t.name}').join('\n');
      return '- ${d.name}:\n$topics';
    }).join('\n');

    final methodsSection =
        tagConfig.methods.map((m) => '- ${m.name}').join('\n');

    return '''
【固定标签规则】
1. 必须在末尾附上 2-3 个 hashtag，格式为 #领域 #主题 [#可选方法]。
2. hashtag 必须从以下可选标签中选择，不允许创造新标签。
3. 标签必须尽量符合：
   - 1 个领域 domain
   - 1 个主题 topic
   - 0-1 个方法 method
4. 标签放在正文之后，独占一行，不要混在正文中。

【可选领域及主题】
$domainsSection

【可选方法】
$methodsSection

【输出格式】
正文内容
#领域 #主题 [#可选方法]''';
  }

  Future<String> polishPlainText({
    required String content,
    required AIConfig config,
  }) async {
    if (!config.isUsable) {
      throw Exception('AI 润色未启用或配置不完整');
    }
    if (content.trim().isEmpty) {
      throw Exception('内容为空');
    }

    final trimmed = config.polishPrompt?.trim();
    final effectivePrompt =
        (trimmed != null && trimmed.isNotEmpty)
            ? trimmed
            : defaultPolishPrompt;

    final chatUrl = PolisherService.chatUrl(config.baseUrl);

    final response = await _http.post(
      Uri.parse(chatUrl),
      headers: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': config.model,
        'messages': [
          {'role': 'system', 'content': effectivePrompt},
          {'role': 'user', 'content': '原文：$content'},
        ],
        'max_tokens': 500,
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

    return rawContent.trim();
  }

  static String chatUrl(String baseUrl) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/v1')) {
      return '$url/chat/completions';
    }
    return '$url/v1/chat/completions';
  }

  void dispose() {
    _http.close();
  }
}
