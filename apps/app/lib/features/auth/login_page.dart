import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../auth_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../home_page.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _podeBiometria = false;

  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _carregarDadosLembrados();
    await _verificarBiometria();
  }

  Future<void> _carregarDadosLembrados() async {
    final remember = await AuthService.getRememberMe();
    if (!remember) return;
    final email = await AuthService.getUserEmail();
    if (email != null && email.isNotEmpty && mounted) {
      setState(() {
        _email.text = email;
        _rememberMe = true;
      });
    }
  }

  Future<void> _verificarBiometria() async {
    final temToken = await AuthService.hasSavedToken();
    if (!temToken) return;
    final disponivel = await _localAuth.canCheckBiometrics;
    final suportado = await _localAuth.isDeviceSupported();
    if (!mounted) return;
    setState(() => _podeBiometria = disponivel && suportado);
  }

  Future<void> _loginBiometrico() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Use sua impressão digital para entrar no DublyDesk',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (ok) {
        await AuthService.setRememberMe(true);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomePage(themeService: ThemeService.instance),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Biometria erro: $e');
      _snack('Biometria: $e');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.trim().isEmpty) {
      _snack('Preencha email e senha.');
      return;
    }

    setState(() => _loading = true);

    final result = await ApiService.post(
      '/auth/login',
      {
        'email': _email.text.trim(),
        'password': _password.text.trim(),
      },
      requiresAuth: false,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      await AuthService.saveSession(
        token: data['token'],
        name: data['user']['name'],
        email: data['user']['email'],
        rememberMe: _rememberMe,
        avatarUrl: data['user']['avatarUrl'] as String?,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(themeService: ThemeService()),
        ),
      );
    } else {
      _snack(result['error'] ?? 'Erro no login');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              children: [
                // ----- Logo -----
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/logo.jpeg',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ----- Card de boas-vindas -----
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Boas-vindas',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Acesse o painel profissional de gestão de voz',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: secondaryColor),
                      ),
                      const SizedBox(height: 24),

                      // E-MAIL
                      Text(
                        'E-MAIL',
                        style: AppTheme.labelCaps(color: secondaryColor),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'voce@exemplo.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // SENHA + esqueci
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'SENHA',
                              style:
                                  AppTheme.labelCaps(color: secondaryColor),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordPage(),
                              ),
                            ),
                            child: Text(
                              'Esqueci minha senha',
                              style: AppTheme.labelCaps(
                                color: AppColors.primaryFor(theme.brightness),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Lembrar de mim
                      InkWell(
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (v) =>
                                      setState(() => _rememberMe = v ?? false),
                                  activeColor: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Lembrar de mim',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Entrar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: Text(
                            _loading
                                ? 'Entrando...'
                                : 'Entrar no Painel  →',
                          ),
                        ),
                      ),

                      // Biometria
                      if (_podeBiometria) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loginBiometrico,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Entrar com impressão digital'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryLight,
                              side: const BorderSide(
                                  color: AppColors.primaryLight),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Criar conta
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          ),
                          child: const Text('Criar nova conta de artista'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                Center(
                  child: Text(
                    '© 2026 DUBLYDESK — SISTEMA PROFISSIONAL DE GESTÃO DE VOZ',
                    textAlign: TextAlign.center,
                    style: AppTheme.labelCaps(color: secondaryColor),
                  ),
                ),
              ],
            ),
            if (_loading)
              Positioned.fill(
                child: ColoredBox(
                  color: theme.scaffoldBackgroundColor.withValues(alpha: 0.6),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
