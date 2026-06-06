import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/diary_markdown_view.dart';
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
  final _quickNoteController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDiary();
  }

  @override
  void dispose() {
    _quickNoteController.dispose();
    super.dispose();
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

  Future<void> _saveQuickNote() async {
    final content = _quickNoteController.text.trim();
    if (content.isEmpty) return;

    setState(() => _saving = true);

    try {
      await widget.apiClient.appendQuickNote(DateTime.now(), content);
      if (!mounted) return;
      _quickNoteController.clear();
      await _loadDiary();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败';
      });
    }
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
                      TextField(
                        controller: _quickNoteController,
                        decoration: const InputDecoration(
                          hintText: '写点什么...',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveQuickNote,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('保存'),
                        ),
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
