import 'package:flutter/material.dart';

import '../models/image_settings.dart';
import '../services/image_settings_repository.dart';

/// 图片上传设置页。
class ImageCompressPage extends StatefulWidget {
  final ImageSettingsRepository? repository;

  const ImageCompressPage({super.key, this.repository});

  @override
  State<ImageCompressPage> createState() => _ImageCompressPageState();
}

class _ImageCompressPageState extends State<ImageCompressPage> {
  late final ImageSettingsRepository _repository;
  late final TextEditingController _prefixController;
  ImageSettings _settings = ImageSettings.defaults();
  bool _loading = true;
  bool _saving = false;
  String? _prefixError;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ImageSettingsRepository();
    _prefixController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _prefixController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _repository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _prefixController.text = settings.filenamePrefix;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefix = _prefixController.text.trim();
    if (!ImageSettings.isValidFilenamePrefix(prefix)) {
      setState(() => _prefixError = '只能使用英文、数字、短横线或下划线');
      return;
    }

    setState(() => _saving = true);
    await _repository.save(_settings.copyWith(filenamePrefix: prefix));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('图片设置已保存')));
  }

  Future<void> _resetDefault() async {
    final defaults = await _repository.resetDefault();
    if (!mounted) return;
    setState(() {
      _settings = defaults;
      _prefixController.text = defaults.filenamePrefix;
      _prefixError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('图片设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _buildSectionTitle(theme, '图片压缩'),
                const SizedBox(height: 8),
                _buildOption<int>(
                  label: '最大长边',
                  value: _settings.maxLongSidePx,
                  options: ImageSettings.maxLongSideOptions,
                  suffix: ' px',
                  onChanged: (value) =>
                      _update(_settings.copyWith(maxLongSidePx: value)),
                ),
                _buildOption<int>(
                  label: '目标大小',
                  value: _settings.targetSizeMb,
                  options: ImageSettings.targetSizeMbOptions,
                  suffix: ' MB',
                  onChanged: (value) =>
                      _update(_settings.copyWith(targetSizeMb: value)),
                ),
                _buildOption<int>(
                  label: 'JPEG 质量',
                  value: _settings.initialQuality,
                  options: ImageSettings.initialQualityOptions,
                  onChanged: (value) =>
                      _update(_settings.copyWith(initialQuality: value)),
                ),
                _buildOption<int>(
                  label: '最小长边',
                  value: _settings.minLongSidePx,
                  options: ImageSettings.minLongSideOptions,
                  suffix: ' px',
                  onChanged: (value) =>
                      _update(_settings.copyWith(minLongSidePx: value)),
                ),
                _buildInfoRow(theme, '输出格式', 'JPEG'),
                const SizedBox(height: 24),
                _buildSectionTitle(theme, '文件命名'),
                const SizedBox(height: 12),
                TextField(
                  controller: _prefixController,
                  decoration: InputDecoration(
                    labelText: '文件名前缀',
                    hintText: ImageSettings.defaultFilenamePrefix,
                    errorText: _prefixError,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _prefixError = ImageSettings.isValidFilenamePrefix(value)
                          ? null
                          : '只能使用英文、数字、短横线或下划线';
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildInfoRow(theme, '日期格式', 'YYYYMMDD'),
                _buildInfoRow(theme, '序号格式', '三位序号 NNN'),
                const SizedBox(height: 12),
                _buildPreview(theme),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _resetDefault,
                  child: const Text('恢复默认'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中...' : '保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _update(ImageSettings settings) {
    setState(() => _settings = settings);
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(title, style: theme.textTheme.titleLarge);
  }

  Widget _buildOption<T>({
    required String label,
    required T value,
    required List<T> options,
    required ValueChanged<T> onChanged,
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: options
            .map(
              (option) => DropdownMenuItem<T>(
                value: option,
                child: Text('$option$suffix'),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final prefix = _prefixController.text.trim().isEmpty
        ? ImageSettings.defaultFilenamePrefix
        : _prefixController.text.trim();

    return Text(
      '$prefix-YYYYMMDD-NNN.jpg',
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
