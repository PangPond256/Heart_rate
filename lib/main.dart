import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/user_model.dart';
import 'models/history_model.dart';
import 'dashboard.dart';
import 'measurement.dart';
import 'history.dart';
import 'profile.dart';
import 'settings.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(UserModelAdapter());
  Hive.registerAdapter(HistoryModelAdapter());
  await Hive.openBox<UserModel>('users');
  await Hive.openBox<HistoryModel>('history');
  await Hive.openBox('settings');
  await Hive.openBox('session');
  runApp(const HeartSenseApp());
}

class HeartSenseApp extends StatefulWidget {
  const HeartSenseApp({super.key});

  @override
  State<HeartSenseApp> createState() => _HeartSenseAppState();
}

class _HeartSenseAppState extends State<HeartSenseApp> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final box = await Hive.openBox('settings');
    setState(() {
      _isDark = box.get('darkMode', defaultValue: false);
    });
  }

  void _toggleTheme(bool value) async {
    final box = await Hive.openBox('settings');
    await box.put('darkMode', value);
    setState(() => _isDark = value);
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      fontFamily: 'SF Pro Display',
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1E3A8A),
        secondary: Color(0xFF10B981),
        surface: Colors.white,
        onSurface: Colors.black87,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1E3A8A),
        elevation: 0.5,
      ),
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'SF Pro Display',
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF93C5FD),
        secondary: Color(0xFF10B981),
        surface: Color(0xFF1E293B),
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HeartSense',
      theme: _isDark ? darkTheme : lightTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/dashboard': (context) => const HeartSenseDashboard(),
        '/measurement': (context) => const MeasurementScreen(),
        '/history': (context) => const HistoryScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => SettingsScreen(onThemeChanged: _toggleTheme),
      },
    );
  }
}
