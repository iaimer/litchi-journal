import 'package:flutter/material.dart';

import '../models/memory_entry.dart';
import '../services/api_client.dart';
import '../services/past_memory_service.dart';
import '../widgets/memory_card.dart';
import 'read_only_diary_screen.dart';

class PastScreen extends StatefulWidget {
  final ApiClient apiClient;

  const PastScreen({super.key, required this.apiClient});

  @override
  State<PastScreen> createState() => _PastScreenState();
}

class _PastScreenState extends State<PastScreen> {
  late final PastMemoryService _service;
  MemoryEntry? _todayMemory;
  MemoryEntry? _randomMemory;
  bool _loading = true;
  bool _randomLoading = false;
  bool _todayLoading = true;
  String? _randomDateKey;

  @override
  void initState() {
    super.initState();
    _service = PastMemoryService(widget.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([_loadTodayHistory(), _loadRandomMemory()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadTodayHistory() async {
    try {
      final memory = await _service.getTodayHistory();
      if (!mounted) return;
      setState(() {
        _todayMemory = memory;
        _todayLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _todayLoading = false);
    }
  }

  Future<void> _loadRandomMemory() async {
    setState(() => _randomLoading = true);
    try {
      final excludeKey = _randomDateKey;
      final memory = await _service.getRandomMemory(
        excludeDateKeys: excludeKey != null ? {excludeKey} : null,
      );
      if (!mounted) return;
      setState(() {
        _randomMemory = memory;
        _randomDateKey = memory != null
            ? '${memory.date.year}-${memory.date.month.toString().padLeft(2, '0')}-${memory.date.day.toString().padLeft(2, '0')}'
            : null;
        _randomLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _randomLoading = false);
    }
  }

  void _openDiary(MemoryEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReadOnlyDiaryScreen(date: entry.date, apiClient: widget.apiClient),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('过往', style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 4),
                  Text(
                    '看看那些已经走过的日子',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // 区块一：今天曾经发生过
                          Text('今天曾经发生过', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 12),
                          if (_todayLoading)
                            _buildLoadingCard()
                          else if (_todayMemory != null)
                            MemoryCard(
                              entry: _todayMemory!,
                              apiClient: widget.apiClient,
                              onTap: () => _openDiary(_todayMemory!),
                            )
                          else
                            _buildEmptyState('这一天还没有旧时光。\n要不要随便走走？'),

                          const SizedBox(height: 24),

                          // 区块二：随便走走
                          Text('随便走走', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 12),
                          if (_randomLoading)
                            _buildLoadingCard()
                          else if (_randomMemory != null)
                            MemoryCard(
                              entry: _randomMemory!,
                              apiClient: widget.apiClient,
                              onTap: () => _openDiary(_randomMemory!),
                            )
                          else
                            _buildEmptyState('还没有找到可以回看的旧时光。'),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton.icon(
                              onPressed: _randomLoading
                                  ? null
                                  : _loadRandomMemory,
                              icon: const Icon(Icons.shuffle, size: 18),
                              label: const Text('再走一段'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor, width: 0.5),
      ),
      child: const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
