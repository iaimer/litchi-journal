import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';

import '../widgets/flora_icon.dart';

import '../theme/app_theme.dart';

/// 关于页。
/// 显示版本号（从 PackageInfo 读取）和当前版本更新内容（从 CHANGELOG.md 解析）。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  /// 从 CHANGELOG.md 中解析当前版本对应的更新内容。
  /// 查找 "## X.Y.Z" 或 "## vX.Y.Z" 段落，直到下一个 "##"。
  static String parseCurrentVersion(String raw, String version) {
    final lines = raw.split('\n');
    final content = <String>[];
    var collecting = false;

    for (final line in lines) {
      if (line.startsWith('## ')) {
        if (collecting) break;
        final heading = line.substring(3).trim();
        collecting = heading == version || heading == 'v$version';
        continue;
      }
      if (collecting) content.add(line);
    }

    return content.join('\n').trim();
  }

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
        changelog = AboutPage.parseCurrentVersion(raw, info.version);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const SizedBox(height: 32),
                const FloraIcon(FloraIcons.brandIcon, size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  '荔枝日记',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '版本 $_version',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Flutter 客户端',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '安静的日常日记\n关心你每天的小事',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
