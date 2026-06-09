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
你是一个理性的人生教练。基于当天日记内容，输出 250-300 字的分析。用第三人称"你"视角。

按以下结构输出，模块间空行分隔：

📌 模式识别
今天的行为模式或思维惯性

⚠️ 矛盾指出
温和指出言行不一致的地方

🎯 行动建议
明天可做的具体小改进

💬 暖心鼓励
注入一点情绪价值，给继续记录、持续改进的勇气

铁律：
- 总字数严格 250-300 字，不超出、不偷懒
- 只基于原文，不编造
- 教练口吻，客观直接，不说教''';

  static const _retryInstruction = '''
【重要提醒】
你上一次没有输出合法标签。这次必须严格要求：

1. 在最后一行输出标签，格式为：#领域 #主题 [#可选方法]
2. 必须输出 1 个领域 + 1 个主题
3. 可选 1 个方法
4. 标签必须来自上面列出的可选标签，不允许创造新标签
5. 不要输出解释，只输出正文和标签
6. 方法名（如 #反思）不能替代领域或主题，必须同时输出领域+主题

输出示例：
润色后的正文内容
#亲子 #亲子沟通 #反思''';

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
    final headers = {
      'Authorization': 'Bearer ${config.apiKey}',
      'Content-Type': 'application/json',
    };

    // First attempt
    var rawContent =
        await _callAI(chatUrl, headers, config.model, systemPrompt, content);
    var result = const PolishResultParser().parse(rawContent, tagConfig);

    if (result.tags.isNotEmpty) return result;

    // Retry with stronger tag instruction
    final retryPrompt = '$systemPrompt\n\n$_retryInstruction';
    rawContent =
        await _callAI(chatUrl, headers, config.model, retryPrompt, content);
    result = const PolishResultParser().parse(rawContent, tagConfig);

    return result;
  }

  Future<String> _callAI(
    String chatUrl,
    Map<String, String> headers,
    String model,
    String systemPrompt,
    String userContent,
  ) async {
    final response = await _http.post(
      Uri.parse(chatUrl),
      headers: headers,
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': '原文：$userContent'},
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

    return rawContent.trim();
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
        (trimmed != null && trimmed.isNotEmpty) ? trimmed : defaultPolishPrompt;

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

  Future<String> generateCoach({
    required String diaryContext,
    required AIConfig config,
  }) async {
    if (!config.isUsable) {
      throw Exception('AI 教练未启用或配置不完整');
    }

    final trimmed = config.coachPrompt?.trim();
    final effectivePrompt =
        (trimmed != null && trimmed.isNotEmpty) ? trimmed : defaultCoachPrompt;

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
          {
            'role': 'user',
            'content': '今天日记内容：\n$diaryContext',
          },
        ],
        'max_tokens': 800,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI 教练生成失败 (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('AI 未返回教练结果');
    }

    final message =
        (choices[0] as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    final rawContent = message?['content'] as String?;
    if (rawContent == null || rawContent.trim().isEmpty) {
      throw Exception('AI 教练结果为空');
    }

    return rawContent.trim();
  }

  static List<String> parseCoachResult(String raw) {
    // Extract 🎯 行动建议 module — same regex as Web
    final actionMatch = RegExp(
      r'(?:###\s+)?\*{0,2}\s*🎯\s*\*{0,2}\s*行动建议\s*\*{0,2}\s*\n?([\s\S]*?)(?=(?:###\s+)?\*{0,2}\s*💬\s*\*{0,2}\s*暖心鼓励\s*\*{0,2}|$)',
      multiLine: true,
    ).firstMatch(raw);

    final actionContent =
        actionMatch?.group(1)?.trim() ?? '';

    // Remove action module + clean up whitespace
    final lizhiContent = actionMatch != null
        ? raw.replaceAll(actionMatch.group(0)!, '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim()
        : raw.trim();

    return [lizhiContent, actionContent];
  }

  String _buildSystemPrompt({
    required EntryType entryType,
    required TagConfig tagConfig,
    String? customPrompt,
  }) {
    final trimmed = customPrompt?.trim();
    final effectivePrompt =
        (trimmed != null && trimmed.isNotEmpty) ? trimmed : defaultPolishPrompt;

    final hint = switch (entryType) {
      EntryType.quickNote => '这是一条随手记录。',
      EntryType.reflection => '这是一条觉察与迭代记录。判断这条觉察属于哪个生活领域（亲子/育儿/工作/学习/阅读/技术/生活），从该领域中选择适合的主题。',
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
