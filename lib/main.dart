import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/api_config.dart';
import 'services/api_client.dart';
import 'services/reading_cache_repository.dart';
import 'services/appearance_controller.dart';
import 'screens/home_screen.dart';
import 'screens/settings_page.dart';
import 'screens/past_screen.dart';
import 'screens/habit_stats_screen.dart';
import 'theme/app_theme.dart';
import 'theme/diary_reading_style.dart';
import 'widgets/flora_dock.dart';
import 'widgets/flora_dock_pages.dart';
import 'widgets/flora_origin.dart';
import 'widgets/flora_skeleton.dart';
import 'widgets/flora_splash.dart';
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
          theme: DiaryReadingStyle.applyTo(
            AppTheme.light,
            fontSize: AppearanceController.instance.readingFontSize,
          ),
          darkTheme: DiaryReadingStyle.applyTo(
            AppTheme.dark,
            fontSize: AppearanceController.instance.readingFontSize,
          ),
          themeMode: AppearanceController.instance.themeMode,
          builder: (context, child) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: theme.scaffoldBackgroundColor,
                statusBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                statusBarBrightness: isDark
                    ? Brightness.dark
                    : Brightness.light,
                systemNavigationBarColor: theme.scaffoldBackgroundColor,
                systemNavigationBarDividerColor: theme.scaffoldBackgroundColor,
                systemNavigationBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarContrastEnforced: false,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AppEntry(),
        );
      },
    );
  }
}

class AppEntry extends StatefulWidget {
  final ReadingCacheRepository? readingCache;
  const AppEntry({super.key, this.readingCache});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  ApiConfig? _config;
  ApiClient? _apiClient;
  bool _loading = true;
  bool _showSplash = true;
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
        if (config == null) {
          _config = null;
          _apiClient?.dispose();
          _apiClient = null;
        } else {
          _setConfig(config);
        }
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
      _setConfig(config);
    });
  }

  void _setConfig(ApiConfig config) {
    _apiClient?.dispose();
    _config = config;
    _apiClient = ApiClient(config, readingCache: widget.readingCache);
  }

  void _onSplashDone() {
    if (!mounted) return;
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return FloraSplash(ready: !_loading, onDone: _onSplashDone);
    }
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const FloraSkeletonRegion(
          child: Center(child: FloraSkeletonBox(width: 180, height: 16)),
        ),
      );
    }
    if (_config == null) {
      return SetupScreen(onConfigured: _onConfigured);
    }
    return MainScreen(
      apiClient: _apiClient!,
      onApiConfigChanged: _onConfigured,
    );
  }

  @override
  void dispose() {
    _apiClient?.dispose();
    super.dispose();
  }
}

/// 底部导航主页面，保留今天、过往、习惯与设置四个页面状态。
class MainScreen extends StatefulWidget {
  final ApiClient apiClient;
  final ValueChanged<ApiConfig> onApiConfigChanged;

  const MainScreen({
    super.key,
    required this.apiClient,
    required this.onApiConfigChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Rect? _dockOrigin;
  final _dockIconKeys = List.generate(4, (_) => GlobalKey());
  int _habitRefreshToken = 0;
  int _settingsRevision = 0;
  int _menuDismissRevision = 0;

  List<Widget> _buildScreens() {
    return [
      HomeScreen(
        key: const PageStorageKey('home'),
        apiClient: widget.apiClient,
        onApiConfigChanged: widget.onApiConfigChanged,
        active: _currentIndex == 0,
        settingsRevision: _settingsRevision,
      ),
      PastScreen(
        key: const PageStorageKey('past'),
        apiClient: widget.apiClient,
        active: _currentIndex == 1,
      ),
      HabitStatsScreen(
        key: const PageStorageKey('habits'),
        apiClient: widget.apiClient,
        refreshToken: _habitRefreshToken,
      ),
      SettingsPage(
        key: const PageStorageKey('settings'),
        primary: true,
        apiConfig: ApiConfig(baseUrl: widget.apiClient.baseUrl, token: ''),
        apiClient: widget.apiClient,
        tokenConfigured: widget.apiClient.hasToken,
        onApiConfigChanged: widget.onApiConfigChanged,
        onPreferencesChanged: () => setState(() {
          _settingsRevision++;
          _habitRefreshToken++;
        }),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    final dockHeight = FloraDock.heightFor(context);
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBody: true,
      body: FloraDockScope(
        clearance: dockHeight + 12 + 56 + 16 + systemBottom,
        fabBottom: systemBottom + dockHeight + 12,
        menuDismissRevision: _menuDismissRevision,
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: FloraDockPages(
            selectedIndex: _currentIndex,
            origin: _dockOrigin,
            children: screens,
          ),
        ),
      ),
      bottomNavigationBar: FloraDock(
        selectedIndex: _currentIndex,
        iconKeys: _dockIconKeys,
        height: dockHeight,
        onSelected: (index) {
          final iconContext = _dockIconKeys[index].currentContext;
          if (iconContext != null) {
            _dockOrigin = FloraOrigin.capture(iconContext)?.rect;
          }
          setState(() {
            _menuDismissRevision++;
            if (index == _currentIndex && index != 2) return;
            _currentIndex = index;
            if (index == 2) {
              _habitRefreshToken++;
            }
          });
        },
      ),
    );
  }
}
