import 'package:flutter/material.dart';

import '../models/memory_entry.dart';
import '../services/api_client.dart';
import '../services/past_memory_service.dart';
import '../widgets/flora_empty.dart';
import '../widgets/flora_icon.dart';
import '../widgets/history_calendar.dart';
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
  bool _calendarExpanded = false;
  bool _calendarLoading = false;
  bool _calendarLoadFailed = false;
  DateTime _displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  final Map<String, Set<String>> _recordedDatesByMonth = {};

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

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Future<void> _toggleCalendar() async {
    setState(() => _calendarExpanded = !_calendarExpanded);
    if (_calendarExpanded) await _loadCalendarMonth(_displayedMonth);
  }

  Future<void> _loadCalendarMonth(DateTime month, {bool force = false}) async {
    final key = _monthKey(month);
    if (!force && _recordedDatesByMonth.containsKey(key)) {
      setState(() {
        _calendarLoading = false;
        _calendarLoadFailed = false;
      });
      return;
    }
    setState(() {
      _calendarLoading = true;
      _calendarLoadFailed = false;
    });
    try {
      final result = await widget.apiClient.fetchHistoryMonth(
        month.year,
        month.month,
      );
      final dates = result.diaries
          .where((day) => day.hasContent || day.hasImages)
          .map((day) => day.date)
          .toSet();
      if (!mounted) return;
      setState(() {
        _recordedDatesByMonth[key] = dates;
        _calendarLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _calendarLoading = false;
        _calendarLoadFailed = true;
      });
    }
  }

  Future<void> _changeCalendarMonth(DateTime month) async {
    setState(() => _displayedMonth = month);
    await _loadCalendarMonth(month);
  }

  Future<void> _openDate(DateTime date) async {
    setState(() => _calendarExpanded = false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReadOnlyDiaryScreen(date: date, apiClient: widget.apiClient),
      ),
    );
    _recordedDatesByMonth.remove(_monthKey(date));
    if (_calendarExpanded) {
      await _loadCalendarMonth(_displayedMonth, force: true);
    }
  }

  void _openDiary(MemoryEntry entry) {
    _openDate(entry.date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16 + MediaQuery.of(context).padding.top,
                16,
                _calendarExpanded ? 12 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('过往', style: theme.textTheme.headlineLarge),
                      ),
                      IconButton(
                        key: const Key('history_calendar_toggle'),
                        tooltip: _calendarExpanded ? '收起日历' : '选择日期',
                        onPressed: _toggleCalendar,
                        icon: Icon(
                          _calendarExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.calendar_month_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '看看那些已经走过的日子',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  if (_calendarExpanded) ...[
                    const SizedBox(height: 16),
                    HistoryCalendar(
                      displayedMonth: _displayedMonth,
                      recordedDateKeys:
                          _recordedDatesByMonth[_monthKey(_displayedMonth)] ??
                          const {},
                      loading: _calendarLoading,
                      markerLoadFailed: _calendarLoadFailed,
                      today: DateTime.now(),
                      onMonthChanged: _changeCalendarMonth,
                      onDateSelected: _openDate,
                    ),
                  ],
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
                            const FloraEmpty(name: FloraIcons.emptyPast),

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
                            const FloraEmpty(name: FloraIcons.emptySearch),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton.icon(
                              onPressed: _randomLoading
                                  ? null
                                  : _loadRandomMemory,
                              icon: const FloraIcon(
                                FloraIcons.shuffle,
                                size: 18,
                              ),
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
}
