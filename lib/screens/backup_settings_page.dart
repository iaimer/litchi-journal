import 'dart:async';

import 'package:flutter/material.dart';

import '../models/backup_settings.dart';
import '../services/api_client.dart';
import '../widgets/flora_page_scaffold.dart';
import 'webdav_settings_page.dart';

/// 数据与备份设置总览。
class BackupSettingsPage extends StatefulWidget {
  final ApiClient apiClient;

  const BackupSettingsPage({super.key, required this.apiClient});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  BackupSettingsSnapshot _settings = BackupSettingsSnapshot.defaults();
  bool _loading = true;
  bool _saving = false;
  bool _runningAction = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _settings.status;

    return FloraPageScaffold(
      title: '数据与备份',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      body: ListView(
        key: const ValueKey('backup_settings_page'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) _buildErrorBanner(theme, _error!),
          if (status.state == BackupState.success &&
              status.lastSuccessAt != null)
            _buildSuccessBanner(theme, status),
          _buildSectionHeader(theme, '备份状态'),
          _buildGroup([
            _BackupRow(
              label: '最近备份',
              value: _formatDateTime(status.lastSuccessAt) ?? '尚未备份',
              icon: Icons.history_rounded,
            ),
            _BackupRow(
              label: '状态',
              value: _statusLabel(status),
              icon: Icons.cloud_done_rounded,
              trailing: _statusPill(theme, status),
            ),
            _BackupRow(
              label: '下次备份',
              value: _settings.enabled
                  ? (_formatDateTime(status.nextRunAt) ?? '计算中')
                  : '自动备份已关闭',
              icon: Icons.schedule_rounded,
            ),
          ]),
          _buildSectionHeader(theme, '自动备份'),
          _buildGroup([
            _BackupRow(
              label: '自动备份',
              value: _settings.enabled ? '已开启' : '已关闭',
              icon: Icons.autorenew_rounded,
              trailing: Switch(
                key: const ValueKey('backup_auto_switch'),
                value: _settings.enabled,
                onChanged: _saving ? null : _toggleEnabled,
              ),
            ),
            _BackupRow(label: '备份频率', value: '每周', icon: Icons.repeat_rounded),
            _BackupRow(
              label: '备份时间',
              value:
                  '${backupWeekdayNames[_settings.weekday]} ${_settings.time}',
              icon: Icons.access_time_rounded,
              onTap: _saving ? null : _pickSchedule,
            ),
            _BackupRow(
              label: '留存规则',
              value:
                  '近 ${_settings.recentWeeks} 周 + ${_settings.monthlyMonths} 个月',
              icon: Icons.layers_rounded,
            ),
          ]),
          _buildSectionHeader(theme, '备份方式'),
          _buildGroup([
            _BackupRow(
              key: const ValueKey('backup_webdav_settings'),
              label: 'WebDAV 设置',
              value: _settings.passwordConfigured ? '已配置' : '未配置',
              icon: Icons.cloud_upload_rounded,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _saving
                  ? null
                  : () async {
                      final saved = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => WebDavSettingsPage(
                            apiClient: widget.apiClient,
                            initialSettings: _settings,
                          ),
                        ),
                      );
                      if (saved == true && mounted) await _load();
                    },
            ),
            _BackupRow(
              label: '立即备份到 WebDAV',
              value: _runningAction ? '备份进行中' : '手动执行',
              icon: Icons.upload_rounded,
              trailing: _runningAction
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: _runningAction ? null : _startManualBackup,
            ),
            _BackupRow(
              key: const ValueKey('backup_export_phone'),
              label: '导出到手机',
              value: '保存 ZIP 到下载目录',
              icon: Icons.download_rounded,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _runningAction ? null : _exportToPhone,
            ),
          ]),
          if (status.state == BackupState.failed &&
              status.lastError != null) ...[
            const SizedBox(height: 12),
            Text(
              status.lastError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _load() async {
    try {
      final settings = await widget.apiClient.fetchBackupSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _safeError(error, '备份设置暂时不可用');
      });
    }
  }

  Future<void> _toggleEnabled(bool enabled) async {
    if (enabled && !_settings.passwordConfigured) {
      _showMessage('请先完成 WebDAV 配置，再开启自动备份');
      return;
    }
    final previous = _settings;
    setState(() {
      _saving = true;
      _settings = _settings.copyWith(enabled: enabled);
    });
    try {
      final saved = await widget.apiClient.updateBackupSettings(_settings);
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _settings = previous;
        _saving = false;
      });
      _showMessage(_safeError(error, '保存自动备份设置失败'));
    }
  }

  Future<void> _pickSchedule() async {
    final weekday = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择备份星期'),
        children: [
          for (var index = 0; index < backupWeekdayNames.length; index++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(index),
              child: Text(backupWeekdayNames[index]),
            ),
        ],
      ),
    );
    if (!mounted || weekday == null) return;
    final currentParts = _settings.time.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(currentParts.first) ?? 3,
      minute: int.tryParse(currentParts.last) ?? 0,
    );
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (!mounted || time == null) return;
    final updated = _settings.copyWith(
      weekday: weekday,
      time:
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
    );
    await _save(updated);
  }

  Future<void> _save(BackupSettingsSnapshot updated) async {
    final previous = _settings;
    setState(() {
      _saving = true;
      _settings = updated;
    });
    try {
      final saved = await widget.apiClient.updateBackupSettings(updated);
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _settings = previous;
        _saving = false;
      });
      _showMessage(_safeError(error, '保存备份设置失败'));
    }
  }

  Future<void> _startManualBackup() async {
    if (!_settings.passwordConfigured) {
      _showMessage('请先完成 WebDAV 配置');
      return;
    }
    setState(() => _runningAction = true);
    try {
      await widget.apiClient.startWebDavBackup();
      if (mounted) {
        setState(() {
          _settings = _settings.copyWith(
            status: _settings.status.copyWith(state: BackupState.running),
          );
        });
      }
      await _pollBackupStatus();
    } catch (error) {
      if (mounted) _showMessage(_safeError(error, '启动备份失败'));
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _pollBackupStatus() async {
    for (var attempt = 0; attempt < 120; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      try {
        final latest = await widget.apiClient.fetchBackupSettings();
        if (!mounted) return;
        setState(() => _settings = latest);
        if (latest.status.state != BackupState.running) {
          if (latest.status.state == BackupState.success) {
            _showMessage('备份完成');
          } else if (latest.status.lastError != null) {
            _showMessage(latest.status.lastError!);
          }
          return;
        }
      } catch (_) {
        // 状态查询失败不打断服务端任务，下一轮继续查询。
      }
    }
    if (mounted) _showMessage('备份仍在后台执行，可稍后返回查看状态');
  }

  Future<void> _exportToPhone() async {
    setState(() => _runningAction = true);
    try {
      await widget.apiClient.enqueueBackupDownload();
      if (mounted) _showMessage('已加入下载队列，可在系统通知中查看进度');
    } catch (error) {
      if (mounted) _showMessage(_safeError(error, '无法导出备份'));
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(height: 1, indent: 56, endIndent: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme, String message) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }

  Widget _buildSuccessBanner(ThemeData theme, BackupStatus status) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: theme.colorScheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '备份完成 · ${_formatDateTime(status.lastSuccessAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(ThemeData theme, BackupStatus status) {
    final running = status.state == BackupState.running;
    final failed = status.state == BackupState.failed;
    final color = failed
        ? theme.colorScheme.error
        : running
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }

  String _statusLabel(BackupStatus status) {
    return switch (status.state) {
      BackupState.running => status.phase ?? '进行中',
      BackupState.success => '已完成',
      BackupState.failed => '失败',
      BackupState.idle => '未执行',
    };
  }

  String? _formatDateTime(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    return '${local.month}月${local.day}日 ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _safeError(Object error, String fallback) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    if (error is UnsupportedError) return error.message ?? fallback;
    return fallback;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BackupRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _BackupRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
    return SizedBox(
      height: 68,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

extension on BackupStatus {
  BackupStatus copyWith({
    BackupState? state,
    String? phase,
    DateTime? lastAttemptAt,
    DateTime? lastSuccessAt,
    DateTime? nextRunAt,
    String? lastFileName,
    int? lastSizeBytes,
    String? lastSha256,
    String? lastError,
  }) {
    return BackupStatus(
      state: state ?? this.state,
      phase: phase ?? this.phase,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      lastFileName: lastFileName ?? this.lastFileName,
      lastSizeBytes: lastSizeBytes ?? this.lastSizeBytes,
      lastSha256: lastSha256 ?? this.lastSha256,
      lastError: lastError ?? this.lastError,
    );
  }
}
