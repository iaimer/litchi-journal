import '../models/tag_config.dart';
import '../models/tag_settings.dart';

/// 标签设置辅助函数。
class TagSettingsHelper {
  TagSettingsHelper._();

  /// 生成只含 enabled 标签的 TagConfig，name 替换为 displayName。
  static TagConfig effectiveTagConfig(TagConfig source, TagSettings settings) {
    return settings.toEffectiveTagConfig(source);
  }

  /// 找出 initialTags 中已被隐藏的标签名称列表。
  /// 同时匹配 displayName 和 defaultName。
  static List<String> hiddenInitialTags(
    List<String> initialTags,
    TagSettings settings,
  ) {
    if (initialTags.isEmpty) return [];

    final disabledNames = <String>{};
    for (final ds in settings.domainSettings) {
      if (!ds.enabled) {
        disabledNames.add(ds.displayName);
        if (ds.displayName != ds.defaultName) {
          disabledNames.add(ds.defaultName);
        }
        // 域名下的所有 topic 也视为隐藏
        for (final ts in ds.topics) {
          disabledNames.add(ts.displayName);
          if (ts.displayName != ts.defaultName) {
            disabledNames.add(ts.defaultName);
          }
        }
      } else {
        for (final ts in ds.topics) {
          if (!ts.enabled) {
            disabledNames.add(ts.displayName);
            if (ts.displayName != ts.defaultName) {
              disabledNames.add(ts.defaultName);
            }
          }
        }
      }
    }
    for (final ms in settings.methodSettings) {
      if (!ms.enabled) {
        disabledNames.add(ms.displayName);
        if (ms.displayName != ms.defaultName) {
          disabledNames.add(ms.defaultName);
        }
      }
    }

    return initialTags.where((t) => disabledNames.contains(t)).toList();
  }

  /// 校验 displayName 是否合法。
  /// 不能为空，不能包含 #、空格、换行、制表符。
  static String? validateDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '标签名不能为空';
    if (trimmed.contains('#')) return '标签名不能包含 # 符号';
    if (trimmed.contains(' ')) return '标签名不能包含空格';
    if (trimmed.contains('\n') || trimmed.contains('\r')) {
      return '标签名不能包含换行符';
    }
    if (trimmed.contains('\t')) return '标签名不能包含制表符';
    return null;
  }

  /// 计算已启用标签总数（所有 enabled 的 domain + topic + method）。
  static int countEnabled(TagSettings settings) {
    int count = 0;
    for (final ds in settings.domainSettings) {
      if (ds.enabled) {
        count++; // count the domain
        for (final ts in ds.topics) {
          if (ts.enabled) count++;
        }
      }
    }
    for (final ms in settings.methodSettings) {
      if (ms.enabled) count++;
    }
    return count;
  }
}
