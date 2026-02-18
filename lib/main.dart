import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/app_provider.dart';
import 'services/powersync_service.dart';
import 'widgets/responsive_scaffold.dart';
import 'screens/dashboard_screen.dart';
import 'screens/units_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/content_screen.dart';
import 'screens/publishing_screen.dart';
import 'screens/rates_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/payouts_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize PowerSync with error handling
  try {
    await PowerSyncService.instance.initialize(
      powerSyncEndpoint: 'https://699433304102cb53befa83c9.powersync.journeyapps.com',
      devToken: 'eyJhbGciOiJSUzI1NiIsImtpZCI6InBvd2Vyc3luYy1kZXYtMzIyM2Q0ZTMifQ.eyJzdWIiOiJkZXZUb2tlbiIsImlhdCI6MTc3MTMyNjcwMywiaXNzIjoiaHR0cHM6Ly9wb3dlcnN5bmMtYXBpLmpvdXJuZXlhcHBzLmNvbSIsImF1ZCI6Imh0dHBzOi8vNjk5NDMzMzA0MTAyY2I1M2JlZmE4M2M5LnBvd2Vyc3luYy5qb3VybmV5YXBwcy5jb20iLCJleHAiOjE3NzEzNjk5MDN9.aQVaU_1eBlJ9KpGWQXt6fgeHJdE-lZ4O7bW4AJ9lwtg8Vk2pK6fpB86F-w6mPpU5RVvSb1ogTVKFlFG4_4zTYNjOhUOe1ZaD70gEM98rpV4Oqf3UPuOGeSGtY0GAs3vXx8ntr2He-PR_4hNOQ0a24ae1lnWWIC5BeuD1ZfWiWJ6lbRYMAc9BJ2cjfe3hKI4_9FjQJGSFMmLqyh5lg2i2ZRLii6c68pYF45s0jOjJRTSPVJKjkevKMN9pK6HuJaB7gaof-85KKBXwGqtk9fEBT53ZSJ4x466a5Jh_zSqgFDc0fWBFPeVr_smmOmGmppGuztVzb_AfwnFNQldzruJT1w',
    );
    print('✅ PowerSync initialized successfully');
  } catch (e) {
    print('⚠️ PowerSync initialization failed: $e');
    print('📱 App will continue without PowerSync sync');
    // App will work without PowerSync - just won't sync
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..loadUnits(),
      child: const PmsLiteApp(),
    ),
  );
}

class PmsLiteApp extends StatelessWidget {
  const PmsLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return MaterialApp(
      title: 'PMS Lite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(prov.locale),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    UnitsScreen(),
    CalendarScreen(),
    BookingsScreen(),
    ContentScreen(),
    PublishingScreen(),
    RatesScreen(),
    ExpensesScreen(),
    PayoutsScreen(),
    ReportsScreen(),
    NotesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return ResponsiveScaffold(
      currentIndex: _currentIndex,
      onNavChanged: (i) => setState(() => _currentIndex = i),
      isRtl: prov.isRtl,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}
