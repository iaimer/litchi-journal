import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_theme.dart';

/// 关于页。
/// 显示版本号（从 PackageInfo 读取）和当前版本更新内容（从 CHANGELOG.md 解析）。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  String _changelog = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = 'v${info.version} (${info.buildNumber})';

      String changelog = '';
      try {
        final raw = await rootBundle.loadString('CHANGELOG.md');
        changelog = _parseCurrentVersion(raw, info.version);
      } catch (_) {
        changelog = '';
      }

      if (!mounted) return;
      setState(() {
        _version = version;
        _changelog = changelog;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = 'v1.1.0 (1)');
    }
  }

  /// 从 CHANGELOG.md 中解析当前版本对应的更新内容。
  /// 查找 "## X.Y.Z" 段落，直到下一个 "##"。
  String _parseCurrentVersion(String raw, String version) {
    final pattern = RegExp(r'^##\s+' + RegExp.escape(version) + r'\s*$(.*?)(?=^##\s|\Z)',
        multiLine: true, dotAll: true);
    final match = pattern.firstMatch(raw);
    if (match == null) return '';
    return match.group(1)?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Text('🌿', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  '荔枝日记',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '版本 $_version',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Flutter 客户端',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '安静的日常日记\n关心你每天的小事',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (_changelog.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              '更新内容',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _changelog,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.6,
              ),
            ),
          ] else ...[
            const SizedBox(height: 32),
            Text(
              '更新内容',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '当前版本的更新内容暂时没有读取到。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
