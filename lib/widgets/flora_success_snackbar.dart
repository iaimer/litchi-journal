import 'package:flutter/material.dart';

import 'flora_animated_icon.dart';

void showFloraSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Semantics(
            excludeSemantics: true,
            child: FloraAnimatedIcon(
              name: FloraAnimatedIconName.successCheck,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
