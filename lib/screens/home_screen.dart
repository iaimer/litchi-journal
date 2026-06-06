import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../models/tag_config.dart';
import '../services/api_client.dart';
import '../services/tag_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/diary_markdown_view.dart';
import '../widgets/quick_note_composer.dart';
import '../widgets/section_card.dart';

class HomeScreen extends StatefulWidget {
  final ApiClient apiClient;

  const HomeScreen({super.key, required this.apiClient});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DiaryEntry? _diary;
  bool _loading = true;
  String? _error;
  TagConfig? _tagConfig;
  bool _tagConfigFailed = false;

  @override
  void initState() {
    super.initState();
    _loadDiary();
    _loadTagConfig();
  }

  Future<void> _loadTagConfig() async {
    try {
      final repo = TagRepository(apiClient: widget.apiClient);
      final config = await repo.loadTagConfig();
      if (!mounted) return;
      setState(() {
        _tagConfig = config;
        _tagConfigFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _tagConfigFailed = true);
    }
  }

  Future<void> _loadDiary() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final diary = await widget.apiClient.getDiary(DateTime.now());
      if (!mounted) return;
      setState(() {
        _diary = diary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败';
        _loading = false;
      });
    }
  }

  Future<void> _loadDiarySilently() async {
    try {
      final diary = await widget.apiClient.getDiary(DateTime.now());
      if (!mounted) return;
      setState(() => _diary = diary);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存，但刷新失败')));
    }
  }

  Future<void> _handleQuickNoteSubmit(
      String content, List<String> tags) async {
    final success = await widget.apiClient.appendQuickNote(
      DateTime.now(),
      content,
      tags: tags,
    );
    if (!success) throw Exception('保存失败');
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存')));
    _loadDiarySilently();
  }

  String _todayString() {
    final now = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${now.year}年${now.month}月${now.day}日 星期${weekdays[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('荔枝日记')),
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDiary,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),
                  Text(
                    _todayString(),
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '已连接服务器',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style:
                          TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_diary != null && _diary!.raw.isNotEmpty) ...[
                    DiaryMarkdownView(markdown: _diary!.raw),
                  ] else ...[
                    const Text(
                      '今日还没有日记内容',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SectionCard(
                    title: '快速记录',
                    children: [
                      QuickNoteComposer(
                        onSubmit: _handleQuickNoteSubmit,
                        tagConfig: _tagConfig,
                        tagHint:
                            _tagConfigFailed ? '标签暂不可用' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
