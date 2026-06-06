import 'package:flutter/material.dart';

import 'services/api_config.dart';
import 'services/api_client.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LitchiJournalApp());
}

class LitchiJournalApp extends StatelessWidget {
  const LitchiJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '荔枝日记',
      theme: AppTheme.light,
      home: const AppEntry(),
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

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await ApiConfig.load();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
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
    return HomeScreen(apiClient: ApiClient(_config!));
  }
}
