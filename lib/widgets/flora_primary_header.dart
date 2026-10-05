import 'package:flutter/material.dart';

/// 三个主页面共用的紧凑 Banner 节奏。
class FloraPrimaryHeader extends StatelessWidget {
  static const double contentHeight = 64;
  static const double controlHeight = 48;

  final Widget child;
  final Widget? expandedChild;

  const FloraPrimaryHeader({
    super.key,
    required this.child,
    this.expandedChild,
  });

  @override
  Widget build(BuildContext context) {
    final hasExpandedChild = expandedChild != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        hasExpandedChild ? 12 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: controlHeight),
            child: child,
          ),
          if (hasExpandedChild) ...[const SizedBox(height: 16), expandedChild!],
        ],
      ),
    );
  }
}
