import '../models/polish_result.dart';
import '../models/tag_config.dart';
import '../models/tag_settings.dart';

class PolishResultParser {
  const PolishResultParser();

  PolishResult parse(String rawText, TagConfig tagConfig,
      {TagSettings? tagSettings}) {
    final knownTags = _getAllKnownTags(tagConfig, tagSettings: tagSettings);
    // disabledTags = 已隐藏标签，需要从正文中清除但不提取为 tag
    final disabledTags = tagSettings != null
        ? _getDisabledTagNames(tagSettings)
        : <String>{};

    final tagRegex = RegExp(r'#([\p{L}\p{N}_/-]+)', unicode: true);
    final rawTags = <String>[];

    final withoutTags = rawText.replaceAllMapped(tagRegex, (match) {
      final tag = match.group(1)!.trim();
      if (knownTags.contains(tag)) {
        rawTags.add(tag);
        return '';
      }
      // 隐藏标签也从正文中清除，不显示 #育儿 等原文
      if (disabledTags.contains(tag)) {
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

    final tags = _validateTags(rawTags, tagConfig, tagSettings: tagSettings);

    return PolishResult(content: content, tags: tags);
  }

  /// 构建已隐藏标签名称集合（含 displayName + defaultName）。
  static Set<String> _getDisabledTagNames(TagSettings tagSettings) {
    final names = <String>{};
    for (final ds in tagSettings.domainSettings) {
      if (!ds.enabled) {
        names.add(ds.displayName);
        if (ds.displayName != ds.defaultName) {
          names.add(ds.defaultName);
        }
        for (final ts in ds.topics) {
          names.add(ts.displayName);
          if (ts.displayName != ts.defaultName) {
            names.add(ts.defaultName);
          }
        }
      } else {
        for (final ts in ds.topics) {
          if (!ts.enabled) {
            names.add(ts.displayName);
            if (ts.displayName != ts.defaultName) {
              names.add(ts.defaultName);
            }
          }
        }
      }
    }
    for (final ms in tagSettings.methodSettings) {
      if (!ms.enabled) {
        names.add(ms.displayName);
        if (ms.displayName != ms.defaultName) {
          names.add(ms.defaultName);
        }
      }
    }
    return names;
  }

  static Set<String> _getAllKnownTags(TagConfig config,
      {TagSettings? tagSettings}) {
    if (tagSettings != null) {
      // 使用 TagSettings：只包含 enabled 标签的 displayName + defaultName
      final names = <String>{};
      for (final ds in tagSettings.domainSettings) {
        if (!ds.enabled) continue;
        names.add(ds.displayName);
        if (ds.displayName != ds.defaultName) {
          names.add(ds.defaultName);
        }
        for (final ts in ds.topics) {
          if (!ts.enabled) continue;
          names.add(ts.displayName);
          if (ts.displayName != ts.defaultName) {
            names.add(ts.defaultName);
          }
        }
      }
      for (final ms in tagSettings.methodSettings) {
        if (!ms.enabled) continue;
        names.add(ms.displayName);
        if (ms.displayName != ms.defaultName) {
          names.add(ms.defaultName);
        }
      }
      return names;
    }

    // 无 TagSettings：使用 TagConfig 的全部 name（兼容旧行为）
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

  static List<String> _validateTags(List<String> validTags, TagConfig config,
      {TagSettings? tagSettings}) {
    // 构建有效名称集合（enabled 且匹配一条就算）
    Set<String> enabledNames;
    Map<String, String> nameToDisplayName;

    if (tagSettings != null) {
      enabledNames = {};
      nameToDisplayName = {};

      for (final ds in tagSettings.domainSettings) {
        if (!ds.enabled) continue;
        enabledNames.add(ds.displayName);
        nameToDisplayName[ds.displayName] = ds.displayName;
        if (ds.displayName != ds.defaultName) {
          enabledNames.add(ds.defaultName);
          nameToDisplayName[ds.defaultName] = ds.displayName;
        }
        for (final ts in ds.topics) {
          if (!ts.enabled) continue;
          enabledNames.add(ts.displayName);
          nameToDisplayName[ts.displayName] = ts.displayName;
          if (ts.displayName != ts.defaultName) {
            enabledNames.add(ts.defaultName);
            nameToDisplayName[ts.defaultName] = ts.displayName;
          }
        }
      }
      for (final ms in tagSettings.methodSettings) {
        if (!ms.enabled) continue;
        enabledNames.add(ms.displayName);
        nameToDisplayName[ms.displayName] = ms.displayName;
        if (ms.displayName != ms.defaultName) {
          enabledNames.add(ms.defaultName);
          nameToDisplayName[ms.defaultName] = ms.displayName;
        }
      }
    } else {
      // 无 TagSettings：所有名称都有效
      enabledNames = <String>{};
      nameToDisplayName = {};
      for (final domain in config.domains) {
        enabledNames.add(domain.name);
        nameToDisplayName[domain.name] = domain.name;
        for (final topic in domain.topics) {
          enabledNames.add(topic.name);
          nameToDisplayName[topic.name] = topic.name;
        }
      }
      for (final method in config.methods) {
        enabledNames.add(method.name);
        nameToDisplayName[method.name] = method.name;
      }
    }

    // 只保留已启用的标签
    final enabledTags = validTags.where((t) {
      final clean = t.startsWith('#') ? t.substring(1) : t;
      return enabledNames.contains(clean);
    }).toList();

    final domainNames = config.domains.map((d) => d.name).toSet();
    // 在 TagSettings 模式下，domain 可能改了 displayName，也需要匹配
    if (tagSettings != null) {
      for (final ds in tagSettings.domainSettings) {
        if (ds.enabled) domainNames.add(ds.displayName);
      }
    }

    final domain = enabledTags.cast<String?>().firstWhere(
          (t) => domainNames.contains(t),
          orElse: () => null,
        );
    if (domain == null) return [];

    // 用 displayName 查找 domain 的主题
    TagDomain? matchedDomain;
    for (final d in config.domains) {
      if (d.name == domain) {
        matchedDomain = d;
        break;
      }
    }
    // 如果 domain 被重命名了，用原始 id 查找
    if (matchedDomain == null && tagSettings != null) {
      for (final ds in tagSettings.domainSettings) {
        if (ds.displayName == domain) {
          matchedDomain = config.domains.where((d) => d.id == ds.key).firstOrNull;
          break;
        }
      }
    }
    if (matchedDomain == null) return [];

    final domainTopics = matchedDomain.topics.map((t) => t.name).toSet();
    // 加上 TopicSetting 的 displayName
    if (tagSettings != null) {
      for (final ds in tagSettings.domainSettings) {
        if (ds.key == matchedDomain.id) {
          for (final ts in ds.topics) {
            if (ts.enabled) domainTopics.add(ts.displayName);
          }
          break;
        }
      }
    }

    final topic = enabledTags.cast<String?>().firstWhere(
          (t) => domainTopics.contains(t),
          orElse: () => null,
        );
    if (topic == null) return [];

    final methodNames = config.methods.map((m) => m.name).toSet();
    if (tagSettings != null) {
      for (final ms in tagSettings.methodSettings) {
        if (ms.enabled) methodNames.add(ms.displayName);
      }
    }
    final method = enabledTags.cast<String?>().firstWhere(
          (t) => methodNames.contains(t),
          orElse: () => null,
        );

    // 输出 displayName
    final result = [
      nameToDisplayName[domain] ?? domain,
      nameToDisplayName[topic] ?? topic,
    ];
    if (method != null) {
      result.add(nameToDisplayName[method] ?? method);
    }
    return result;
  }
}
