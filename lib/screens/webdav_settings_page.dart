import 'package:flutter/material.dart';

import '../models/backup_settings.dart';
import '../services/api_client.dart';
import '../widgets/flora_page_scaffold.dart';

/// WebDAV 独立全屏配置页。
class WebDavSettingsPage extends StatefulWidget {
  final ApiClient apiClient;
  final BackupSettingsSnapshot? initialSettings;

  const WebDavSettingsPage({
    super.key,
    required this.apiClient,
    this.initialSettings,
  });

  @override
  State<WebDavSettingsPage> createState() => _WebDavSettingsPageState();
}

class _WebDavSettingsPageState extends State<WebDavSettingsPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _remotePathController;

  BackupSettingsSnapshot _settings = BackupSettingsSnapshot.defaults();
  bool _loading = false;
  bool _testing = false;
  bool _saving = false;
  bool _testPassed = false;
  String? _error;
  String? _testedSignature;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings ?? BackupSettingsSnapshot.defaults();
    _urlController = TextEditingController(text: _settings.webdavUrl);
    _usernameController = TextEditingController(text: _settings.username);
    _passwordController = TextEditingController();
    _remotePathController = TextEditingController(text: _settings.remotePath);
    for (final controller in [
      _urlController,
      _usernameController,
      _passwordController,
      _remotePathController,
    ]) {
      controller.addListener(_invalidateTest);
    }
    if (widget.initialSettings == null) _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _remotePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FloraPageScaffold(
      title: 'WebDAV 设置',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null) _buildError(theme, _error!),
                _buildSectionTitle(theme, '连接信息'),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: '服务器地址',
                            hintText: 'https://dav.example.com/dav',
                            prefixIcon: Icon(Icons.link_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: '应用密码',
                            hintText: _settings.passwordConfigured
                                ? '已保存，留空表示保持不变'
                                : '请输入 WebDAV 应用密码',
                            prefixIcon: const Icon(Icons.key_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _remotePathController,
                          decoration: const InputDecoration(
                            labelText: '远程目录',
                            hintText: '/荔枝日记备份',
                            prefixIcon: Icon(Icons.folder_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _testing || _saving
                                ? null
                                : _testConnection,
                            icon: _testing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.network_check_rounded),
                            label: Text(_testing ? '测试中…' : '连接测试'),
                          ),
                        ),
                        if (_testPassed) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: theme.colorScheme.tertiary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '连接测试通过，可以保存',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildSectionTitle(theme, '安全提示'),
                Text(
                  '仅支持 HTTPS 和 WebDAV 应用密码。密码不会回显，也不会写入日志。修改任一连接字段后，需要重新测试。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _testing || _saving ? null : _save,
                child: Text(_saving ? '保存中…' : '保存'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await widget.apiClient.fetchBackupSettings();
      if (!mounted) return;
      _settings = settings;
      _urlController.text = settings.webdavUrl;
      _usernameController.text = settings.username;
      _remotePathController.text = settings.remotePath;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _safeError(error, '无法读取 WebDAV 设置');
      });
    }
  }

  Future<void> _testConnection() async {
    final validation = _validateFields();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
      _testPassed = false;
    });
    try {
      await widget.apiClient.testBackupConnection(
        webdavUrl: _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        remotePath: _remotePathController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testPassed = true;
        _testedSignature = _connectionSignature();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testPassed = false;
        _error = _safeError(error, 'WebDAV 连接测试失败');
      });
    }
  }

  Future<void> _save() async {
    final validation = _validateFields();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    final password = _passwordController.text;
    final signature = _connectionSignature();
    if (!_testPassed || _testedSignature != signature) {
      setState(() => _error = '请先完成连接测试，连接字段修改后需要重新测试');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.apiClient.updateBackupSettings(
        _settings.copyWith(
          webdavUrl: _urlController.text.trim(),
          username: _usernameController.text.trim(),
          remotePath: _remotePathController.text.trim(),
        ),
        password: password.isEmpty ? null : password,
      );
      if (!mounted) return;
      _settings = saved;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _safeError(error, '保存 WebDAV 设置失败');
      });
    }
  }

  void _invalidateTest() {
    if (!mounted) return;
    final signature = _connectionSignature();
    if (_testedSignature == signature) return;
    if (_testPassed || _error != null) {
      setState(() {
        _testPassed = false;
        _error = null;
      });
    }
  }

  String _connectionSignature() {
    return '${_urlController.text.trim()}\u0000${_usernameController.text.trim()}\u0000${_passwordController.text}\u0000${_remotePathController.text.trim()}';
  }

  String? _validateFields() {
    final url = Uri.tryParse(_urlController.text.trim());
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      return '请输入 HTTPS WebDAV 地址';
    }
    if (url.userInfo.isNotEmpty) return '地址不能包含用户名或密码';
    if (_usernameController.text.trim().isEmpty) return '请输入用户名';
    if (_settings.passwordConfigured && _passwordController.text.isEmpty) {
      // 留空表示沿用服务端已保存的密码，测试接口会合并旧密码。
    } else if (_passwordController.text.isEmpty) {
      return '请输入应用密码';
    }
    final path = _remotePathController.text.trim();
    if (path.isEmpty || !path.startsWith('/') || path.contains('..')) {
      return '请输入有效的远程目录';
    }
    return null;
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
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

  Widget _buildError(ThemeData theme, String message) {
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

  String _safeError(Object error, String fallback) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    if (error is UnsupportedError) return error.message ?? fallback;
    return fallback;
  }
}
