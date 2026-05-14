import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';

import 'auth_service.dart';
import 'core/app_navigator.dart';
import 'core/services/theme_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'home_page.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _themeService = ThemeService.instance;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onTheme);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onTheme);
    super.dispose();
  }

  void _onTheme() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'DublyDesk',
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      themeMode: _themeService.mode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routes: {'/login': (_) => const LoginPage()},
      home: AuthGate(themeService: _themeService),
    );
  }
}

class AuthGate extends StatefulWidget {
  final ThemeService themeService;
  const AuthGate({super.key, required this.themeService});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _logged = false;
  static bool _notificationsResynced = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() { _logged = false; _loading = false; });
      return;
    }

    final remember = await AuthService.getRememberMe();

    if (!remember) {
      if (!mounted) return;
      setState(() { _logged = false; _loading = false; });
      return;
    }

    if (!_notificationsResynced) {
      _notificationsResynced = true;
      unawaited(NotificationService.resyncFromApi());
    }

    // rememberMe=true: auto-login apenas se o dispositivo não suporta biometria.
    // Se suporta, mostra login page para que o botão de digital apareça.
    final localAuth = LocalAuthentication();
    final hasBiometrics = await localAuth.canCheckBiometrics;
    final isSupported = await localAuth.isDeviceSupported();

    if (!mounted) return;
    setState(() {
      _logged = !(hasBiometrics && isSupported);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _logged
        ? HomePage(themeService: widget.themeService)
        : const LoginPage();
  }
}
