import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'flora_icon.dart';

/// 标题与添加菜单共用的模块视觉身份；不依赖显示标题。
class DiaryModuleVisual {
  final String icon;
  final Color color;

  const DiaryModuleVisual(this.icon, this.color);

  static const _modules = {
    'quickNote': DiaryModuleVisual(FloraIcons.fabWrite, TodayRainbow.quickNote),
    'review': DiaryModuleVisual(FloraIcons.fabInsight, TodayRainbow.review),
    'happiness': DiaryModuleVisual(FloraIcons.fabHappy, TodayRainbow.happiness),
    'coach': DiaryModuleVisual(FloraIcons.sectionCoach, TodayRainbow.coach),
    'tomorrow': DiaryModuleVisual(
      FloraIcons.sectionTomorrow,
      TodayRainbow.tomorrow,
    ),
    'media': DiaryModuleVisual(FloraIcons.history, TodayRainbow.media),
  };

  static DiaryModuleVisual? forType(String type) => _modules[type];
}
