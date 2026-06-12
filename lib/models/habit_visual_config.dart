import 'dart:ui';

import 'habit_stats.dart';

/// 习惯视觉配置：display name、icon、主题色、分组。
/// 后续可从习惯设置中自定义，当前为固定映射。
class HabitVisualConfig {
  final String key;
  final String displayName;
  final String icon;
  final Color color;
  final HabitGroup group;

  const HabitVisualConfig({
    required this.key,
    required this.displayName,
    required this.icon,
    required this.color,
    required this.group,
  });

  static const Map<String, HabitVisualConfig> defaults = {
    'water': HabitVisualConfig(
      key: 'water',
      displayName: '饮水',
      icon: '💧',
      color: Color(0xFF6BAED6),
      group: HabitGroup.body,
    ),
    'steps': HabitVisualConfig(
      key: 'steps',
      displayName: '运动',
      icon: '🚶',
      color: Color(0xFFE8A87C),
      group: HabitGroup.body,
    ),
    'reading': HabitVisualConfig(
      key: 'reading',
      displayName: '亲子共读',
      icon: '📖',
      color: Color(0xFF6B8E6B),
      group: HabitGroup.growth,
    ),
    'language': HabitVisualConfig(
      key: 'language',
      displayName: '学语言',
      icon: '🗣️',
      color: Color(0xFF9B8EC4),
      group: HabitGroup.growth,
    ),
    'supplements': HabitVisualConfig(
      key: 'supplements',
      displayName: '补充剂',
      icon: '💊',
      color: Color(0xFFC49B8C),
      group: HabitGroup.body,
    ),
  };

  /// 根据 key 获取视觉配置，未知 key 返回 fallback。
  static HabitVisualConfig of(String key) {
    return defaults[key] ??
        HabitVisualConfig(
          key: key,
          displayName: key,
          icon: '✅',
          color: const Color(0xFF8A8278),
          group: HabitGroup.body,
        );
  }
}
