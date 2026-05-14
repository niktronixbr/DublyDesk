import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../home_page.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final bool forceManual;
  const LoginPage({super.key, this.forceManual = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _autoLoginando = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosLembrados();
  }

  Future<void> _carregarDadosLembrados() async {
    if (widget.forceManual) {
      if (mounted) setState(() => _autoLoginando = false);
      return;
    }

    final remember = await AuthService.getRememberMe();
    if (!remember) {
      if (mounted) setState(() => _autoLoginando = false);
      return;
    }

    final email = await AuthService.getUserEmail();
    final senha = await AuthService.getSavedPassword();

    if (!mounted) return;

    if (email != null && email.isNotEmpty) {
      _email.text = email;
    }

    if (senha != null && senha.isNotEmpty && email != null && email.isNotEmpty) {
      _password.text = senha;
      await _login(autoLogin: true);
    } else {
      setState(() => _autoLoginando = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login({bool autoLogin = false}) async {
    if (_email.text.trim().isEmpty || _password.text.trim().isEmpty) {
      _snack('Preencha email e senha.');
      return;
    }

    if (!autoLogin) setState(() => _loading = true);

    final senha = _password.text.trim();
    final result = await ApiService.post(
      '/auth/login',
      {
        'email': _email.text.trim(),
        'password': senha,
      },
      requiresAuth: false,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      await AuthService.saveSession(
        token: data['token'],
        name: data['user']['name'],
        email: data['user']['email'],
        rememberMe: true,
        avatarUrl: data['user']['avatarUrl'] as String?,
        password: senha,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(themeService: ThemeService()),
        ),
      );
    } else {
      if (autoLogin) {
        // Credencial inválida (ex: senha mudou) — limpar senha salva e mostrar formulário
        await AuthService.clearSavedPassword();
        _password.clear();
        if (mounted) {
          setState(() => _autoLoginando = false);
          _snack('Sessão expirada. Digite sua senha para continuar.');
        }
      } else {
        setState(() => _loading = false);
        _snack(result['error'] ?? 'Erro no login');
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_autoLoginando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
