import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../auth_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../home_page.dart';
import 'login_page.dart';

class BiometricLockPage extends StatefulWidget {
  final ThemeService themeService;
  const BiometricLockPage({super.key, required this.themeService});

  @override
  State<BiometricLockPage> createState() => _BiometricLockPageState();
}

class _BiometricLockPageState extends State<BiometricLockPage> {
  final _localAuth = LocalAuthentication();
  String _userName = '';
  bool _autenticando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
  }

  Future<void> _carregarUsuario() async {
    final nome = await AuthService.getUserName();
    if (!mounted) return;
    setState(() => _userName = nome ?? '');
  }

  Future<void> _prompt() async {
    if (_autenticando) return;
    setState(() {
      _autenticando = true;
      _erro = null;
    });

    bool ok = false;
    try {
      ok = await _localAuth.authenticate(
        localizedReason: 'Desbloquear DublyDesk',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      debugPrint('Biometria erro: $e');
      if (mounted) setState(() => _erro = 'Não foi possível autenticar.');
    }

    if (!mounted) return;
    setState(() => _autenticando = false);

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(themeService: widget.themeService),
        ),
      );
    }
  }

  void _entrarComSenha() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage(forceManual: true)),
    );
  }

  String get _primeiroNome {
    final partes = _userName.trim().split(' ');
    return partes.isEmpty ? '' : partes.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/logo.jpeg',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _primeiroNome.isEmpty ? 'Olá!' : 'Olá, $_primeiroNome',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Use sua biometria para desbloquear o DublyDesk.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: secondaryColor),
              ),
              const SizedBox(height: 40),
              InkWell(
                onTap: _autenticando ? null : _prompt,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    Icons.fingerprint,
                    size: 80,
                    color: AppColors.primaryFor(theme.brightness),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_autenticando)
                Text(
                  'Aguardando autenticação...',
                  style: AppTheme.labelCaps(color: secondaryColor),
                )
              else
                Text(
                  'Toque para tentar novamente',
                  style: AppTheme.labelCaps(color: secondaryColor),
                ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(
                  _erro!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 40),
              TextButton(
                onPressed: _entrarComSenha,
                child: const Text('Entrar com senha'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
