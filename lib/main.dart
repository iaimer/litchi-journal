import 'package:flutter/material.dart';

import 'services/api_config.dart';
import 'services/api_client.dart';
import 'services/appearance_controller.dart';
import 'screens/home_screen.dart';
import 'screens/past_screen.dart';
import 'screens/habit_stats_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/flora_icon.dart';
import 'screens/setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppearanceController.instance.init();
  runApp(const LitchiJournalApp());
}

class LitchiJournalApp extends StatelessWidget {
  const LitchiJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppearanceController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: '荔枝日记',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: AppearanceController.instance.themeMode,
          home: const AppEntry(),
        );
      },
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  ApiConfig? _config;
  bool _loading = true;
  static const _configLoadTimeout = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await ApiConfig.load().timeout(_configLoadTimeout);
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _config = null;
        _loading = false;
      });
    }
  }

  void _onConfigured(ApiConfig config) {
    setState(() {
      _config = config;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_config == null) {
      return SetupScreen(onConfigured: _onConfigured);
    }
    return MainScreen(apiClient: ApiClient(_config!));
  }
}

/// 底部导航主页面，包含今天、过往、习惯三个 tab。
class MainScreen extends StatefulWidget {
  final ApiClient apiClient;

  const MainScreen({super.key, required this.apiClient});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _habitRefreshToken = 0;

  List<Widget> _buildScreens() {
    return [
      HomeScreen(
        key: const PageStorageKey('home'),
        apiClient: widget.apiClient,
      ),
      PastScreen(
        key: const PageStorageKey('past'),
        apiClient: widget.apiClient,
      ),
      HabitStatsScreen(
        key: const PageStorageKey('habits'),
        apiClient: widget.apiClient,
        refreshToken: _habitRefreshToken,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 2) {
              _habitRefreshToken++;
            }
          });
        },
        destinations: [
          NavigationDestination(
            icon: FloraIcon(FloraIcons.diary, size: 24),
            selectedIcon: FloraIcon(FloraIcons.diary, size: 24),
            label: '今天',
          ),
          NavigationDestination(
            icon: FloraIcon(FloraIcons.history, size: 24),
            selectedIcon: FloraIcon(FloraIcons.history, size: 24),
            label: '过往',
          ),
          NavigationDestination(
            icon: FloraIcon(FloraIcons.habits, size: 24),
            selectedIcon: FloraIcon(FloraIcons.habits, size: 24),
            label: '习惯',
          ),
        ],
      ),
    );
  }
}
