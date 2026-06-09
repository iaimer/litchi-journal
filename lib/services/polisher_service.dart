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
你是理性人生教练。基于当天日记，严格按以下格式输出，不要添加任何其他内容。

📌 模式识别
- 今天的行为模式或思维惯性

⚠️ 矛盾指出
- 指出言行不一致的地方

🎯 行动建议
- 明天可做的具体改进

💬 暖心鼓励
- 情绪价值，鼓励继续记录

严禁：
- 不要说"你好""好的""让我们来看看""以下是""希望"等开场或结尾语
- 不要改写模块标题：必须使用 📌 模式识别 ⚠️ 矛盾指出 🎯 行动建议 💬 暖心鼓励
- 不要用加粗**或方括号【】包裹标题
- 不要给标题加编号如1. 2. 3. 4.
- 不要用#号做标题
- 正文用 - 开头
- 总字数250-300字
- 只基于原文，不编造''';

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
    // Step 1: parse into module blocks
    final blocks = _parseModuleBlocks(raw);
    if (blocks.isEmpty) return [raw.trim(), ''];

    // Step 2: extract & normalize
    var lizhi = <String>[];
    var action = '';

    for (final block in blocks) {
      switch (block.type) {
        case _ModuleType.pattern:
          lizhi.add('📌 模式识别');
          lizhi.addAll(block.bodyLines);
          break;
        case _ModuleType.contradiction:
          lizhi.add('⚠️ 矛盾指出');
          lizhi.addAll(block.bodyLines);
          break;
        case _ModuleType.encouragement:
          lizhi.add('💬 暖心鼓励');
          lizhi.addAll(block.bodyLines);
          break;
        case _ModuleType.action:
          action = block.bodyLines.join('\n');
          break;
      }
    }

    final lizhiContent = lizhi.join('\n').trim();
    return [lizhiContent, action.trim()];
  }

  // -- module detection helpers --

  static final _patternAliases = [
    '模式识别', '主要模式', '主要模式与趋势',
  ];
  static final _contradictionAliases = [
    '矛盾指出', '矛盾', '可能的矛盾', '潜在矛盾', '不一致',
  ];
  static final _actionAliases = [
    '行动建议', '可操作的行动', '操作建议', '具体行动',
  ];
  static final _encouragementAliases = [
    '暖心鼓励', '温暖鼓励', '温暖结语',
  ];

  static bool _matchesAny(String text, List<String> aliases) {
    final cleaned = _cleanMarkdown(text);
    return aliases.any((a) => cleaned.contains(a));
  }

  static String _cleanMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*{1,3}'), '')
        .replaceAll(RegExp(r'#{1,3}\s*'), '')
        .replaceAll('【', '')
        .replaceAll('】', '')
        .replaceAll(RegExp(r'^\d+\.\s*'), '')
        .replaceAll(RegExp(r'^[-•]\s*'), '')
        .replaceAll(RegExp(r'[：:]$'), '')
        .trim();
  }

  static String _cleanBodyLine(String line) {
    var t = line.trim();
    if (t.isEmpty) return '';
    // remove markdown formatting
    t = t.replaceAll('**', '');
    t = t.replaceAll('__', '');
    // strip leading bullet characters and whitespace
    t = t.replaceAll(RegExp(r'^[-\u2022\s]+'), '');
    if (t.isEmpty) return '';
    return '- $t';
  }

  static List<_ModuleBlock> _parseModuleBlocks(String raw) {
    final lines = raw.split('\n');
    final blocks = <_ModuleBlock>[];
    _ModuleBlock? current;
    var reachedFirstModule = false;

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;

      final type = _detectModuleType(t);
      if (type != null) {
        reachedFirstModule = true;
        if (current != null && current.bodyLines.isNotEmpty) {
          blocks.add(current);
        }
        current = _ModuleBlock(type);
        continue;
      }

      if (!reachedFirstModule) continue; // skip preamble

      final cleaned = _cleanBodyLine(t);
      if (cleaned.isNotEmpty) {
        current?.bodyLines.add(cleaned);
      }
    }

    if (current != null && current.bodyLines.isNotEmpty) {
      blocks.add(current);
    }

    return blocks;
  }

  static _ModuleType? _detectModuleType(String line) {
    final c = _cleanMarkdown(line);
    if (c.isEmpty) return null;

    if (_matchesAny(c, _actionAliases)) return _ModuleType.action;
    if (_matchesAny(c, _encouragementAliases)) return _ModuleType.encouragement;
    if (_matchesAny(c, _contradictionAliases)) return _ModuleType.contradiction;
    if (_matchesAny(c, _patternAliases)) return _ModuleType.pattern;

    return null;
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

enum _ModuleType { pattern, contradiction, action, encouragement }

class _ModuleBlock {
  final _ModuleType type;
  final bodyLines = <String>[];
  _ModuleBlock(this.type);
}
