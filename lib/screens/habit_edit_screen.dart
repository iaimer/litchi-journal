import 'package:flutter/material.dart';

import '../widgets/flora_icon.dart';

import '../models/habit_settings.dart';
import '../models/habit_visual_config.dart';
import '../services/habit_settings_repository.dart';
import '../services/habit_stats_cache_repository.dart';
import '../services/habit_stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/habit_icon.dart';
import '../widgets/flora_page_scaffold.dart';

/// 习惯编辑页。
///
/// 编辑单个习惯的显示名称、图标、颜色和状态。
class HabitEditScreen extends StatefulWidget {
  final String habitKey;

  /// 为 true 时进入新增模式：key 为新生成的 custom_xxx，初始值使用默认。
  final bool isCreateMode;

  const HabitEditScreen({super.key, required this.habitKey, this.isCreateMode = false});

  @override
  State<HabitEditScreen> createState() => _HabitEditScreenState();
}

class _HabitEditScreenState extends State<HabitEditScreen> {
  final _repo = HabitSettingsRepository();
  final _nameController = TextEditingController();

  late HabitSettings _settings;
  late String _displayName;
  late String _icon;
  late int _colorArgb;
  late bool _active;
  bool _saving = false;
  bool _loaded = false;

  /// 图标候选，对应 Flora Icon System 素材清单的习惯默认和候选图标。
  static const _iconCandidates = [
    FloraIcons.habitWater,
    FloraIcons.habitWalk,
    FloraIcons.candidateRun,
    FloraIcons.habitRead,
    FloraIcons.candidateBooks,
    FloraIcons.habitLanguage,
    FloraIcons.chatFeedback,
    FloraIcons.habitPill,
    FloraIcons.candidateSprout,
    FloraIcons.candidateStar,
    FloraIcons.candidateSun,
    FloraIcons.candidateMoon,
    FloraIcons.candidateMeditate,
    FloraIcons.candidateLift,
    FloraIcons.candidateApple,
  ];

  /// 颜色候选（柔和色）
  static final _colorCandidates = <_ColorOption>[
    _ColorOption('蓝色', const Color(0xFF6BAED6)),
    _ColorOption('橙色', const Color(0xFFE8A87C)),
    _ColorOption('绿色', const Color(0xFF6B8E6B)),
    _ColorOption('紫色', const Color(0xFF9B8EC4)),
    _ColorOption('粉色', const Color(0xFFE8A0B0)),
    _ColorOption('棕色', const Color(0xFFC49B8C)),
    _ColorOption('灰色', const Color(0xFF8A8278)),
  ];

  HabitVisualConfig get _defaultConfig => HabitVisualConfig.of(widget.habitKey);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repo.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _displayName = settings.displayNameFor(widget.habitKey);
      _icon = settings.iconFor(widget.habitKey);
      _colorArgb = settings.colorFor(widget.habitKey);
      _active = settings.isActive(widget.habitKey);
      _nameController.text = widget.isCreateMode ? '' : _displayName;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('名称不能为空')));
      return;
    }
    if (trimmed.length > 12) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('名称最长 12 个字')));
      return;
    }

    // 重名校验：新建时不能与任何已有习惯同名，编辑时不能与其它习惯同名
    final allNames = _settings.allDisplayNames(
      excludeKey: widget.isCreateMode ? null : widget.habitKey,
    );
    if (allNames.contains(trimmed)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已存在同名习惯')));
      return;
    }

    setState(() => _saving = true);
    try {
      final HabitSettings updated;
      if (widget.isCreateMode) {
        updated = _saveCreate(trimmed);
      } else {
        updated = _settings.updateHabit(
          key: widget.habitKey,
          active: _active,
          displayName: trimmed,
          icon: _icon,
          color: _colorArgb,
        );
      }

      // 自定义习惯维护 aliases：新建初始化，重命名追加（不重复）
      final saved = widget.habitKey.startsWith('custom_')
          ? updated.appendHabitAlias(key: widget.habitKey, newName: trimmed)
          : updated;

      await _repo.save(saved);

      // 清除习惯统计缓存，确保统计页使用最新视觉配置
      await HabitStatsCacheRepository().clear();
      HabitStatsService.clearDayCache();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存')));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  HabitSettings _saveCreate(String name) {
    final newExtraHabits = Map<String, String>.from(_settings.extraHabits);
    newExtraHabits[widget.habitKey] = name;

    final newStatusMap = Map<String, bool>.from(_settings.statusMap);
    newStatusMap[widget.habitKey] = _active;

    var updated = _settings.copyWith(
      statusMap: newStatusMap,
      extraHabits: newExtraHabits,
      displayNameMap: Map<String, String>.from(_settings.displayNameMap),
      iconMap: Map<String, String>.from(_settings.iconMap),
      colorMap: Map<String, int>.from(_settings.colorMap),
    );

    final defaultIcon = HabitVisualConfig.of(widget.habitKey).icon;
    if (_icon != defaultIcon) {
      final newIcon = Map<String, String>.from(updated.iconMap);
      newIcon[widget.habitKey] = _icon;
      updated = updated.copyWith(iconMap: newIcon);
    }

    final defaultColor =
        HabitVisualConfig.of(widget.habitKey).color.toARGB32();
    if (_colorArgb != defaultColor) {
      final newColor = Map<String, int>.from(updated.colorMap);
      newColor[widget.habitKey] = _colorArgb;
      updated = updated.copyWith(colorMap: newColor);
    }

    return updated;
  }

  String get _defaultDisplayName =>
      _settings.extraHabits[widget.habitKey] ?? _defaultConfig.displayName;

  void _resetToDefault() {
    final name = _defaultDisplayName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认'),
        content: Text('将「$name」恢复为默认名称、图标、颜色和启用状态？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _displayName = name;
                _icon = _defaultConfig.icon;
                _colorArgb = _defaultConfig.color.toARGB32();
                _active = true;
                _nameController.text = name;
              });
            },
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
  }

  /// 统计中文字符长度（一个中文=1，一个英文/数字=0.5，上限 12 中文字符≈24 英文字符）
  /// 简化处理：按字符数计算
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_loaded) {
      return const FloraPageScaffold(
        title: '编辑习惯',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FloraPageScaffold(
      title: widget.isCreateMode ? '新增习惯' : '编辑习惯',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. 显示名称 ──
            _buildLabel(theme, '显示名称'),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: '输入习惯名称',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              maxLength: 24,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
            ),

            const SizedBox(height: 20),

            // ── 2. 图标选择 ──
            _buildLabel(theme, '图标'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _iconCandidates.map((icon) {
                final selected = _icon == icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = icon),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppColors.primary.withAlpha(30)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.dividerColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: HabitIcon(
                        icon,
                        size: 22,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── 3. 颜色选择 ──
            _buildLabel(theme, '颜色'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: _colorCandidates.map((option) {
                final selected = _colorArgb == option.color.toARGB32();
                return GestureDetector(
                  onTap: () =>
                      setState(() => _colorArgb = option.color.toARGB32()),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: option.color,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: selected ? 3 : 0,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: option.color.withAlpha(80),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: selected
                        ? const FloraIcon(
                            FloraIcons.check,
                            size: 20,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── 4. 状态 ──
            _buildLabel(theme, '状态'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _active ? '启用中' : '已归档',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '归档后，这个习惯会从今天页和习惯统计页隐藏，'
                              '历史记录仍会保留。',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (!widget.isCreateMode)
            // ── 5. 恢复默认 ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetToDefault,
                icon: const FloraIcon(FloraIcons.reset, size: 18),
                label: const Text('恢复默认'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  side: BorderSide(color: theme.dividerColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── 6. 保存按钮 ──
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Text('保存'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _ColorOption {
  final String name;
  final Color color;
  const _ColorOption(this.name, this.color);
}
