import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';

import '../widgets/flora_icon.dart';
import '../widgets/flora_page_scaffold.dart';

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
    final brandAsset = FloraIcons.path(FloraIcons.brandIcon);

    return FloraPageScaffold(
      title: '关于',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        children: [
          Center(
            child: Column(
              children: [
                Image.asset(
                  brandAsset,
                  width: 168,
                  height: 168,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  '荔枝日记',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '记录生活里的点滴，',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '看见自己的成长。',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '版本 $_version',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_changelog.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text('更新内容', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            MarkdownBody(
              data: _changelog,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                h2: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                h3: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                listBullet: theme.textTheme.bodySmall,
              ),
            ),
          ] else ...[
            const SizedBox(height: 32),
            Text('更新内容', style: theme.textTheme.titleLarge),
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
