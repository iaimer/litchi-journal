import 'package:flutter/material.dart';

/// 设置页统一页面骨架。
///
/// 仅提供 Scaffold + AppBar + body 底部 SafeArea，
/// 不接管 body 的 padding、ListView、SingleChildScrollView 等业务内容。
class FloraPageScaffold extends StatelessWidget {
  const FloraPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottomNavigationBar,
    this.leading,
  });

  /// AppBar 标题。
  final String title;

  /// 页面主体内容，由调用方完整构建。
  final Widget body;

  /// AppBar 右侧操作按钮。
  final List<Widget>? actions;

  /// Scaffold 底部导航栏，透传。
  final Widget? bottomNavigationBar;

  /// AppBar 左侧按钮。为 null 时系统自动生成默认返回按钮。
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        leading: leading,
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
