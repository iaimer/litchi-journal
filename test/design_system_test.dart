import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/diary_markdown_view.dart';
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
  for (final dark in [false, true]) {
    for (final readOnly in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('真实回顾标题前景 dark=$dark readOnly=$readOnly scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 1400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final theme = dark ? AppTheme.dark : AppTheme.light;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: DiaryMarkdownView(
                    markdown: '### 人生教练\n模式识别\n今天留意到了自己的感受。\n暖心鼓励\n允许自己慢慢来。',
                    readOnly: readOnly,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final heading in ['模式识别', '暖心鼓励']) {
            final text = tester.widget<Text>(find.text(heading));
            expect(
              text.style!.color,
              moduleTextColor(TodayRainbow.coach, theme),
            );
            _expectTextContrast(
              text.style!.color!,
              theme.scaffoldBackgroundColor,
            );
            _expectTextContrast(text.style!.color!, theme.colorScheme.surface);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final dark in [false, true]) {
    for (final width in [320.0, 430.0]) {
      testWidgets('真实时间文字使用可读模块前景 dark=$dark width=$width', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = dark ? AppTheme.dark : AppTheme.light;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: DiaryMarkdownView(
                  markdown:
                      "## 随手记 & 灵感\n- **08:30** 一条记录 #生活\n## 每日小确幸\n> **10:20** 开心的小事 #日常\n### 觉察与迭代\n- **12:15** 此刻的感受 #情绪",
                  readOnly: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final time in ['08:30', '10:20', '12:15']) {
          final text = tester.widget<Text>(find.text(time));
          _expectTextContrast(
            text.style!.color!,
            theme.scaffoldBackgroundColor,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final dark in [false, true]) {
    testWidgets('focused input labels stay readable dark=$dark', (
      tester,
    ) async {
      final theme = dark ? AppTheme.dark : AppTheme.light;
      final focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: TextField(
              focusNode: focus,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      final label = tester.renderObject<RenderParagraph>(find.text('Address'));
      _expectTextContrast(label.text.style!.color!, theme.colorScheme.surface);
      final border =
          theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
      _expectOutlineContrast(
        border.borderSide.color,
        theme.colorScheme.surface,
      );
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    });
    test('text buttons retain disabled state dark=$dark', () {
      final theme = dark ? AppTheme.dark : AppTheme.light;
      final colors = theme.textButtonTheme.style!.foregroundColor!;
      expect(colors.resolve({WidgetState.disabled}), isNot(colors.resolve({})));
      _expectTextContrast(colors.resolve({})!, theme.colorScheme.surface);
    });
  }

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
      expect(scheme.onSurfaceVariant, const Color(0xFF666E68));
      expect(scheme.outline, const Color(0xFF89928B));
      expect(scheme.outlineVariant, const Color(0xFFE4E9E5));
      expect(scheme.surfaceContainerHighest, const Color(0xFFEDF1EE));
      expect(scheme.surfaceTint, const Color(0xFFF5B2C5));
      expect(scheme.error, const Color(0xFFB54A4A));
      _expectTextContrast(scheme.onSurface, scheme.surface);
      _expectTextContrast(scheme.onSurfaceVariant, scheme.surface);
      _expectTextContrast(scheme.error, scheme.surface);
      _expectTextContrast(scheme.onPrimary, scheme.primary);
      _expectTextContrast(
        AppColors.actionText,
        AppTheme.light.scaffoldBackgroundColor,
      );
      _expectOutlineContrast(scheme.outline, scheme.surface);
    });

    test('深色主题保持同等层级和可操作边界', () {
      final scheme = AppTheme.dark.colorScheme;
      expect(scheme.onSurfaceVariant, const Color(0xFFB7BFB8));
      expect(scheme.outline, const Color(0xFF89978D));
      expect(scheme.outlineVariant, const Color(0xFF3E4941));
      expect(scheme.surfaceContainerHighest, const Color(0xFF2D332F));
      expect(scheme.surfaceTint, const Color(0xFFF5B2C5));
      expect(scheme.error, const Color(0xFFE07A7A));
      _expectTextContrast(scheme.onSurface, scheme.surface);
      _expectTextContrast(scheme.onSurfaceVariant, scheme.surface);
      _expectTextContrast(scheme.error, scheme.surface);
      _expectTextContrast(scheme.onPrimary, scheme.primary);
      _expectTextContrast(
        scheme.primary,
        AppTheme.dark.scaffoldBackgroundColor,
      );
      _expectOutlineContrast(scheme.outline, scheme.surface);
    });

    test('五色时间与彩色标题前景在浅深色表面满足对比度', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        for (final color in TodayRainbow.values) {
          for (final background in [
            theme.colorScheme.surface,
            theme.scaffoldBackgroundColor,
          ]) {
            _expectTextContrast(moduleTextColor(color, theme), background);
          }
        }
      }
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

    test('五模块主色与历史兼容映射', () {
      expect(TodayRainbow.values, const [
        Color(0xFFF08F8F),
        Color(0xFFF0B36F),
        Color(0xFF8DB993),
        Color(0xFF85ACD8),
        Color(0xFFAC98CD),
      ]);
      expect(TodayRainbow.anxiety, TodayRainbow.review);
      expect(TodayRainbow.media, TodayRainbow.tomorrow);
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
