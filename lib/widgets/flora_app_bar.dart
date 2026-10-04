import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'flora_glass.dart';
import 'flora_icon.dart';
import 'flora_origin.dart';

/// 阅读页可启用整条玻璃背景，其他路由保留局部操作玻璃。
class FloraAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final double? toolbarHeight;
  final bool? centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? surfaceTintColor;
  final Color? shadowColor;
  final double? elevation;
  final double? scrolledUnderElevation;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool glassBackground;

  const FloraAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.toolbarHeight,
    this.centerTitle,
    this.backgroundColor,
    this.foregroundColor,
    this.surfaceTintColor,
    this.shadowColor,
    this.elevation,
    this.scrolledUnderElevation,
    this.titleTextStyle,
    this.systemOverlayStyle,
    this.glassBackground = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight);

  Widget _action(Widget action) {
    if (action is! IconButton) return action;
    return glassBackground
        ? FloraOriginIconButton(button: action)
        : FloraGlassIconButton(button: action, tint: _tint);
  }

  Color? get _tint => backgroundColor == Colors.black ? Colors.black : null;

  Widget? _buildLeading(Widget? leading) {
    if (leading == null) return null;
    if (leading is IconButton &&
        leading.icon is FloraIcon &&
        (leading.icon as FloraIcon).name == FloraIcons.back) {
      // 只移除返回按钮的玻璃底座，热区与箭头中心保持不变。
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Center(
          child: SizedBox.square(
            dimension: 48,
            child: FloraOriginIconButton(button: leading),
          ),
        ),
      );
    }
    return _action(leading);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final back =
        leading ??
        (canPop
            ? IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const FloraIcon(FloraIcons.back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null);
    return AppBar(
      title: title,
      leading: _buildLeading(back),
      automaticallyImplyLeading: false,
      actions: actions?.map(_action).toList(),
      toolbarHeight: toolbarHeight,
      centerTitle: centerTitle,
      backgroundColor: glassBackground ? Colors.transparent : backgroundColor,
      flexibleSpace: glassBackground
          ? const FloraGlassHeader(child: SizedBox.expand())
          : null,
      foregroundColor: foregroundColor,
      surfaceTintColor: surfaceTintColor ?? Colors.transparent,
      shadowColor: shadowColor,
      elevation: elevation ?? 0,
      scrolledUnderElevation: scrolledUnderElevation ?? 0,
      titleTextStyle: titleTextStyle,
      systemOverlayStyle:
          systemOverlayStyle ??
          (glassBackground
              ? SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness:
                      Theme.of(context).brightness == Brightness.dark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: Theme.of(context).brightness,
                )
              : null),
    );
  }
}
