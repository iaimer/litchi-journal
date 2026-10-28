import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/appearance_controller.dart';
import '../services/appearance_settings.dart';
import '../theme/app_theme.dart';
import '../theme/diary_reading_style.dart';
import '../widgets/flora_icon.dart';
import '../widgets/flora_page_scaffold.dart';

part 'appearance_segment_controls.dart';

/// 外观设置页面。主题与日记阅读字号独立设置，选择后自动保存。
class AppearanceSettingsPage extends StatefulWidget {
  final AppearanceController? controller;

  const AppearanceSettingsPage({super.key, this.controller});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  static const _pageInset = 16.0;
  static const _panelInset = 20.0;
  static const _panelBorder = 1.0;

  int _themeRequest = 0;
  int _readingRequest = 0;

  AppearanceController get _controller =>
      widget.controller ?? AppearanceController.instance;

  Future<void> _select(ThemeMode mode) async {
    if (mode == _controller.themeMode) return;
    final request = ++_themeRequest;
    try {
      await _controller.setThemeMode(mode);
    } catch (_) {
      if (mounted && request == _themeRequest) _showSaveError('外观未保存，请重试');
    }
  }

  Future<void> _selectReadingSize(int size) async {
    if (size == _controller.readingFontSize) return;
    final request = ++_readingRequest;
    try {
      await _controller.setReadingFontSize(size);
    } catch (_) {
      if (mounted && request == _readingRequest) _showSaveError('字号未保存，请重试');
    }
  }

  void _showSaveError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => FloraPageScaffold(
    title: '外观',
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildSettings(context),
    ),
  );

  Widget _buildSettings(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _buildContent(
      context,
      _AppearanceSegmentLayout(
        context,
        constraints.maxWidth - 2 * (_pageInset + _panelInset + _panelBorder),
      ),
    ),
  );

  Widget _buildContent(
    BuildContext context,
    _AppearanceSegmentLayout controls,
  ) {
    final theme = Theme.of(context);
    final reading = DiaryReadingStyle(
      fontSize: _controller.readingFontSize.toDouble(),
    );
    return ListView(
      padding: const EdgeInsets.all(_pageInset),
      children: [
        _buildPanel(theme, [
          Text('外观模式', style: reading.heading(theme)),
          const SizedBox(height: 16),
          _buildModeControl(controls),
        ]),
        const SizedBox(height: 16),
        _buildReadingSettings(theme, reading, controls),
        const SizedBox(height: 16),
        Text(
          '字号仍会跟随手机系统字体设置',
          style: reading.metadata(theme).copyWith(height: 1.6),
        ),
      ],
    );
  }

  Widget _buildReadingSettings(
    ThemeData theme,
    DiaryReadingStyle reading,
    _AppearanceSegmentLayout controls,
  ) => _buildPanel(theme, [
    Text('阅读字号', style: reading.heading(theme)),
    const SizedBox(height: 8),
    Text(
      '仅调整日记阅读内容，不改变菜单大小。',
      style: reading.metadata(theme).copyWith(height: 1.6),
    ),
    const SizedBox(height: 16),
    _buildSizeControl(controls),
    const SizedBox(height: 20),
    Divider(height: 1, color: theme.colorScheme.outlineVariant),
    const SizedBox(height: 20),
    _buildPreview(theme, reading),
  ]);

  Widget _buildPanel(ThemeData theme, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(_panelInset),
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,

      borderRadius: BorderRadius.circular(FloraRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _buildPreview(ThemeData theme, DiaryReadingStyle reading) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('正文预览', style: reading.metadata(theme).copyWith(fontSize: 12)),
      const SizedBox(height: 12),
      Text('平凡的一天', style: reading.heading(theme)),
      const SizedBox(height: 12),
      Text(
        '慢慢走，认真看。那些微小而真实的瞬间，都值得被好好记住。',
        key: const Key('appearance_reading_preview'),
        style: reading.body(theme),
      ),
      const SizedBox(height: 12),
      Text('#日常记录', style: reading.metadata(theme)),
    ],
  );
}
