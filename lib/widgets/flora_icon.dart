import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 稳定的界面图标逻辑名称，习惯设置中已保存的名称不得随资源迁移改写。
class FloraIcons {
  FloraIcons._();

  static const String diary = 'diary';
  static const String history = 'history';
  static const String habits = 'habits';
  static const String settings = 'settings';
  static const String coach = 'coach';

  static const String fabWrite = 'fab-write';
  static const String fabInsight = 'fab-insight';
  static const String fabHappy = 'fab-happy';
  static const String fabAnxiety = 'fab-anxiety';
  static const String fabPhoto = 'fab-photo';

  static const String settingAppearance = 'setting-appearance';
  static const String settingHabits = 'setting-habits';
  static const String settingTags = 'setting-tags';
  static const String settingCloud = 'setting-cloud';
  static const String settingAi = 'setting-ai';
  static const String settingPrompt = 'setting-prompt';
  static const String settingImage = 'setting-image';
  static const String settingAbout = 'setting-about';

  static const String edit = 'edit';
  static const String delete = 'delete';
  static const String restore = 'restore';
  static const String reset = 'reset';
  static const String more = 'more';
  static const String shuffle = 'shuffle';

  static const String back = 'back';
  static const String close = 'close';
  static const String add = 'add';
  static const String arrowRight = 'arrow-right';
  static const String chevronLeft = 'chevron-left';
  static const String chevronRight = 'chevron-right';
  static const String chevronUp = 'chevron-up';
  static const String chevronDown = 'chevron-down';
  static const String refresh = 'refresh';
  static const String eye = 'eye';
  static const String eyeOff = 'eye-off';
  static const String play = 'play';
  static const String pause = 'pause';
  static const String timer = 'timer';
  static const String clock = 'clock';
  static const String calendar = 'calendar';
  static const String historyAction = 'history-action';
  static const String radioSelected = 'radio-selected';
  static const String radioUnselected = 'radio-unselected';
  static const String checkboxChecked = 'checkbox-checked';
  static const String checkboxUnchecked = 'checkbox-unchecked';
  static const String imagePlaceholder = 'image-placeholder';
  static const String imageOff = 'image-off';
  static const String wifi = 'wifi';
  static const String error = 'error';
  static const String success = 'success';
  static const String check = 'check';
  static const String circleHelp = 'circle-help';

  static const String calloutQuote = 'callout-quote';
  static const String calloutTip = 'callout-tip';
  static const String calloutInfo = 'callout-info';
  static const String calloutWarning = 'callout-warning';
  static const String calloutError = 'callout-error';
  static const String calloutSuccess = 'callout-success';
  static const String calloutCode = 'callout-code';

  static const String deviceSystem = 'device-system';
  static const String theme = 'theme';

  static const String habitWater = 'habit-water';
  static const String habitWalk = 'habit-walk';
  static const String habitRead = 'habit-read';
  static const String habitLanguage = 'habit-language';
  static const String habitPill = 'habit-pill';

  static const String candidateRun = 'candidate-run';
  static const String candidateSprout = 'candidate-sprout';
  static const String candidateStar = 'candidate-star';
  static const String candidateSun = 'candidate-sun';
  static const String candidateMoon = 'candidate-moon';
  static const String candidateMeditate = 'candidate-meditate';
  static const String candidateLift = 'candidate-lift';
  static const String candidateApple = 'candidate-apple';
  static const String candidateBooks = 'candidate-books';

  static const String pin = 'pin';
  static const String warning = 'warning';
  static const String chatFeedback = 'chat-feedback';
  static const String question = 'question';
  static const String reward = 'reward';
  static const String target = 'target';

  static const String brandIcon = 'brand-icon';
  static const String brandSplash = 'brand-splash';
  static const String brandSplashDark = 'brand-splash-dark';
  static const String emptyPast = 'empty-past';
  static const String emptyTags = 'empty-tags';
  static const String emptyHabits = 'empty-habits';
  static const String emptySearch = 'empty-search';
  static const String successCheck = 'success-check';

  static const Map<String, String> _lucideFiles = {
    diary: 'notebook-pen',
    history: 'images',
    habits: 'sprout',
    settings: 'settings',
    coach: 'sparkles',
    fabWrite: 'pen-line',
    fabInsight: 'eye',
    fabHappy: 'sparkles',
    fabAnxiety: 'cloud-rain',
    fabPhoto: 'image-plus',
    settingAppearance: 'palette',
    settingHabits: 'list-checks',
    settingTags: 'tags',
    settingCloud: 'server-cog',
    settingAi: 'bot',
    settingPrompt: 'message-square-text',
    settingImage: 'image',
    settingAbout: 'info',
    edit: 'pencil',
    delete: 'trash-2',
    restore: 'undo-2',
    reset: 'rotate-ccw',
    more: 'ellipsis',
    shuffle: 'shuffle',
    back: 'arrow-left',
    close: 'x',
    add: 'plus',
    arrowRight: 'arrow-right',
    chevronLeft: 'chevron-left',
    chevronRight: 'chevron-right',
    chevronUp: 'chevron-up',
    chevronDown: 'chevron-down',
    refresh: 'refresh-cw',
    eye: 'eye',
    eyeOff: 'eye-off',
    play: 'play',
    pause: 'pause',
    timer: 'timer',
    clock: 'clock-3',
    calendar: 'calendar-days',
    historyAction: 'history',
    radioSelected: 'circle-dot',
    radioUnselected: 'circle',
    checkboxChecked: 'square-check-big',
    checkboxUnchecked: 'square',
    imagePlaceholder: 'image',
    imageOff: 'image-off',
    wifi: 'wifi',
    error: 'circle-x',
    success: 'circle-check-big',
    check: 'check',
    circleHelp: 'circle-help',
    calloutQuote: 'quote',
    calloutTip: 'lightbulb',
    calloutInfo: 'info',
    calloutWarning: 'triangle-alert',
    calloutError: 'circle-x',
    calloutSuccess: 'circle-check-big',
    calloutCode: 'code-xml',
    deviceSystem: 'monitor-smartphone',
    theme: 'sun-moon',
    habitWater: 'glass-water',
    habitWalk: 'footprints',
    habitRead: 'book-open',
    habitLanguage: 'languages',
    habitPill: 'pill',
    candidateRun: 'activity',
    candidateSprout: 'sprout',
    candidateStar: 'star',
    candidateSun: 'sunrise',
    candidateMoon: 'moon',
    candidateMeditate: 'flower-2',
    candidateLift: 'dumbbell',
    candidateApple: 'apple',
    candidateBooks: 'library',
    pin: 'pin',
    warning: 'triangle-alert',
    chatFeedback: 'message-circle-heart',
    question: 'message-circle-question',
    reward: 'award',
    target: 'target',
    emptyTags: 'tags',
    emptyHabits: 'sprout',
    emptySearch: 'search',
  };

  static const Map<String, String> _lordiconSvgFiles = {
    emptyPast: 'system-outline-4092-book.svg',
    successCheck: 'system-outline-37-check.svg',
  };

  static const Map<String, String> _pngFiles = {
    brandIcon: 'app-icon.png',
    brandSplash: 'brand-splash-reference.png',
    brandSplashDark: 'brand-splash-dark.png',
  };

  static String path(String name) {
    final lucideFile = _lucideFiles[name];
    if (lucideFile != null) return 'assets/icons/lucide/$lucideFile.svg';

    final lordiconFile = _lordiconSvgFiles[name];
    if (lordiconFile != null) return 'assets/icons/lordicon/$lordiconFile';

    final pngFile = _pngFiles[name];
    if (pngFile != null) return 'assets/icon/$pngFile';
    return '';
  }

  static bool hasAsset(String name) => path(name).isNotEmpty;
  static bool isLucide(String name) => _lucideFiles.containsKey(name);
  static bool isLordicon(String name) => _lordiconSvgFiles.containsKey(name);

  static List<String> get all => [
    ..._lucideFiles.keys,
    ..._lordiconSvgFiles.keys,
    ..._pngFiles.keys,
  ];
}

/// 使用本地 SVG 渲染统一的静态界面图标。
class FloraIcon extends StatelessWidget {
  const FloraIcon(this.name, {super.key, double? size, this.color})
    : size = size ?? 24,
      _inheritThemeSize = size == null;

  final String name;
  final double size;
  final bool _inheritThemeSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final effectiveColor =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    final effectiveSize = _inheritThemeSize ? iconTheme.size ?? size : size;
    final assetPath = FloraIcons.path(name);
    if (assetPath.isEmpty) {
      assert(FloraIcons.hasAsset(name), 'Unknown Flora icon: $name');
      return SvgPicture.asset(
        FloraIcons.path(FloraIcons.circleHelp),
        width: effectiveSize,
        height: effectiveSize,
        colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      );
    }

    if (assetPath.endsWith('.png')) {
      return Image.asset(
        assetPath,
        width: effectiveSize,
        height: effectiveSize,
      );
    }

    return SvgPicture.asset(
      assetPath,
      width: effectiveSize,
      height: effectiveSize,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
    );
  }
}
