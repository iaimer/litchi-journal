import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:litchi_journal_flutter/screens/past_screen.dart';
import 'package:litchi_journal_flutter/screens/habit_stats_screen.dart';
import 'package:litchi_journal_flutter/screens/home_screen.dart';
import 'package:litchi_journal_flutter/services/api_client.dart';
import 'package:litchi_journal_flutter/services/api_config.dart';
import 'package:litchi_journal_flutter/services/habit_settings_repository.dart';
import 'package:litchi_journal_flutter/services/habit_trend_cache_repository.dart';
import 'package:litchi_journal_flutter/theme/app_theme.dart';
import 'package:litchi_journal_flutter/widgets/diary_date_title.dart';
import 'package:litchi_journal_flutter/widgets/flora_app_bar.dart';
import 'package:litchi_journal_flutter/widgets/flora_glass.dart';
import 'package:litchi_journal_flutter/widgets/flora_icon.dart';
import 'package:litchi_journal_flutter/widgets/flora_primary_header.dart';
import 'package:litchi_journal_flutter/widgets/flora_skeleton.dart';

void main() {
  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('习惯页顶部接缝：深色=$dark，高对比=$highContrast，字体=$scale', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(const Size(320, 720));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final pending = Completer<http.Response>();
          await _mountHabits(
            tester,
            dark: dark,
            highContrast: highContrast,
            textScale: scale,
            initialStats: pending,
          );
          expect(find.byType(FloraSkeletonRegion), findsOneWidget);
          await _expectPaperSeam(tester, dark: dark);
          pending.complete(_json([]));
          await tester.pumpAndSettle();
          expect(find.byType(SegmentedButton), findsNothing);
          await _expectPaperSeam(tester, dark: dark);
          expect(tester.takeException(), isNull);
        });
      }
      testWidgets('习惯玻璃渐进滚动并恢复纸色：深色=$dark，高对比=$highContrast', (tester) async {
        await _mountHabits(tester, dark: dark, highContrast: highContrast);
        final theme = dark ? AppTheme.dark : AppTheme.light;
        final titleRect = tester.getRect(find.text('习惯趋势'));
        final ink = await _titleInk(tester, theme.colorScheme.onSurface);
        expect(ink, isNotEmpty);
        final controller = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!;
        for (final offset in [
          0.0,
          8.0,
          12.0,
          16.0,
          20.0,
          24.0,
          48.0,
          -8.0,
          0.0,
        ]) {
          controller.jumpTo(offset);
          await tester.pumpAndSettle();
          final strength = ((offset - 8) / 16).clamp(0.0, 1.0);
          _expectGlassStrength(tester, theme, strength, highContrast);
          expect(tester.getRect(find.text('习惯趋势')), titleRect);
          expect(await _titleInk(tester, theme.colorScheme.onSurface), ink);
        }
        await _expectPaperSeam(tester, dark: dark);
      });
    }
  }

  testWidgets('年趋势刷新不重置玻璃滚动位置', (tester) async {
    await _mountHabits(tester);
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    controller.jumpTo(16);
    await tester.pumpAndSettle();
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(controller.offset, 16);
    _expectGlassStrength(tester, AppTheme.light, 0.5, false);
  });

  for (final dark in [false, true]) {
    testWidgets('习惯页淡彩摘要经过顶部正确模糊且标题清晰：深色=$dark', (tester) async {
      await _mountHabits(tester, dark: dark);
      final theme = dark ? AppTheme.dark : AppTheme.light;
      final metric = find.byKey(const ValueKey('habit_metric_reading'));
      final title = tester.getRect(find.text('习惯趋势'));
      final controller = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      controller.jumpTo(tester.getRect(metric).top - title.top);
      await tester.pumpAndSettle();
      final x = tester.getRect(metric).center.dx;
      final filtered = await _verticalContrast(tester, x, title.top - 12, 24);
      final ink = await _titleInk(tester, theme.colorScheme.onSurface);
      final filter = tester.renderObject<RenderBackdropFilter>(
        find.descendant(
          of: find.byType(FloraGlassHeader),
          matching: find.byType(BackdropFilter),
        ),
      );
      // 单变量对照：保留同一底色、透明度和位置，仅移除背景模糊。
      final original = filter.filterConfig;
      filter.filterConfig = ImageFilterConfig(ui.ImageFilter.blur());
      await tester.pump();
      final plain = await _verticalContrast(tester, x, title.top - 12, 24);
      expect(plain, greaterThan(0));
      expect(filtered, lessThan(plain));
      expect(await _titleInk(tester, theme.colorScheme.onSurface), ink);
      filter.filterConfig = original;
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('三个主页面收起 Banner 统一最小高度并支持日期换行', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final scale in [1.0, 1.3]) {
      await tester.pumpWidget(
        _app(PastScreen(apiClient: _client()), textScale: scale),
      );
      await tester.pumpAndSettle();
      expect(
        _headerRect(tester).height,
        closeTo(24 + FloraPrimaryHeader.contentHeight, 0.5),
      );

      await tester.pumpWidget(
        _app(
          HabitStatsScreen(
            apiClient: _client(),
            habitSettingsRepo: HabitSettingsRepository(
              storage: _MemoryStorage(),
            ),
            trendCacheRepo: HabitTrendCacheRepository(
              storage: _MemoryStorage(),
            ),
          ),
          textScale: scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _headerRect(tester).height,
        closeTo(24 + FloraPrimaryHeader.contentHeight, 0.5),
      );

      final date = DateTime.now();
      final weekday = const [
        '一',
        '二',
        '三',
        '四',
        '五',
        '六',
        '日',
      ][date.weekday - 1];
      await tester.pumpWidget(
        _app(
          HomeScreen(
            apiClient: _client(),
            habitSettingsRepo: HabitSettingsRepository(
              storage: _MemoryStorage(),
            ),
          ),
          textScale: scale,
        ),
      );
      await tester.pump();
      final appBar = find.byType(AppBar);
      final dateRect = tester.getRect(find.text('${date.month}月${date.day}日'));
      final weekdayRect = tester.getRect(find.text('星期$weekday'));
      if (weekdayRect.top >= dateRect.bottom) {
        expect(weekdayRect.left, closeTo(dateRect.left, 0.5));
        expect(
          tester.getSize(appBar).height,
          greaterThan(24 + FloraPrimaryHeader.contentHeight),
        );
      } else {
        expect(
          tester.getSize(appBar).height,
          closeTo(24 + FloraPrimaryHeader.contentHeight, 0.5),
        );
      }
      expect(weekdayRect.right, lessThanOrEqualTo(320 - 16 - 48));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('窄屏长日期完整换行，短日期保持同行', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final shortDate = DateTime(2026, 1, 1);
    final longDate = DateTime(2026, 12, 31);

    await tester.pumpWidget(_compactHomeApp(shortDate, textScale: 1));
    await tester.pumpAndSettle();
    final dateRect = tester.getRect(find.text('1月1日'));
    final weekdayRect = tester.getRect(find.text('星期四'));
    expect(weekdayRect.top, lessThan(dateRect.bottom));
    expect(
      tester.getSize(find.byType(AppBar)).height,
      closeTo(24 + FloraPrimaryHeader.contentHeight, 0.5),
    );

    await tester.pumpWidget(_compactHomeApp(longDate, textScale: 1.3));
    await tester.pumpAndSettle();
    final wrappedDateRect = tester.getRect(find.text('12月31日'));
    final wrappedWeekdayRect = tester.getRect(find.text('星期四'));
    expect(wrappedWeekdayRect.left, closeTo(wrappedDateRect.left, 0.5));
    expect(
      wrappedWeekdayRect.top,
      greaterThanOrEqualTo(wrappedDateRect.bottom),
    );
    expect(tester.getSize(find.text('星期四')).width, greaterThanOrEqualTo(40));
    expect(
      tester.getSize(find.byType(AppBar)).height,
      greaterThan(24 + FloraPrimaryHeader.contentHeight),
    );
  });

  testWidgets('主页面标题在更大字体下自然增加 Banner 高度', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(PastScreen(apiClient: _client()), textScale: 2),
    );
    await tester.pumpAndSettle();
    expect(
      _headerRect(tester).height,
      greaterThan(24 + FloraPrimaryHeader.contentHeight),
    );

    await tester.pumpWidget(
      _app(
        HabitStatsScreen(
          apiClient: _client(),
          habitSettingsRepo: HabitSettingsRepository(storage: _MemoryStorage()),
          trendCacheRepo: HabitTrendCacheRepository(storage: _MemoryStorage()),
        ),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _headerRect(tester).height,
      greaterThan(24 + FloraPrimaryHeader.contentHeight),
    );
  });

  testWidgets('冷启动屏幕元信息未就绪时，图墙占位使用实际可用宽度', (tester) async {
    final pending = Completer<http.Response>();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: Size.zero),
          child: child!,
        ),
        home: PastScreen(apiClient: _client(initialGallery: pending)),
      ),
    );
    expect(tester.takeException(), isNull);
    final boxes = find.byType(FloraSkeletonBox);
    expect(boxes, findsNWidgets(7));
    final viewportWidth = tester.getSize(find.byType(CustomScrollView)).width;
    expect(
      tester.getSize(boxes.at(1)).width,
      closeTo((viewportWidth - 44) / 3, 0.01),
    );
    for (final box in boxes.evaluate()) {
      final size = tester.getSize(find.byWidget(box.widget));
      expect(size.width, greaterThanOrEqualTo(0));
      expect(size.height, greaterThanOrEqualTo(0));
    }
    pending.complete(_json({'months': [], 'nextCursor': null}));
    await tester.pumpAndSettle();
  });

  testWidgets('过往标题置顶，图墙进入同一视口的标题背后', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(PastScreen(apiClient: _client())));
    await tester.pumpAndSettle();

    final scroll = find.byType(CustomScrollView);
    expect(tester.getRect(scroll).top, 0);
    final titleRect = tester.getRect(find.text('过往'));
    final tile = find.byKey(const ValueKey('2024-03-01-photo-1.png'));
    final initialTileRect = tester.getRect(tile);
    final sample = Offset(
      initialTileRect.center.dx,
      _headerRect(tester).bottom - 12,
    );
    final before = await _pixelAt(tester, sample);
    final view = tester.widget<CustomScrollView>(scroll);
    view.controller!.jumpTo(125);
    await tester.pumpAndSettle();

    final header = _headerRect(tester);
    expect(tester.getRect(find.text('过往')), titleRect);
    expect(tester.getRect(tile).top, closeTo(initialTileRect.top - 125, 0.5));
    expect(tester.getRect(tile).overlaps(header), isTrue);
    _expectHeaderPaintedLast(tester);
    final after = await _pixelAt(tester, sample);
    expect(after.b - after.r, greaterThan(before.b - before.r + 20 / 255));
    expect(tester.takeException(), isNull);
  });

  testWidgets('习惯标题置顶，指标能滚入标题背后且刷新保留内容', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _MemoryStorage();
    await tester.pumpWidget(
      _app(
        HabitStatsScreen(
          apiClient: _client(),
          habitSettingsRepo: HabitSettingsRepository(storage: storage),
          trendCacheRepo: HabitTrendCacheRepository(storage: storage),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scroll = find.byType(CustomScrollView);
    expect(scroll, findsOneWidget);
    expect(tester.getRect(scroll).top, 0);
    final titleRect = tester.getRect(find.text('习惯趋势'));
    final metric = find.byKey(const ValueKey('habit_metric_reading'));
    final initialMetricRect = tester.getRect(metric);
    final sample = Offset(
      initialMetricRect.right - 12,
      _headerRect(tester).bottom - 8,
    );
    final before = await _pixelAt(tester, sample);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(initialMetricRect.top - titleRect.top);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('习惯趋势')), titleRect);
    expect(tester.getRect(metric).overlaps(_headerRect(tester)), isTrue);
    _expectHeaderPaintedLast(tester);
    final after = await _pixelAt(tester, sample);
    final difference =
        (before.r - after.r).abs() +
        (before.g - after.g).abs() +
        (before.b - after.b).abs();
    expect(difference, greaterThan(0.03));
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    expect(refresh.edgeOffset, closeTo(_headerRect(tester).height, 0.5));
    final offset = position.pixels;
    final future = refresh.onRefresh();
    await tester.pump();
    expect(metric, findsOneWidget);
    await future;
    await tester.pumpAndSettle();
    expect(position.pixels, offset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      testWidgets('过往日历自然展开和收起：深色=$dark，高对比=$highContrast', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(
            PastScreen(apiClient: _client()),
            dark: dark,
            highContrast: highContrast,
          ),
        );
        await tester.pumpAndSettle();

        final title = tester.getRect(find.text('过往'));
        final collapsed = _headerRect(tester);
        final controller = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!;
        controller.jumpTo(125);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('history_calendar_toggle')));
        await tester.pumpAndSettle();

        final expanded = _headerRect(tester);
        final calendar = tester.getRect(
          find.byKey(const Key('history_calendar')),
        );
        expect(expanded.height, greaterThan(collapsed.height + 300));
        expect(calendar.bottom, lessThanOrEqualTo(expanded.bottom));
        expect(expanded.bottom, lessThan(720));
        expect(tester.getRect(find.text('过往')), title);
        expect(controller.offset, 125);
        expect(
          tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .edgeOffset,
          closeTo(expanded.height, 0.5),
        );

        await tester.tap(find.byKey(const Key('history_calendar_toggle')));
        await tester.pumpAndSettle();
        expect(_headerRect(tester), collapsed);
        expect(controller.offset, 125);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('过往移除月份条，日历从当前可见图墙月份打开', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(PastScreen(apiClient: _client())));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gallery_month_picker')), findsNothing);
    expect(find.byKey(const Key('gallery_previous_month')), findsNothing);
    expect(find.byKey(const Key('gallery_next_month')), findsNothing);

    final month = find.text('2024年3月').last;
    expect(
      tester.getRect(month).top,
      lessThanOrEqualTo(_headerRect(tester).bottom + 12),
    );

    await tester.tap(find.byKey(const Key('history_calendar_toggle')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('history_calendar')),
        matching: find.text('2024年3月'),
      ),
      findsOneWidget,
    );
    expect(find.text('记录标记暂未加载，仍可选择日期'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('画廊控制器继续分页，刷新保留旧图墙及滚动位置', (tester) async {
    final requests = <Uri>[];
    final pending = Completer<http.Response>();
    await tester.pumpWidget(
      _app(
        PastScreen(
          apiClient: _client(
            requests: requests,
            paginate: true,
            galleryRefresh: pending,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    await tester.drag(
      find.byType(CustomScrollView),
      Offset(0, -controller.position.maxScrollExtent),
    );
    await tester.pumpAndSettle();
    expect(
      requests
          .where((uri) => uri.path == '/api/v1/history/gallery')
          .map((uri) => uri.queryParameters['cursor']),
      [null, '2024-02'],
    );
    final offset = controller.offset;
    final future = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    expect(find.text('2024年2月'), findsWidgets);
    expect(
      find.byType(LinearProgressIndicator, skipOffstage: false),
      findsNothing,
    );
    pending.complete(
      _json({
        'months': [_month(3), _month(2)],
        'nextCursor': null,
      }),
    );
    await future;
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(offset, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('顶部回忆先加载时，日历仍从可见相册月份打开', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = Completer<http.Response>();
    await tester.pumpWidget(
      _app(
        PastScreen(
          apiClient: _client(todayMemory: true, initialGallery: pending),
        ),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete(
      _json({
        'months': [_month(3)],
        'nextCursor': null,
      }),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('2024年3月').last).top,
      greaterThan(_headerRect(tester).bottom + 40),
    );
    await tester.tap(find.byKey(const Key('history_calendar_toggle')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('history_calendar')),
        matching: find.text('2024年3月'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  for (final past in [false, true]) {
    testWidgets('${past ? '过往' : '今天'}保留下拉圆形反馈', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final pending = Completer<http.Response>();
      final client = _client(
        galleryRefresh: past ? pending : null,
        diaryRefresh: past ? null : pending,
      );
      await tester.pumpWidget(
        _app(
          past
              ? PastScreen(apiClient: client)
              : HomeScreen(
                  apiClient: client,
                  habitSettingsRepo: HabitSettingsRepository(
                    storage: _MemoryStorage(),
                  ),
                ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(past ? CustomScrollView : ListView).first,
        const Offset(0, 400),
      );
      await tester.pump();
      try {
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      } finally {
        await _finishHeaderRefresh(tester, pending, past, null);
      }
    });
  }

  for (final past in [false, true]) {
    for (final switchTab in [false, true]) {
      for (final dark in [false, true]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets(
            '刷新无横线：${past ? '过往' : '今天'} '
            '${switchTab ? '切回' : '刷新'} dark=$dark scale=$scale',
            (tester) => _expectRefreshWithoutStripe(
              tester,
              past: past,
              switchTab: switchTab,
              dark: dark,
              scale: scale,
            ),
          );
        }
      }
    }
  }
}

Future<void> _mountHabits(
  WidgetTester tester, {
  bool dark = false,
  bool highContrast = false,
  double textScale = 1,
  Completer<http.Response>? initialStats,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final storage = _MemoryStorage();
  await tester.pumpWidget(
    _app(
      HabitStatsScreen(
        apiClient: _client(initialStats: initialStats),
        habitSettingsRepo: HabitSettingsRepository(storage: storage),
        trendCacheRepo: HabitTrendCacheRepository(storage: storage),
      ),
      dark: dark,
      highContrast: highContrast,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectPaperSeam(WidgetTester tester, {required bool dark}) async {
  final bottom = _headerRect(tester).bottom;
  final pixels = <Color>[];
  for (final x in [4.0, 160.0, 316.0]) {
    pixels.add(await _pixelAt(tester, Offset(x, bottom - 1)));
    pixels.add(await _pixelAt(tester, Offset(x, bottom + 1)));
  }
  final paper = (dark ? AppTheme.dark : AppTheme.light).scaffoldBackgroundColor;
  expect(pixels, List.filled(6, paper));
}

Future<double> _verticalContrast(
  WidgetTester tester,
  double x,
  double top,
  int height,
) async {
  var previous = await _pixelAt(tester, Offset(x, top));
  var contrast = 0.0;
  for (var y = 1; y <= height; y++) {
    final current = await _pixelAt(tester, Offset(x, top + y));
    contrast +=
        (current.r - previous.r).abs() +
        (current.g - previous.g).abs() +
        (current.b - previous.b).abs();
    previous = current;
  }
  return contrast;
}

void _expectGlassStrength(
  WidgetTester tester,
  ThemeData theme,
  double strength,
  bool highContrast,
) {
  final header = find.byType(FloraGlassHeader);
  expect(tester.widget<FloraGlassHeader>(header).glassStrength, strength);
  final filter = find.descendant(
    of: header,
    matching: find.byType(BackdropFilter),
  );
  if (highContrast || strength == 0) {
    expect(filter, findsNothing);
  } else {
    expect(
      tester.widget<BackdropFilter>(filter).filter,
      ui.ImageFilter.blur(sigmaX: 18 * strength, sigmaY: 18 * strength),
    );
  }
  final decoration =
      tester
              .widget<DecoratedBox>(
                find
                    .descendant(of: header, matching: find.byType(DecoratedBox))
                    .first,
              )
              .decoration
          as BoxDecoration;
  final opacity = theme.brightness == Brightness.dark ? 0.60 : 0.42;
  expect(
    decoration.color,
    theme.scaffoldBackgroundColor.withValues(
      alpha: highContrast ? 1 : ui.lerpDouble(1, opacity, strength)!,
    ),
  );
}

Future<List<int>> _titleInk(WidgetTester tester, Color color) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('scroll_header_capture')),
  );
  final rect = tester.getRect(find.text('习惯趋势'));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final offsets = <int>[];
      for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
        for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
          final offset = (y * image.width + x) * 4;
          if (bytes.getUint8(offset) == (color.r * 255).round() &&
              bytes.getUint8(offset + 1) == (color.g * 255).round() &&
              bytes.getUint8(offset + 2) == (color.b * 255).round()) {
            offsets.add(offset);
          }
        }
      }
      return offsets;
    } finally {
      image.dispose();
    }
  }))!;
}

Widget _app(
  Widget home, {
  bool dark = false,
  bool highContrast = false,
  double textScale = 1.3,
}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      size: const Size(320, 720),
      padding: const EdgeInsets.only(top: 24),
      textScaler: TextScaler.linear(textScale),
      highContrast: highContrast,
    ),
    child: RepaintBoundary(
      key: const Key('scroll_header_capture'),
      child: child!,
    ),
  ),
  home: home,
);

Widget _compactHomeApp(DateTime date, {required double textScale}) =>
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 24),
          size: const Size(320, 720),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: FloraAppBar(
            toolbarHeight: CompactDiaryDateTitle.preferredToolbarHeight(
              context,
              date,
            ),
            centerTitle: false,
            title: CompactDiaryDateTitle(date: date),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const FloraIcon(FloraIcons.settings),
              ),
            ],
          ),
        ),
      ),
    );

Future<Color> _pixelAt(WidgetTester tester, Offset point) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('scroll_header_capture')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    final color = Color.fromARGB(
      255,
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
    image.dispose();
    return color;
  }))!;
}

Rect _headerRect(WidgetTester tester) {
  final header = tester.widget<PinnedHeaderSliver>(
    find.byType(PinnedHeaderSliver),
  );
  return tester.getRect(find.byWidget(header.child!));
}

void _expectHeaderPaintedLast(WidgetTester tester) {
  final viewport = tester.renderObject<RenderViewport>(find.byType(Viewport));
  expect(viewport.paintOrder, SliverPaintOrder.firstIsTop);
}

ApiClient _client({
  List<Uri>? requests,
  bool paginate = false,
  Completer<http.Response>? galleryRefresh,
  Completer<http.Response>? initialGallery,
  Completer<http.Response>? initialStats,
  bool todayMemory = false,
  Completer<http.Response>? diaryRefresh,
}) {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(30, 120, 230));
  final imageBytes = img.encodePng(image);
  var galleryRequests = 0;
  var statsRequests = 0;
  var diaryRequests = 0;
  final client = ApiClient(
    ApiConfig(baseUrl: 'https://test.local', token: 'test'),
    httpClient: _HeaderHttpClient((request) async {
      expect(request.method, 'GET');
      requests?.add(request.url);
      if (request.url.path.startsWith('/api/v1/diary/image/render/')) {
        return http.Response.bytes(
          imageBytes,
          200,
          headers: {'content-type': 'image/png'},
        );
      }
      if (request.url.path == '/api/v1/history/gallery') {
        galleryRequests++;
        final cursor = request.url.queryParameters['cursor'];
        if (galleryRequests == 1 && initialGallery != null) {
          return initialGallery.future;
        }
        if (galleryRequests > 1 && cursor == null && galleryRefresh != null) {
          return galleryRefresh.future;
        }
        if (paginate) {
          return _json({
            'months': [_month(cursor == null ? 3 : 2)],
            'nextCursor': cursor == null ? '2024-02' : null,
          });
        }
        return _json({
          'months': [_month(3), _month(2)],
          'nextCursor': null,
        });
      }
      if (request.url.path == '/api/v1/stats/habit') {
        statsRequests++;
        if (statsRequests == 1 && initialStats != null) {
          return initialStats.future;
        }
        return _json([
          {
            'date': request.url.queryParameters['from'],
            'hasDiary': true,
            'water': 0,
            'steps': 0,
            'reading': true,
            'readingMinutes': 30,
            'language': false,
            'supplements': false,
            'customCheckboxes': {},
            'customDurations': {},
          },
        ]);
      }
      if (diaryRefresh != null &&
          request.url.path.startsWith('/api/v1/diary/')) {
        diaryRequests++;
        if (diaryRequests > 1) return diaryRefresh.future;
        return _diaryResponse();
      }
      if (todayMemory && request.url.path.startsWith('/api/v1/diary/')) {
        return _json({
          'date': request.url.path.split('/').last,
          'raw': '## 影像记录\n![[photo-1.png]]',
          'sections': {},
        });
      }
      if (request.url.path.startsWith('/api/v1/history/')) {
        final parts = request.url.pathSegments;
        return _json({
          'year': int.parse(parts[parts.length - 2]),
          'month': int.parse(parts.last),
          'diaries': [],
        });
      }
      return _json({'diaries': []});
    }),
  );
  addTearDown(client.dispose);
  return client;
}

Map<String, Object> _month(int month) => {
  'year': 2024,
  'month': month,
  'totalDays': 24,
  'totalImages': 24,
  'days': [
    for (var day = 1; day <= 24; day++)
      {
        'date':
            '2024-${month.toString().padLeft(2, '0')}-'
            '${day.toString().padLeft(2, '0')}',
        'images': ['photo-$day.png'],
        'hasContent': true,
      },
  ],
};

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _MemoryStorage implements HabitSettingsStorage, HabitTrendCacheStorage {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _HeaderHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest) respond;

  _HeaderHttpClient(this.respond);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await respond(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

http.Response _diaryResponse() => _json({
  'date': ApiClient.formatDate(DateTime.now()),
  'raw':
      '## 随手记\n${List.generate(20, (index) => '- **10:${index.toString().padLeft(2, '0')}** 测试正文 $index').join('\n')}',
  'sections': {},
});

Future<void> _expectRefreshWithoutStripe(
  WidgetTester tester, {
  required bool past,
  required bool switchTab,
  required bool dark,
  required double scale,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  FlutterSecureStorage.setMockInitialValues({});
  final pending = Completer<http.Response>();
  final client = _client(
    galleryRefresh: past ? pending : null,
    diaryRefresh: past ? null : pending,
  );
  final repo = HabitSettingsRepository(storage: _MemoryStorage());
  Widget app(bool active) => _app(
    past
        ? PastScreen(apiClient: client, active: active)
        : HomeScreen(
            apiClient: client,
            habitSettingsRepo: repo,
            active: active,
          ),
    dark: dark,
    textScale: scale,
  );
  await tester.pumpWidget(app(true));
  await tester.pumpAndSettle();
  final header = past
      ? _headerRect(tester)
      : tester.getRect(find.byType(FloraAppBar));
  Future<void>? refreshing;
  if (switchTab) {
    await tester.pumpWidget(app(false));
    await tester.pumpWidget(app(true));
  } else {
    refreshing = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
  }
  await tester.pump();
  await tester.idle();
  try {
    await _expectRefreshFrames(tester, header: header, dark: dark);
    expect(
      past
          ? find.text('2024年3月')
          : find.textContaining('测试正文', findRichText: true),
      findsWidgets,
    );
  } finally {
    await _finishHeaderRefresh(tester, pending, past, refreshing);
  }
}

Future<void> _finishHeaderRefresh(
  WidgetTester tester,
  Completer<http.Response> pending,
  bool past,
  Future<void>? refreshing,
) async {
  pending.complete(
    past
        ? _json({
            'months': [_month(3), _month(2)],
            'nextCursor': null,
          })
        : _diaryResponse(),
  );
  await tester.pumpAndSettle();
  if (refreshing != null) await refreshing;
  expect(find.byType(LinearProgressIndicator), findsNothing);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
}

Future<void> _expectRefreshFrames(
  WidgetTester tester, {
  required Rect header,
  required bool dark,
}) async {
  final theme = dark ? AppTheme.dark : AppTheme.light;
  for (final milliseconds in [16, 80, 160]) {
    await tester.pump(Duration(milliseconds: milliseconds));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    for (final x in [20.0, 80.0, 160.0, 240.0, 300.0]) {
      expect(
        await _pixelAt(tester, Offset(x, header.bottom + 0.5)),
        theme.scaffoldBackgroundColor,
        reason: '刷新中间帧的 Banner 下沿必须保留纸色，不能出现条带',
      );
    }
  }
}
