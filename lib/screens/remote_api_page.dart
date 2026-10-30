import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_config.dart';
import '../widgets/flora_page_scaffold.dart';
import '../widgets/flora_success_snackbar.dart';

/// 服务器连接配置，测试不写入，保存只采用已验证的当前表单。
class RemoteApiPage extends StatefulWidget {
  final ApiConfig apiConfig;
  final ApiClient? apiClient;
  final bool tokenConfigured;
  final ValueChanged<ApiConfig>? onConfigChanged;
  final ApiClient Function(ApiConfig config)? createApiClient;

  const RemoteApiPage({
    super.key,
    required this.apiConfig,
    this.apiClient,
    this.tokenConfigured = true,
    this.onConfigChanged,
    this.createApiClient,
  });

  @override
  State<RemoteApiPage> createState() => _RemoteApiPageState();
}

class _RemoteApiPageState extends State<RemoteApiPage> {
  late ApiConfig _current;
  late final TextEditingController _url;
  final _token = TextEditingController();
  bool _testing = false;
  bool _saving = false;
  int _revision = 0;
  int? _verifiedRevision;
  String? _message;
  bool _success = false;

  bool get _busy => _testing || _saving;

  @override
  void initState() {
    super.initState();
    _current =
        widget.apiClient?.configWithBaseUrl(widget.apiConfig.baseUrl) ??
        widget.apiConfig;
    _url = TextEditingController(text: _current.baseUrl);
    _url.addListener(_changed);
    _token.addListener(_changed);
  }

  void _changed() {
    setState(() {
      _revision++;
      _verifiedRevision = null;
      _message = null;
      _success = false;
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  ApiConfig? _candidate() {
    final address = _url.text.trim();
    final uri = Uri.tryParse(address);
    String? error;
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        RegExp(r'\s').hasMatch(address)) {
      error = '请输入有效的 HTTP 或 HTTPS 服务器地址';
    }
    final entered = _token.text.trim();
    if (error == null &&
        entered.isNotEmpty &&
        (entered.length < 32 || RegExp(r'\s').hasMatch(entered))) {
      error = '请输入至少32个字符且不含空白的新 Token';
    }
    final token = entered.isEmpty ? _current.token : entered;
    if (error == null && token.isEmpty) error = '请输入 Token';
    if (error != null) {
      setState(() {
        _message = error;
        _success = false;
      });
      return null;
    }
    return ApiConfig(baseUrl: address, token: token);
  }

  Future<void> _run({required bool save}) async {
    if (_busy) return;
    final config = _candidate();
    if (config == null) return;
    final revision = _revision;
    setState(() {
      _saving = save;
      _testing = !save;
      _message = null;
    });
    ApiClient? client;
    try {
      if (!save || _verifiedRevision != revision) {
        client = widget.createApiClient?.call(config) ?? ApiClient(config);
        final result = await client.testConnection(DateTime.now());
        if (!mounted || revision != _revision) return;
        if (!result.success) {
          setState(() {
            _message = result.message;
            _success = false;
            _verifiedRevision = null;
          });
          return;
        }
        _verifiedRevision = revision;
      }
      if (!mounted || revision != _revision) return;
      if (!save) {
        setState(() {
          _message = '连接成功';
          _success = true;
        });
        return;
      }
      await config.save();
      if (!mounted) return;
      _current = config;
      _token.clear();
      _verifiedRevision = _revision;
      widget.onConfigChanged?.call(config);
      showFloraSuccessSnackBar(context, '连接配置已保存并生效');
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() {
          _message = save ? '验证或保存失败，请重试' : '连接测试失败，请重试';
          _success = false;
          _verifiedRevision = null;
        });
      }
    } finally {
      client?.dispose();
      if (mounted) {
        setState(() {
          _testing = false;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_saving,
      child: FloraPageScaffold(
        title: '服务器连接',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('server_url'),
              controller: _url,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(labelText: '服务器地址'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('server_token'),
              controller: _token,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              decoration: InputDecoration(
                labelText: 'Token',
                hintText: _current.token.isNotEmpty
                    ? '已配置，留空保持不变'
                    : '请输入 Token',
              ),
            ),
            const SizedBox(height: 24),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _run(save: false),
                      child: Text(
                        _testing ? '测试中…' : '测试连接',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy ? null : () => _run(save: true),
                      child: Text(
                        _saving ? '保存中…' : '保存',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color: _success
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
