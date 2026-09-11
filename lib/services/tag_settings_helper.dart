import '../models/tag_config.dart';
import '../models/tag_settings.dart';

/// 标签设置辅助函数。
class TagSettingsHelper {
  TagSettingsHelper._();

  /// 生成当前设备可用的 TagConfig，name 替换为 displayName。
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
      if (!ds.enabled || ds.deleted) {
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
          if (!ts.enabled || ts.deleted) {
            disabledNames.add(ts.displayName);
            if (ts.displayName != ts.defaultName) {
              disabledNames.add(ts.defaultName);
            }
          }
        }
      }
    }
    for (final ms in settings.methodSettings) {
      if (!ms.enabled || ms.deleted) {
        disabledNames.add(ms.displayName);
        if (ms.displayName != ms.defaultName) {
          disabledNames.add(ms.defaultName);
        }
      }
    }

    // 用户重新创建同名标签后，以当前可用标签为准，不把它误判为历史隐藏标签。
    final activeNames = <String>{};
    for (final ds in settings.domainSettings) {
      if (ds.enabled && !ds.deleted) {
        activeNames.add(ds.displayName);
        activeNames.add(ds.defaultName);
        for (final ts in ds.topics) {
          if (ts.enabled && !ts.deleted) {
            activeNames.add(ts.displayName);
            activeNames.add(ts.defaultName);
          }
        }
      }
    }
    for (final ms in settings.methodSettings) {
      if (ms.enabled && !ms.deleted) {
        activeNames.add(ms.displayName);
        activeNames.add(ms.defaultName);
      }
    }
    disabledNames.removeWhere(activeNames.contains);

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

  /// 校验名称是否与当前其它可用标签重复。
  static String? validateUniqueDisplayName(
    String name,
    Iterable<String> existingNames,
  ) {
    final normalized = name.trim();
    if (existingNames.contains(normalized)) return '标签名已存在';
    return null;
  }

  /// 计算当前设备中启用且未删除的 domain、topic、method 总数。
  static int countEnabled(TagSettings settings) {
    int count = 0;
    for (final ds in settings.domainSettings) {
      if (ds.enabled && !ds.deleted) {
        count++; // count the domain
        for (final ts in ds.topics) {
          if (ts.enabled && !ts.deleted) count++;
        }
      }
    }
    for (final ms in settings.methodSettings) {
      if (ms.enabled && !ms.deleted) count++;
    }
    return count;
  }
}
