import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/journal_section.dart';
import 'package:litchi_journal_flutter/widgets/tag_color_helper.dart';

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

Color _paintedChipBackground(TagChipColors colors, Color base) {
  return Color.alphaBlend(colors.backgroundColor, base);
}

void _expectTextContrast(Color foreground, Color background) {
  expect(_contrastRatio(foreground, background), greaterThanOrEqualTo(4.5));
}

void _expectOutlineContrast(Color outline, Color background) {
  expect(_contrastRatio(outline, background), greaterThanOrEqualTo(3));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('阶段 4 Lucide 图标资源', () {
    const normalizedIcons = <String>[
      FloraIcons.shuffle,
      FloraIcons.close,
      FloraIcons.habitWalk,
      FloraIcons.habitLanguage,
      FloraIcons.candidateRun,
      FloraIcons.candidateSun,
      FloraIcons.candidateMeditate,
      FloraIcons.candidateLift,
      FloraIcons.candidateApple,
      FloraIcons.candidateBooks,
      FloraIcons.pin,
      FloraIcons.chatFeedback,
      FloraIcons.fabInsight,
    ];

    test('通用动作与习惯图标使用固定的逻辑资源映射', () {
      expect(
        FloraIcons.path(FloraIcons.shuffle),
        'assets/icons/lucide/shuffle.svg',
      );
      expect(FloraIcons.path(FloraIcons.close), 'assets/icons/lucide/x.svg');
      expect(
        FloraIcons.path(FloraIcons.habitWalk),
        'assets/icons/lucide/footprints.svg',
      );
      expect(
        FloraIcons.path(FloraIcons.habitLanguage),
        'assets/icons/lucide/languages.svg',
      );
      expect(
        FloraIcons.path(FloraIcons.fabWrite),
        'assets/icons/lucide/pen-line.svg',
      );
      expect(
        FloraIcons.path(FloraIcons.fabInsight),
        'assets/icons/lucide/eye.svg',
      );
    });

    test('已注册的产品图标都能解析到资源', () async {
      for (final name in FloraIcons.all) {
        if (name == FloraIcons.brandIcon ||
            name == FloraIcons.brandSplash ||
            name == FloraIcons.brandSplashDark) {
          continue;
        }
        final path = FloraIcons.path(name);
        expect(path, isNotEmpty, reason: '$name 应该有资源路径');
        expect(await rootBundle.loadString(path), isNotEmpty, reason: name);
      }
    });

    test('规范化 Flora SVG 使用 24x24、2px 圆角描边', () async {
      for (final name in normalizedIcons) {
        final path = FloraIcons.path(name);
        expect(path, isNotEmpty, reason: '$name 应该有资源');
        final svg = await rootBundle.loadString(path);
        expect(svg, contains('viewBox="0 0 24 24"'), reason: name);
        expect(svg, contains('fill="none"'), reason: name);
        expect(svg, contains('stroke="currentColor"'), reason: name);
        expect(svg, contains('stroke-width="2"'), reason: name);
        expect(svg, contains('stroke-linecap="round"'), reason: name);
        expect(svg, contains('stroke-linejoin="round"'), reason: name);
      }
    });
  });

  group('阶段 5 Material 3 语义颜色', () {
    test('浅色主题公开完整的层级颜色角色', () {
      final scheme = AppTheme.light.colorScheme;
      expect(scheme.onSurfaceVariant, const Color(0xFF806458));
      expect(scheme.outline, const Color(0xFF9B8174));
      expect(scheme.outlineVariant, const Color(0xFFD8C9B8));
      expect(scheme.surfaceContainerHighest, const Color(0xFFEFE2D2));
      expect(scheme.surfaceTint, const Color(0xFF955F50));
      expect(scheme.error, const Color(0xFFB54A4A));
      _expectTextContrast(scheme.onSurface, scheme.surface);
      _expectTextContrast(scheme.onSurfaceVariant, scheme.surface);
      _expectTextContrast(scheme.error, scheme.surface);
      _expectTextContrast(scheme.primary, scheme.surface);
      _expectTextContrast(
        scheme.primary,
        AppTheme.light.scaffoldBackgroundColor,
      );
      _expectOutlineContrast(scheme.outline, scheme.surface);
    });

    test('深色主题保持同等层级和可操作边界', () {
      final scheme = AppTheme.dark.colorScheme;
      expect(scheme.onSurfaceVariant, const Color(0xFFC8AA9A));
      expect(scheme.outline, const Color(0xFF8E7465));
      expect(scheme.outlineVariant, const Color(0xFF5B493B));
      expect(scheme.surfaceContainerHighest, const Color(0xFF3A3027));
      expect(scheme.surfaceTint, const Color(0xFFCA9A84));
      expect(scheme.error, const Color(0xFFE07A7A));
      _expectTextContrast(scheme.onSurface, scheme.surface);
      _expectTextContrast(scheme.onSurfaceVariant, scheme.surface);
      _expectTextContrast(scheme.error, scheme.surface);
      _expectTextContrast(scheme.primary, scheme.surface);
      _expectTextContrast(
        scheme.primary,
        AppTheme.dark.scaffoldBackgroundColor,
      );
      _expectOutlineContrast(scheme.outline, scheme.surface);
    });

    test('Today Rainbow 标签在最终混合背景上满足文字对比度', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        for (final moduleColor in TodayRainbow.values) {
          for (final selected in [false, true]) {
            final colors = tagChipColorsFor(
              label: '测试标签',
              tagConfig: null,
              theme: theme,
              selected: selected,
              moduleAccentColor: moduleColor,
            );
            for (final base in [
              theme.colorScheme.surface,
              theme.scaffoldBackgroundColor,
            ]) {
              final background = _paintedChipBackground(colors, base);
              _expectTextContrast(colors.textColor, background);
            }
          }
        }
      }
    });

    test('Today Rainbow 只映射七个系统章节', () {
      expect(TodayRainbow.forSectionType('quickNote'), TodayRainbow.quickNote);
      expect(TodayRainbow.forSectionType('happiness'), TodayRainbow.happiness);
      expect(TodayRainbow.forSectionType('anxiety'), TodayRainbow.anxiety);
      expect(TodayRainbow.forSectionType('review'), TodayRainbow.review);
      expect(TodayRainbow.forSectionType('coach'), TodayRainbow.coach);
      expect(TodayRainbow.forSectionType('tomorrow'), TodayRainbow.tomorrow);
      expect(TodayRainbow.forSectionType('media'), TodayRainbow.media);
      expect(TodayRainbow.forSectionType('habit'), isNull);
      expect(TodayRainbow.forSectionType('generic'), isNull);
    });

    test('Callout 语义颜色在抬升表面上保持可读', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final colors = theme.extension<AppCalloutColors>()!;
        final calloutColors = [
          colors.info,
          colors.warning,
          colors.success,
          colors.example,
        ];
        final alpha = theme.brightness == Brightness.dark ? 42 : 24;
        for (final color in calloutColors) {
          final background = Color.alphaBlend(
            color.withAlpha(alpha),
            theme.colorScheme.surfaceContainerHighest,
          );
          _expectTextContrast(color, background);
        }
      }
    });
  });

  testWidgets('通用条目操作槽使用 Lucide 图标和 48dp 热区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: JournalEntryActionSlot(
            alignToTags: true,
            busy: false,
            onPressed: () {},
          ),
        ),
      ),
    );

    final moreIcon = find.byWidgetPredicate(
      (widget) => widget is FloraIcon && widget.name == FloraIcons.more,
    );
    expect(moreIcon, findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
    final menuCenter = tester.getCenter(moreIcon);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: JournalEntryActionSlot(alignToTags: true, busy: true),
        ),
      ),
    );

    final loadingCenter = tester.getCenter(
      find.byType(CircularProgressIndicator),
    );
    expect((loadingCenter.dy - menuCenter.dy).abs(), lessThanOrEqualTo(1));
  });
}
