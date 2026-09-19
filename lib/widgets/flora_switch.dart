import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FloraSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const FloraSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  State<FloraSwitch> createState() => _FloraSwitchState();
}

class _FloraSwitchState extends State<FloraSwitch> {
  void _toggle() {
    widget.onChanged?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onChanged != null;
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final inactiveTrack = theme.colorScheme.onSurface.withAlpha(
      theme.brightness == Brightness.dark ? 82 : 52,
    );
    final activeTrack = activeColor.withAlpha(
      theme.brightness == Brightness.dark ? 190 : 165,
    );

    return Semantics(
      button: true,
      toggled: widget.value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _toggle : null,
        child: SizedBox(
          width: 40,
          height: 24,
          child: AnimatedContainer(
            duration: FloraMotion.standardFor(MediaQuery.of(context)),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FloraRadius.pill),
              color: widget.value ? activeTrack : inactiveTrack,
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: FloraMotion.standardFor(MediaQuery.of(context)),
                  curve: Curves.easeOutCubic,
                  top: 2,
                  left: widget.value ? 18 : 2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: enabled
                          ? theme.colorScheme.surface
                          : theme.disabledColor.withAlpha(110),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(
                            theme.brightness == Brightness.dark ? 105 : 76,
                          ),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
