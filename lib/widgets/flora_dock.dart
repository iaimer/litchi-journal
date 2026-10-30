import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'flora_glass.dart';
import 'flora_icon.dart';

class FloraDockScope extends InheritedWidget {
  final double clearance;
  final double fabBottom;
  final int menuDismissRevision;

  const FloraDockScope({
    super.key,
    required this.clearance,
    required this.fabBottom,
    this.menuDismissRevision = 0,
    required super.child,
  });

  static FloraDockScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FloraDockScope>();

  @override
  bool updateShouldNotify(FloraDockScope oldWidget) =>
      clearance != oldWidget.clearance ||
      fabBottom != oldWidget.fabBottom ||
      menuDismissRevision != oldWidget.menuDismissRevision;
}

class FloraDockFabLocation extends FloatingActionButtonLocation {
  final double bottom;
  const FloraDockFabLocation(this.bottom);

  // 相同位置的重建不能触发 Scaffold 默认的 FAB 移动动画。
  @override
  bool operator ==(Object other) =>
      other is FloraDockFabLocation && other.bottom == bottom;

  @override
  int get hashCode => bottom.hashCode;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) => Offset(
    geometry.scaffoldSize.width - geometry.floatingActionButtonSize.width - 16,
    geometry.scaffoldSize.height -
        geometry.floatingActionButtonSize.height -
        bottom,
  );
}

class FloraDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final List<GlobalKey>? iconKeys;

  const FloraDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.height,
    this.iconKeys,
  });

  static double heightFor(BuildContext context) =>
      math.max(64, 48 + MediaQuery.textScalerOf(context).scale(12) + 4);

  @override
  Widget build(BuildContext context) => FloraGlassHeader(
    child: SafeArea(
      top: false,
      child: Theme(
        data: Theme.of(context).copyWith(splashFactory: NoSplash.splashFactory),
        child: NavigationBar(
          height: height,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: 0,
          animationDuration: FloraMotion.fastFor(MediaQuery.of(context)),
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          destinations: [
            NavigationDestination(
              icon: _DockIcon(FloraIcons.diary, key: iconKeys?[0]),
              selectedIcon: _DockIcon(FloraIcons.dockDiarySelected),
              label: '今天',
            ),
            NavigationDestination(
              icon: _DockIcon(FloraIcons.history, key: iconKeys?[1]),
              selectedIcon: _DockIcon(FloraIcons.dockHistorySelected),
              label: '过往',
            ),
            NavigationDestination(
              icon: _DockIcon(FloraIcons.habits, key: iconKeys?[2]),
              selectedIcon: _DockIcon(FloraIcons.dockHabitsSelected),
              label: '习惯',
            ),
            NavigationDestination(
              icon: _DockIcon(FloraIcons.settings, key: iconKeys?[3]),
              selectedIcon: _DockIcon(FloraIcons.dockSettingsSelected),
              label: '设置',
            ),
          ],
        ),
      ),
    ),
  );
}

class _DockIcon extends StatelessWidget {
  final String name;

  const _DockIcon(this.name, {super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    // 焦点独立于页面选中态；用短线代替已移除的椭圆覆盖层。
    decoration: BoxDecoration(
      border: Border(
        bottom: Focus.of(context).hasFocus
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
    ),
    child: FloraIcon(name, size: 24),
  );
}
