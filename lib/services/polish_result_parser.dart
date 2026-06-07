import '../models/polish_result.dart';
import '../models/tag_config.dart';

class PolishResultParser {
  const PolishResultParser();

  PolishResult parse(String rawText, TagConfig tagConfig) {
    final knownTags = _getAllKnownTags(tagConfig);

    final tagRegex = RegExp(r'#([\p{L}\p{N}_/-]+)', unicode: true);
    final rawTags = <String>[];

    final withoutTags = rawText.replaceAllMapped(tagRegex, (match) {
      final tag = match.group(1)!.trim();
      if (knownTags.contains(tag)) {
        rawTags.add(tag);
        return '';
      }
      return match.group(0)!;
    });

    final content = withoutTags
        .replaceAll(
            RegExp(r'^\s*(内容|润色后|润色结果)\s*[:：]\s*', multiLine: true),
            '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    final tags = _validateTags(rawTags, tagConfig);

    return PolishResult(content: content, tags: tags);
  }

  static Set<String> _getAllKnownTags(TagConfig config) {
    final names = <String>{};
    for (final domain in config.domains) {
      names.add(domain.name);
      for (final topic in domain.topics) {
        names.add(topic.name);
      }
    }
    for (final method in config.methods) {
      names.add(method.name);
    }
    return names;
  }

  static List<String> _validateTags(
      List<String> validTags, TagConfig config) {
    final domainNames = config.domains.map((d) => d.name).toSet();

    final domain = validTags.cast<String?>().firstWhere(
          (t) => domainNames.contains(t),
          orElse: () => null,
        );
    if (domain == null) return [];

    final domainTopics = config.domains
        .firstWhere((d) => d.name == domain)
        .topics
        .map((t) => t.name)
        .toSet();

    final topic = validTags.cast<String?>().firstWhere(
          (t) => domainTopics.contains(t),
          orElse: () => null,
        );
    if (topic == null) return [];

    final methodNames = config.methods.map((m) => m.name).toSet();
    final method = validTags.cast<String?>().firstWhere(
          (t) => methodNames.contains(t),
          orElse: () => null,
        );

    final result = [domain, topic];
    if (method != null) result.add(method);
    return result;
  }
}
