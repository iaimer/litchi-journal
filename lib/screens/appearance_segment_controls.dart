part of 'appearance_settings_page.dart';

const _themeModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
const _themeLabels = ['跟随系统', '浅色', '深色'];
const _sizeLabels = ['小', '中', '大'];
const _modeIcons = [
  FloraIcons.appearanceSystem,
  FloraIcons.appearanceLight,
  FloraIcons.appearanceDark,
];

bool _instantAppearanceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    !TickerMode.valuesOf(context).enabled;

/// 两组先按最长的外观标签计算共同高度，保证字号组不会更矮。
class _AppearanceSegmentLayout {
  final TextStyle labelStyle;
  final double faceHeight;
  final bool stackedIcons;

  const _AppearanceSegmentLayout._(
    this.labelStyle,
    this.faceHeight,
    this.stackedIcons,
  );

  factory _AppearanceSegmentLayout(BuildContext context, double width) {
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 14,
      height: 1.5,
      letterSpacing: 0,
      fontWeight: FontWeight.w600,
    );
    Size measure(String label, double maxWidth) => (TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth)).size;
    final cellContentWidth = width / 3 - 16;
    // 单字也放不下时把图标移到格内上方，不能缩小字体或挤进相邻格。
    final stacked = measure('跟', double.infinity).width > cellContentWidth - 20;
    final textWidth = cellContentWidth - (stacked ? 0 : 20);
    final textHeight = _themeLabels
        .map((label) => measure(label, textWidth).height)
        .reduce(math.max);
    final height = math
        .max(40, textHeight + 16 + (stacked ? 20 : 0))
        .ceilToDouble();
    return _AppearanceSegmentLayout._(style, height, stacked);
  }

  ButtonStyle style(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final instant = _instantAppearanceMotion(context);
    final foreground = WidgetStateProperty.resolveWith<Color>(
      (states) => states.contains(WidgetState.selected)
          ? colors.onPrimary
          : colors.onSurfaceVariant,
    );
    return ButtonStyle(
      textStyle: WidgetStateProperty.resolveWith(
        (states) => labelStyle.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
      foregroundColor: foreground,
      iconColor: foreground,
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.surface,
      ),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      // 增高时仍保留小圆角，避免完整胶囊变成椭圆而裁掉端点文字。
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(FloraRadius.md)),
        ),
      ),
      side: WidgetStatePropertyAll(BorderSide(color: colors.outline)),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      animationDuration: instant ? Duration.zero : FloraMotion.fast,
      splashFactory: NoSplash.splashFactory,
    );
  }

  // 原生控件不把 minimumSize 传给各格，以相同内容高度保证上下同高。
  // 内容加 16dp 内边距，再扣除边框外的 8dp 热区，得到实际视觉高度。
  Widget content(Widget child, Key key) => SizedBox(
    key: key,
    height: faceHeight - 8,
    child: Center(child: child),
  );

  // 仅把时长改为零不会结束原生控件的在途补间，重建它以释放旧动画。
  Widget control(BuildContext context, Widget child) => KeyedSubtree(
    key: ValueKey(_instantAppearanceMotion(context)),
    child: child,
  );
}

extension on _AppearanceSettingsPageState {
  Widget _buildModeControl(_AppearanceSegmentLayout layout) => layout.control(
    context,
    Semantics(
      container: true,
      label: '外观模式',
      child: SegmentedButton<ThemeMode>(
        key: const Key('appearance_theme_control'),
        expandedInsets: EdgeInsets.zero,
        showSelectedIcon: false,
        style: layout.style(context),
        segments: [
          for (var i = 0; i < _themeModes.length; i++)
            ButtonSegment(
              value: _themeModes[i],
              label: layout.content(
                _buildModeLabel(i, layout),
                ValueKey('appearance_theme_content_$i'),
              ),
            ),
        ],
        selected: {_controller.themeMode},
        onSelectionChanged: (values) => _select(values.single),
      ),
    ),
  );

  Widget _buildModeLabel(int index, _AppearanceSegmentLayout layout) {
    final icon = FloraIcon(
      _modeIcons[index],
      size: 16,
      key: ValueKey('appearance_theme_icon_$index'),
    );
    final text = Text(
      _themeLabels[index],
      textAlign: TextAlign.center,
      key: ValueKey('appearance_theme_label_$index'),
    );
    if (layout.stackedIcons) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(height: 4), text],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Flexible(child: text),
      ],
    );
  }

  Widget _buildSizeControl(_AppearanceSegmentLayout layout) => layout.control(
    context,
    Semantics(
      container: true,
      label: '阅读字号',
      child: SegmentedButton<int>(
        key: const Key('appearance_reading_size_control'),
        expandedInsets: EdgeInsets.zero,
        showSelectedIcon: false,
        style: layout.style(context),
        segments: [
          for (var i = 0; i < _sizeLabels.length; i++)
            ButtonSegment(
              value: AppearanceSettings.readingFontSizes[i],
              label: layout.content(
                Semantics(
                  label:
                      '${_sizeLabels[i]}，${AppearanceSettings.readingFontSizes[i]}号',
                  excludeSemantics: true,
                  child: Text(
                    _sizeLabels[i],
                    key: ValueKey('appearance_reading_label_$i'),
                  ),
                ),
                ValueKey('appearance_reading_content_$i'),
              ),
            ),
        ],
        selected: {_controller.readingFontSize},
        onSelectionChanged: (values) => _selectReadingSize(values.single),
      ),
    ),
  );
}
