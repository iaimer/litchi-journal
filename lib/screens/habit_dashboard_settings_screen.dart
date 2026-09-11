import 'package:flutter/material.dart';

import '../models/habit_settings.dart';
import '../services/habit_settings_repository.dart';
import '../widgets/flora_page_scaffold.dart';
import '../widgets/habit_icon.dart';

/// 趋势页顶部仪表盘的习惯选择页。
class HabitDashboardSettingsScreen extends StatefulWidget {
  final HabitSettingsRepository? repository;

  const HabitDashboardSettingsScreen({super.key, this.repository});

  @override
  State<HabitDashboardSettingsScreen> createState() =>
      _HabitDashboardSettingsScreenState();
}

class _HabitDashboardSettingsScreenState
    extends State<HabitDashboardSettingsScreen> {
  late final HabitSettingsRepository _repo;
  HabitSettings _settings = HabitSettings.defaults;
  List<String> _selectedKeys = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? HabitSettingsRepository();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repo.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _selectedKeys = settings.validTrendDashboardHabitKeys
          .where(settings.isActive)
          .toList();
      _loading = false;
    });
  }

  void _toggle(String key, bool selected) {
    if (selected && !_selectedKeys.contains(key)) {
      if (_selectedKeys.length >= 4) {
        setState(() => _error = '最多指定 4 项习惯');
        return;
      }
      setState(() {
        _selectedKeys = [..._selectedKeys, key]..sort(_sortByManageableOrder);
        _error = null;
      });
      return;
    }

    setState(() {
      _selectedKeys = _selectedKeys.where((value) => value != key).toList();
      _error = null;
    });
  }

  int _sortByManageableOrder(String left, String right) {
    final order = _settings.manageableKeys;
    return order.indexOf(left).compareTo(order.indexOf(right));
  }

  Future<void> _save() async {
    if (_saving) return;
    final archivedKeys = _settings.validTrendDashboardHabitKeys.where(
      (key) => !_settings.isActive(key),
    );
    final persistedKeys = [..._selectedKeys, ...archivedKeys].take(4).toList();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.save(
        _settings.copyWith(trendDashboardHabitKeys: persistedKeys),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FloraPageScaffold(
      title: '仪表盘显示',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  '最多指定 4 项，不足时按启用习惯顺序自动补齐。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '已指定 ${_selectedKeys.length}/4',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final key in _settings.manageableKeys)
                        if (_settings.isActive(key))
                          CheckboxListTile(
                            value: _selectedKeys.contains(key),
                            onChanged: (value) => _toggle(key, value ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            secondary: HabitIcon(
                              _settings.iconFor(key),
                              size: 22,
                              color: Color(_settings.colorFor(key)),
                            ),
                            title: Text(_settings.displayNameFor(key)),
                          ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    key: const ValueKey('habit_dashboard_settings_error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
