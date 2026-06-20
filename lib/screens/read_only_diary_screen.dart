import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../services/api_client.dart';
import '../widgets/diary_markdown_view.dart';

/// 只读日记详情页。
/// 展示某天完整日记内容，隐藏所有写入入口。
/// 图片可预览，删除按钮隐藏。
class ReadOnlyDiaryScreen extends StatefulWidget {
  final DateTime date;
  final ApiClient apiClient;

  const ReadOnlyDiaryScreen({
    super.key,
    required this.date,
    required this.apiClient,
  });

  @override
  State<ReadOnlyDiaryScreen> createState() => _ReadOnlyDiaryScreenState();
}

class _ReadOnlyDiaryScreenState extends State<ReadOnlyDiaryScreen> {
  DiaryEntry? _diary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiary();
  }

  Future<void> _loadDiary() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final diary = await widget.apiClient.getDiary(widget.date);
      if (!mounted) return;
      if (diary == null || diary.raw.isEmpty) {
        setState(() {
          _error = '这一天还没有留下记录';
          _loading = false;
        });
        return;
      }
      setState(() {
        _diary = diary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败';
        _loading = false;
      });
    }
  }

  String _dateLabel() {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final d = widget.date;
    return '${d.year}年${d.month}月${d.day}日 星期${weekdays[d.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_dateLabel()),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDiary,
              child: Theme(
                data: theme.copyWith(
                  canvasColor: theme.scaffoldBackgroundColor,
                ),
                child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),
                  if (_diary != null && _diary!.raw.isNotEmpty)
                    DiaryMarkdownView(
                      markdown: _diary!.raw,
                      // 全部只读：不传任何写入回调
                      onHabitUpdate: null,
                      onEntryDelete: null,
                      onEntryEdit: null,
                      onGenerateCoach: null,
                      // 传入 apiClient 用于图片加载
                      apiClient: widget.apiClient,
                      date: widget.date,
                      // readOnly=true：HabitCard 不可交互
                      readOnly: true,
                      hiddenSections: {'tomorrow', 'habits'},
                    ),
                  const SizedBox(height: 32),
                ],
              ),
              ),
            ),
    );
  }
}
