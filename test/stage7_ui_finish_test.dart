import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litchi_journal_flutter/models/diary_document.dart';
import 'package:litchi_journal_flutter/screens/appearance_settings_page.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/flora_empty.dart';
import 'package:litchi_journal_flutter/widgets/flora_error_state.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/flora_skeleton.dart';
import 'package:litchi_journal_flutter/widgets/flora_splash.dart';
import 'package:litchi_journal_flutter/widgets/habit_card.dart';
import 'package:litchi_journal_flutter/widgets/habit_steps_sheet.dart';
import 'package:litchi_journal_flutter/widgets/habit_water_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('阶段 7 设计令牌', () {
    test('一级、二级标题和四档圆角保持稳定', () {
      final theme = AppTheme.light;

      expect(FloraRadius.sm, 8);
      expect(FloraRadius.md, 12);
      expect(FloraRadius.lg, 16);
      expect(FloraRadius.pill, 9999);
      expect(theme.textTheme.headlineLarge?.fontSize, 24);
      expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.bold);
      expect(theme.textTheme.headlineLarge?.height, 1.25);
      expect(AppTheme.dark.textTheme.headlineLarge?.height, 1.25);
      expect(theme.appBarTheme.titleTextStyle?.fontSize, 18);
      expect(theme.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w600);
    });

    testWidgets('占位组件使用内容形状，不引入通用转圈', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Column(
              children: [
                FloraSkeletonBox(width: 180, height: 16),
                FloraSkeletonBox(width: 240, height: 16),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(FloraSkeletonBox), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('一组骨架占位只提供一次加载语义', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloraSkeletonRegion(
              child: Column(
                children: const [
                  FloraSkeletonBox(width: 180, height: 16),
                  FloraSkeletonBox(width: 240, height: 16),
                  FloraSkeletonBox(width: 120, height: 16),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('正在加载'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '正在加载',
        ),
        findsOneWidget,
      );
      semanticsHandle.dispose();
    });

    testWidgets('错误状态是 live region，重试按钮保持独立可操作', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloraErrorState(message: '加载失败', onRetry: () {}),
          ),
        ),
      );

      expect(
        tester
            .getSemantics(find.byType(FloraErrorState))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      expect(find.text('重试'), findsOneWidget);
      semanticsHandle.dispose();
    });

    testWidgets('空状态支持合并后的标题、说明和操作', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: FloraEmpty(
              name: FloraIcons.emptyPast,
              title: '还没有照片回忆',
              message: '已有文字记录的日子，可以从日历进入',
              action: TextButton(onPressed: () {}, child: const Text('打开日历')),
            ),
          ),
        ),
      );

      expect(find.text('还没有照片回忆'), findsOneWidget);
      expect(find.text('已有文字记录的日子，可以从日历进入'), findsOneWidget);
      expect(find.text('打开日历'), findsOneWidget);
    });

    testWidgets('外观页不重复显示常驻说明', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: const AppearanceSettingsPage()),
      );

      expect(find.text('选择你喜欢的显示方式'), findsNothing);
      expect(find.text('跟随系统'), findsOneWidget);
      expect(find.text('浅色模式'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);
    });

    test('减少动态效果时动效时长为零', () {
      const reducedMotion = MediaQueryData(disableAnimations: true);
      const normalMotion = MediaQueryData(disableAnimations: false);

      expect(FloraMotion.fastFor(reducedMotion), Duration.zero);
      expect(FloraMotion.standardFor(reducedMotion), Duration.zero);
      expect(FloraMotion.fastFor(normalMotion), FloraMotion.fast);
    });

    testWidgets('减少动态效果时习惯进度条不等待动画', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: HabitCard(
              section: HabitSection.empty(),
              onUpdate: (_) async => true,
            ),
          ),
        ),
      );

      final progressAnimations = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(progressAnimations, isNotEmpty);
      for (final animation in progressAnimations) {
        expect(animation.duration, Duration.zero);
      }
    });

    testWidgets('减少动态效果时饮水和步数面板立即切换', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    key: const ValueKey('open_steps_sheet'),
                    onPressed: () => showHabitStepsSheet(context, current: 0),
                    child: const Text('步数'),
                  ),
                  TextButton(
                    key: const ValueKey('open_water_sheet'),
                    onPressed: () => showHabitWaterSheet(
                      context,
                      current: 0,
                      quickAmounts: const [250, 500, 750],
                      accentColor: Colors.blue,
                    ),
                    child: const Text('饮水'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open_steps_sheet')));
      await tester.pumpAndSettle();
      final stepsPadding = tester.widget<AnimatedPadding>(
        find.ancestor(
          of: find.byKey(const ValueKey('habit_steps_sheet')),
          matching: find.byType(AnimatedPadding),
        ),
      );
      expect(stepsPadding.duration, Duration.zero);
      await tester.tap(find.byKey(const ValueKey('habit_steps_cancel')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_water_sheet')));
      await tester.pumpAndSettle();
      final waterPadding = tester.widget<AnimatedPadding>(
        find.ancestor(
          of: find.byKey(const ValueKey('habit_water_sheet_actions')),
          matching: find.byType(AnimatedPadding),
        ),
      );
      final waterSwitcher = tester.widget<AnimatedSwitcher>(
        find.ancestor(
          of: find.byKey(const ValueKey('habit_water_sheet_actions')),
          matching: find.byType(AnimatedSwitcher),
        ),
      );
      expect(waterPadding.duration, Duration.zero);
      expect(waterSwitcher.duration, Duration.zero);
    });
  });

  group('阶段 7 启动过渡', () {
    test('浅色和深色品牌启动资源分别存在', () async {
      expect(
        FloraIcons.path(FloraIcons.brandSplash),
        'assets/icon/brand-splash-reference.png',
      );
      expect(
        FloraIcons.path(FloraIcons.brandSplashDark),
        'assets/icon/brand-splash-dark.png',
      );
    });

    testWidgets('减少动态效果时启动过渡立即完成', (tester) async {
      var done = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.light,
            home: FloraSplash(onDone: () => done = true),
          ),
        ),
      );
      await tester.pump();

      expect(done, isTrue);
    });
  });
}
