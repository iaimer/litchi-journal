import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_config.dart';
import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';
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
    TagSettings? tagSettings,
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

    // First attempt
    var rawContent =
        await _callAI(config: config, systemPrompt: systemPrompt, userContent: content);
    var result = const PolishResultParser().parse(rawContent, tagConfig, tagSettings: tagSettings);

    if (result.tags.isNotEmpty) return result;

    // Retry with stronger tag instruction
    final retryPrompt = '$systemPrompt\n\n$_retryInstruction';
    rawContent =
        await _callAI(config: config, systemPrompt: retryPrompt, userContent: content);
    result = const PolishResultParser().parse(rawContent, tagConfig, tagSettings: tagSettings);

    return result;
  }

  Future<String> _callAI({
    required AIConfig config,
    required String systemPrompt,
    required String userContent,
    int maxTokens = 2000,
    String userPrefix = '原文：',
  }) async {
    final chatUrl = PolisherService.chatUrl(config.baseUrl);
    final response = await _http.post(
      Uri.parse(chatUrl),
      headers: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': config.model.isNotEmpty ? config.model : config.resolvedModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': '$userPrefix$userContent'},
        ],
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI 请求失败 (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('AI 未返回结果');
    }

    final message =
        (choices[0] as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    final rawContent = message?['content'] as String?;
    if (rawContent == null || rawContent.trim().isEmpty) {
      throw Exception('AI 结果为空');
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

    return _callAI(
      config: config,
      systemPrompt: effectivePrompt,
      userContent: content,
      maxTokens: 500,
    );
  }

  Future<String> generateCoach({
    required String diaryContext,
    required AIConfig config,
  }) async {
    if (!config.isUsable) {
      throw Exception('AI 教练未启用或配置不完整');
    }

    final trimmed = config.coachPrompt?.trim();
    final effectivePrompt = (trimmed != null &&
            trimmed.isNotEmpty &&
            !trimmed.contains('第一人称'))
        ? trimmed
        : defaultCoachPrompt;

    return _callAI(
      config: config,
      systemPrompt: effectivePrompt,
      userContent: diaryContext,
      maxTokens: 800,
      userPrefix: '今天日记内容：\n',
    );
  }

  static CoachGenerationParts splitCoachResultLikeWeb(String raw) {
    final actionMatch = RegExp(
      r'(?:###\s+)?\*{0,2}\s*🎯\s*\*{0,2}\s*行动建议\s*\*{0,2}\s*\n?([\s\S]*?)(?=(?:###\s+)?\*{0,2}\s*💬\s*\*{0,2}\s*暖心鼓励\s*\*{0,2}|$)',
    ).firstMatch(raw);

    final actionContent = _cleanActionForReplace(
      actionMatch?.group(1)?.trim() ?? '',
    );
    final lizhiContent = _cleanCoachForReplace(actionMatch != null
        ? raw
            .replaceAll(actionMatch.group(0)!, '')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim()
        : raw.trim());

    return CoachGenerationParts(
      lizhiContent: lizhiContent,
      actionContent: actionContent,
    );
  }

  static String _cleanActionForReplace(String text) {
    return text
        .split('\n')
        .map(_stripGeneratedListMarker)
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();
  }

  static String _cleanCoachForReplace(String text) {
    final output = <String>[];
    var paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      output.add(paragraph.join(' '));
      paragraph = [];
    }

    for (final rawLine in text.split('\n')) {
      final raw = rawLine.trim();
      if (raw.isEmpty) {
        flushParagraph();
        continue;
      }

      // Try to detect and extract a module title from this line
      final extracted = _extractModuleTitle(raw);
      if (extracted != null) {
        flushParagraph();
        output.add(extracted.title);
        if (extracted.body != null) {
          paragraph.add(extracted.body!);
        }
      } else {
        final body = _cleanBodyText(raw);
        if (body.isNotEmpty) paragraph.add(body);
      }
    }
    flushParagraph();

    return output.join('\n').trim();
  }

  /// Returns (normalizedTitle, remainingBody) if the line contains a module title.
  /// If the line is just a title, body is null.
  /// If the line starts with a module emoji but no recognized keyword, returns null.
  static ({String title, String? body})? _extractModuleTitle(String raw) {
    // Strip markdown artifacts for matching
    var cleaned = raw
        .replaceAll('**', '')
        .replaceAll(RegExp(r'#{1,3}\s*'), '')
        .replaceAll('【', '')
        .replaceAll('】', '')
        .trim();

    if (cleaned.isEmpty) return null;

    // Check which module this is and get the normalized title
    final normTitle = _normalizeTitle(cleaned);
    if (normTitle == null) return null;

    // Find the actual title text position in the original line.
    // The original line might be: "📌 **模式识别** 今天你展现了……"
    // or: "📌 模式识别：今天你展现了……"

    // Find where the title part ends in the ORIGINAL string.
    // Strategy: find the normalized title text position, and body starts after it.
    final normText = _titleTextFor(normTitle); // e.g., "模式识别"
    final rawNoMD = raw
        .replaceAll('**', '')
        .replaceAll(RegExp(r'#{1,3}\s*'), '')
        .replaceAll('【', '')
        .replaceAll('】', '')
        .replaceAll(RegExp(r'^\d+\.\s*'), '')
        .trim();

    final idx = rawNoMD.indexOf(normText);
    if (idx == -1) return (title: normTitle, body: null);

    final afterTitle = rawNoMD.substring(idx + normText.length)
        .replaceFirst(RegExp(r'^[：:\s]+'), '')
        .trim();

    if (afterTitle.isEmpty) return (title: normTitle, body: null);

    final body = _cleanBodyText(afterTitle);
    return (title: normTitle, body: body.isEmpty ? null : body);
  }

  static String? _normalizeTitle(String cleaned) {
    if (_matchesModuleTitle(cleaned, const ['模式识别', '主要模式', '主要模式与趋势'])) {
      return '📌 模式识别';
    }
    if (_matchesModuleTitle(cleaned, const ['矛盾指出', '潜在矛盾', '可能的矛盾'])) {
      return '⚠️ 矛盾指出';
    }
    if (_matchesModuleTitle(cleaned, const [
      '暖心鼓励',
      '温暖鼓励',
      '温暖结语',
      '最后，想对你说',
      '最后想对你说',
    ])) {
      return '💬 暖心鼓励';
    }
    return null;
  }

  static bool _matchesModuleTitle(String text, List<String> aliases) {
    final normalized = _stripLeadingModulePrefix(text);
    for (final alias in aliases) {
      if (normalized == alias) return true;
      if (normalized.startsWith(alias) &&
          _hasTitleBoundary(normalized, alias.length)) {
        return true;
      }
    }
    return false;
  }

  static String _stripLeadingModulePrefix(String text) {
    var result = text
        .replaceFirst(RegExp(r'^(?:[-•·.\s]+|\d+\.\s*)+'), '')
        .trim();
    for (final emoji in ['📌', '⚠️', '⚠', '🎯', '💬']) {
      if (result.startsWith(emoji)) {
        result = result.substring(emoji.length).trim();
        break;
      }
    }
    return result;
  }

  static bool _hasTitleBoundary(String text, int index) {
    if (index >= text.length) return true;
    final next = text[index];
    return next.trim().isEmpty ||
        next == ':' ||
        next == '：' ||
        next == '与' ||
        next == '和';
  }

  static String _titleTextFor(String normTitle) {
    switch (normTitle) {
      case '📌 模式识别': return '模式识别';
      case '⚠️ 矛盾指出': return '矛盾指出';
      case '💬 暖心鼓励': return '暖心鼓励';
      default: return normTitle;
    }
  }

  static String _cleanBodyText(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^[-•·.\s]+'), '')
        .trim();
  }

  static String _stripGeneratedListMarker(String line) {
    return line.trim().replaceFirst(RegExp(r'^(?:[-•·.\s])+'), '').trim();
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

class CoachGenerationParts {
  final String lizhiContent;
  final String actionContent;

  const CoachGenerationParts({
    required this.lizhiContent,
    required this.actionContent,
  });
}
