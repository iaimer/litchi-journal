import 'package:flutter/material.dart';

class AppColors {
  // Light palette
  static const background = Color(0xFFF7F2EA);
  static const surface = Color(0xFFFFF7ED);
  static const surfaceElevated = Color(0xFFFFF7ED);
  static const surfaceSoft = Color(0xFFF8EBD8);
  static const textPrimary = Color(0xFF5A4A36);
  static const textSecondary = Color(0xFF806458);
  static const muted = Color(0xFF8D766A);
  static const primary = Color(0xFF955F50);
  static const accentSoft = Color(0x1F955F50);
  static const border = Color(0xFFD8C9B8);
  static const outline = Color(0xFF9B8174);
  static const outlineVariant = Color(0xFFD8C9B8);
  static const surfaceContainerHighest = Color(0xFFEFE2D2);
  static const success = Color(0xFF7BA67A);
  static const red = Color(0xFFB54A4A);
  static const tagBlue = Color(0xFF7A9CC6);
  static const tagGreen = Color(0xFF7BA67A);
  static const tagAmber = Color(0xFFC9A96E);

  // Dark palette
  static const darkBackground = Color(0xFF1F1B18);
  static const darkSurface = Color(0xFF2B241E);
  static const darkSurfaceElevated = Color(0xFF3A3027);
  static const darkTextPrimary = Color(0xFFF1E6D7);
  static const darkTextSecondary = Color(0xFFC8AA9A);
  static const darkMuted = Color(0xFFA68C7D);
  static const darkPrimary = Color(0xFFCA9A84);
  static const darkAccentSoft = Color(0x26CA9A84);
  static const darkBorder = Color(0xFF5B493B);
  static const darkOutline = Color(0xFF8E7465);
  static const darkOutlineVariant = Color(0xFF5B493B);
  static const darkSurfaceContainerHighest = Color(0xFF3A3027);
  static const darkSuccess = Color(0xFF8DB88A);
  static const darkRed = Color(0xFFE07A7A);
  static const darkTagBlue = Color(0xFF8AACD4);
  static const darkTagGreen = Color(0xFF8DC498);
  static const darkTagAmber = Color(0xFFD4B57A);
}

/// Today 页面七个日记模块的固定语义色。
///
/// 快速记录页的标签色板是另一套规则，不在这里复用。
class TodayRainbow {
  static const quickNote = Color(0xFFFF6B6B);
  static const happiness = Color(0xFFFF9F43);
  static const anxiety = Color(0xFFFFD43B);
  static const review = Color(0xFF51CF66);
  static const coach = Color(0xFF12B5CB);
  static const tomorrow = Color(0xFF4DABF7);
  static const media = Color(0xFF9775FA);

  static const values = <Color>[
    quickNote,
    happiness,
    anxiety,
    review,
    coach,
    tomorrow,
    media,
  ];

  static Color? forSectionType(String sectionType) {
    switch (sectionType) {
      case 'quickNote':
        return quickNote;
      case 'happiness':
        return happiness;
      case 'anxiety':
        return anxiety;
      case 'review':
        return review;
      case 'coach':
        return coach;
      case 'tomorrow':
        return tomorrow;
      case 'media':
        return media;
      default:
        return null;
    }
  }
}

@immutable
class AppCalloutColors extends ThemeExtension<AppCalloutColors> {
  final Color info;
  final Color warning;
  final Color success;
  final Color example;

  const AppCalloutColors({
    required this.info,
    required this.warning,
    required this.success,
    required this.example,
  });

  static const light = AppCalloutColors(
    info: Color(0xFF2D5F8C),
    warning: Color(0xFF7A4D00),
    success: Color(0xFF2F6844),
    example: Color(0xFF65499A),
  );

  static const dark = AppCalloutColors(
    info: Color(0xFF9CC7F0),
    warning: Color(0xFFFFC266),
    success: Color(0xFF9BCC9F),
    example: Color(0xFFC7A8FF),
  );

  @override
  AppCalloutColors copyWith({
    Color? info,
    Color? warning,
    Color? success,
    Color? example,
  }) {
    return AppCalloutColors(
      info: info ?? this.info,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      example: example ?? this.example,
    );
  }

  @override
  AppCalloutColors lerp(covariant AppCalloutColors? other, double t) {
    if (other == null) return this;
    return AppCalloutColors(
      info: Color.lerp(info, other.info, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      example: Color.lerp(example, other.example, t)!,
    );
  }
}

class FloraSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class FloraRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 9999.0;
}

/// 应用内自定义动效的统一时长。
///
/// 统一时长让页面状态变化保持在用户注意力可以跟上的范围内；
/// 系统开启减少动态效果时，组件直接落到目标状态。
class FloraMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);

  static Duration fastFor(MediaQueryData mediaQuery) =>
      mediaQuery.disableAnimations ? Duration.zero : fast;

  static Duration standardFor(MediaQueryData mediaQuery) =>
      mediaQuery.disableAnimations ? Duration.zero : standard;

  static Duration slowFor(MediaQueryData mediaQuery) =>
      mediaQuery.disableAnimations ? Duration.zero : slow;
}

class AppTheme {
  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      secondary: AppColors.textSecondary,
      onSecondary: AppColors.surface,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      surfaceTint: AppColors.primary,
      error: AppColors.red,
      onError: AppColors.surface,
    ),
    extensions: const [AppCalloutColors.light],
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FloraRadius.md),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FloraRadius.md),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FloraRadius.md),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FloraRadius.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 0.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FloraRadius.md),
        side: const BorderSide(color: AppColors.outlineVariant, width: 0.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withAlpha(45),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        );
      }),
    ),
    dividerColor: AppColors.outlineVariant,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.25,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.6,
      ),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
  );

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkBackground,
      secondary: AppColors.darkTextSecondary,
      onSecondary: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: AppColors.darkOutline,
      outlineVariant: AppColors.darkOutlineVariant,
      surfaceContainerHighest: AppColors.darkSurfaceContainerHighest,
      surfaceTint: AppColors.darkPrimary,
      error: AppColors.darkRed,
      onError: AppColors.darkBackground,
    ),
    extensions: const [AppCalloutColors.dark],
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FloraRadius.md),
        borderSide: const BorderSide(color: AppColors.darkOutline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FloraRadius.md),
        borderSide: const BorderSide(color: AppColors.darkOutline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FloraRadius.md),
        borderSide: const BorderSide(color: AppColors.darkPrimary),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: AppColors.darkBackground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FloraRadius.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkPrimary,
        side: const BorderSide(color: AppColors.darkPrimary, width: 0.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FloraRadius.md),
        side: const BorderSide(color: AppColors.darkOutlineVariant, width: 0.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      indicatorColor: AppColors.darkPrimary.withAlpha(70),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? AppColors.darkTextPrimary
              : AppColors.darkTextSecondary,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? AppColors.darkTextPrimary
              : AppColors.darkTextSecondary,
        );
      }),
    ),
    dividerColor: AppColors.darkOutlineVariant,
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.25,
        color: AppColors.darkTextPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextSecondary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.darkTextPrimary),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: AppColors.darkTextPrimary,
        height: 1.6,
      ),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
    ),
  );
}
