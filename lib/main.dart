import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db/database_helper.dart';
import 'screens/password_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize database
  await DatabaseHelper.instance.database;

  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智能收银台',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.light,
      home: const PasswordGate(),
    );
  }
}

class PasswordGate extends StatefulWidget {
  const PasswordGate({super.key});

  @override
  State<PasswordGate> createState() => _PasswordGateState();
}

class _PasswordGateState extends State<PasswordGate> {
  bool _loading = true;
  bool _needsPassword = false;

  @override
  void initState() {
    super.initState();
    _checkPassword();
  }

  Future<void> _checkPassword() async {
    final db = DatabaseHelper.instance;
    final hasPassword = await db.getSetting('app_password');
    setState(() {
      _loading = false;
      _needsPassword = hasPassword != null && hasPassword.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_needsPassword) {
      return PasswordScreen(
        onAuthenticated: () {
          setState(() => _needsPassword = false);
        },
      );
    }

    return const HomeScreen();
  }
}
