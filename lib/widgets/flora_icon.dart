import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Flora Design System — custom SVG icon registry.
///
/// Maps logical icon names to the user-provided SVG files from
/// assets/svg/. All icons use currentColor for theme adaptivity.
///
/// Usage:
///   FloraIcon(FloraIcons.diary, size: 24)
///   FloraIcon(FloraIcons.habits, size: 20, color: AppColors.primary)
///
/// To add a new icon:
///   1. Place the SVG file in assets/svg/
///   2. Add a `static const` entry below
///   3. Add an entry in [_svgFiles] (or [_pngFiles] for PNG assets)
///   4. Reference by name
class FloraIcons {
  FloraIcons._();

  // ─── P0 · Navigation ─────────────────────────────────────
  static const String diary = 'diary';
  static const String history = 'history';
  static const String habits = 'habits';
  static const String settings = 'settings';
  static const String coach = 'coach';

  // ─── P0 · FAB ────────────────────────────────────────────
  static const String fabWrite = 'fab-write';
  static const String fabInsight = 'fab-insight';
  static const String fabHappy = 'fab-happy';
  static const String fabAnxiety = 'fab-anxiety';
  static const String fabPhoto = 'fab-photo';

  // ─── P1 · Settings ──────────────────────────────────────
  static const String settingAppearance = 'setting-appearance';
  static const String settingHabits = 'setting-habits';
  static const String settingTags = 'setting-tags';
  static const String settingCloud = 'setting-cloud';
  static const String settingAi = 'setting-ai';
  static const String settingPrompt = 'setting-prompt';
  static const String settingImage = 'setting-image';
  static const String settingAbout = 'setting-about';

  // ─── P1 · Edit actions ──────────────────────────────────
  static const String edit = 'edit';
  static const String restore = 'restore';
  static const String reset = 'reset';
  static const String more = 'more';
  static const String shuffle = 'shuffle';

  // ─── P2 · Diary marks ───────────────────────────────────
  static const String back = 'back';
  static const String close = 'close';
  static const String imagePlaceholder = 'image-placeholder';
  static const String check = 'check';
  static const String deviceSystem = 'device-system';
  static const String theme = 'theme';

  // ─── P2 · Default habits ────────────────────────────────
  static const String habitWater = 'habit-water';
  static const String habitWalk = 'habit-walk';
  static const String habitRead = 'habit-read';
  static const String habitLanguage = 'habit-language';
  static const String habitPill = 'habit-pill';

  // ─── P2 · Habit candidates ──────────────────────────────
  static const String candidateRun = 'candidate-run';
  static const String candidateSprout = 'candidate-sprout';
  static const String candidateStar = 'candidate-star';
  static const String candidateSun = 'candidate-sun';
  static const String candidateMoon = 'candidate-moon';
  static const String candidateMeditate = 'candidate-meditate';
  static const String candidateLift = 'candidate-lift';
  static const String candidateApple = 'candidate-apple';
  static const String candidateBooks = 'candidate-books';

  // ─── P2 · AI content markers ────────────────────────────
  static const String pin = 'pin';
  static const String warning = 'warning';
  static const String chatFeedback = 'chat-feedback';
  static const String question = 'question';
  static const String reward = 'reward';
  static const String target = 'target';

  // ─── Brand & empty states ───────────────────────────────
  static const String brandIcon = 'brand-icon';
  static const String brandSplash = 'brand-splash';
  static const String brandSplashDark = 'brand-splash-dark';
  static const String emptyPast = 'empty-past';
  static const String emptyTags = 'empty-tags';
  static const String emptyHabits = 'empty-habits';
  static const String emptySearch = 'empty-search';

  /// Maps logical icon name → SVG filename (without .svg extension).
  static const Map<String, String> _svgFiles = {
    // ── P0 Navigation ──
    diary: 'leaf-svgrepo-com',
    history: 'schedule-svgrepo-com',
    habits: 'double-check-svgrepo-com',
    settings: 'gear-svgrepo-com',
    coach: 'light-bulb-svgrepo-com',
    // ── P0 FAB ──
    fabWrite: 'chat-edit-svgrepo-com',
    fabInsight: 'chat-dots-svgrepo-com',
    fabHappy: 'heart-svgrepo-com',
    fabAnxiety: 'face-neutral-svgrepo-com',
    fabPhoto: 'image-pen-svgrepo-com',
    // ── P1 Settings ──
    settingAppearance: 'palette-svgrepo-com',
    settingHabits: 'check-svgrepo-com',
    settingTags: 'ribbon-svgrepo-com',
    settingCloud: 'cloud-svgrepo-com',
    settingAi: 'star-svgrepo-com',
    settingPrompt: 'comment-svgrepo-com',
    settingImage: 'image-svgrepo-com',
    settingAbout: 'circle-information-svgrepo-com',
    // ── P1 Edit actions ──
    edit: 'pencil-svgrepo-com',
    restore: 'arrow-counter-clockwise-svgrepo-com',
    reset: 'arrow-cycle-svgrepo-com',
    more: 'more-horizontal-svgrepo-com',
    shuffle: 'people-group-svgrepo-com',
    // ── P2 Diary marks ──
    back: 'arrow-left-svgrepo-com',
    close: 'plus-svgrepo-com',
    imagePlaceholder: 'camera-svgrepo-com',
    check: 'check-svgrepo-com',
    deviceSystem: 'devices-svgrepo-com',
    theme: 'monitor-sun-svgrepo-com',
    // ── P2 Default habits ──
    habitWater: 'mug-sauser-svgrepo-com',
    habitWalk: 'footsteps-silhouette-variant-svgrepo-com',
    habitRead: 'book-svgrepo-com',
    habitLanguage: 'naver-dictionary-svgrepo-com',
    habitPill: 'capsule-svgrepo-com',
    // ── P2 Habit candidates ──
    candidateRun: 'running-svgrepo-com',
    candidateSprout: 'plant-svgrepo-com',
    candidateStar: 'writing-notepad-svgrepo-com',
    candidateSun: 'sunrise-svgrepo-com',
    candidateMoon: 'bed-svgrepo-com',
    candidateMeditate: 'meditation-svgrepo-com',
    candidateLift: 'weight-1-svgrepo-com',
    candidateApple: 'fruit-food-apple-svgrepo-com',
    candidateBooks: 'books-svgrepo-com',
    // ── P2 AI content markers ──
    pin: 'pin-list-svgrepo-com',
    warning: 'alert-triangle-svgrepo-com',
    chatFeedback: 'chat-dots-svgrepo-com_2',
    question: 'chat-question-svgrepo-com',
    reward: 'thumbs-up-svgrepo-com',
    target: 'target-04-svgrepo-com',
    // ── Brand & empty states ──
    brandSplash: 'brand-splash',
    brandSplashDark: 'brand-splash-dark',
    emptyPast: 'empty-past',
    emptyTags: 'empty-tags',
    emptyHabits: 'empty-habits',
    emptySearch: 'empty-search',
  };

  /// Maps logical icon name → PNG filename (with extension).
  static const Map<String, String> _pngFiles = {brandIcon: 'app-icon.png'};

  static const String _svgPrefix = 'assets/svg/';
  static const String _svgSuffix = '.svg';
  static const String _pngPrefix = 'assets/icon/';

  /// Returns the asset path for a named icon.
  ///
  /// For SVG icons returns `assets/svg/<filename>.svg`.
  /// For PNG icons returns `assets/svg/<filename>`.
  /// For not-yet-designed entries returns an empty string.
  static String path(String name) {
    final svgFile = _svgFiles[name];
    if (svgFile != null && svgFile.isNotEmpty) {
      return '$_svgPrefix$svgFile$_svgSuffix';
    }
    final pngFile = _pngFiles[name];
    if (pngFile != null && pngFile.isNotEmpty) {
      return '$_pngPrefix$pngFile';
    }
    return '';
  }

  static bool hasAsset(String name) => path(name).isNotEmpty;

  /// All available icon names (for previews, debug).
  static List<String> get all => [
    diary,
    history,
    habits,
    settings,
    coach,
    fabWrite,
    fabInsight,
    fabHappy,
    fabAnxiety,
    fabPhoto,
    settingAppearance,
    settingHabits,
    settingTags,
    settingCloud,
    settingAi,
    settingPrompt,
    settingImage,
    settingAbout,
    edit,
    restore,
    reset,
    more,
    shuffle,
    back,
    close,
    imagePlaceholder,
    check,
    deviceSystem,
    theme,
    habitWater,
    habitWalk,
    habitRead,
    habitLanguage,
    habitPill,
    candidateRun,
    candidateSprout,
    candidateStar,
    candidateSun,
    candidateMoon,
    candidateMeditate,
    candidateLift,
    candidateApple,
    candidateBooks,
    pin,
    warning,
    chatFeedback,
    question,
    reward,
    target,
    brandIcon,
    brandSplash,
    emptyPast,
    emptyTags,
    emptyHabits,
    emptySearch,
  ];
}

/// Flora-branded SVG icon widget.
///
/// Renders a vector icon from the Flora icon set. All icons are from
/// the user-provided SVG set in assets/svg/, using currentColor for
/// theme adaptivity.
///
/// ```dart
/// FloraIcon(FloraIcons.diary, size: 24)
/// FloraIcon(FloraIcons.coach, size: 20, color: AppColors.primary)
/// ```
class FloraIcon extends StatelessWidget {
  const FloraIcon(this.name, {super.key, this.size = 24, this.color});

  /// The logical icon name (one of [FloraIcons] constants).
  final String name;

  /// Icon dimensions (width and height). Defaults to 24.
  final double size;

  /// Icon color. Defaults to [ColorScheme.onSurface] in context.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    final assetPath = FloraIcons.path(name);
    if (assetPath.isEmpty) {
      return Icon(Icons.circle, size: size, color: effectiveColor);
    }
    if (assetPath.endsWith('.png')) {
      return Image.asset(assetPath, width: size, height: size);
    }
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
    );
  }
}
