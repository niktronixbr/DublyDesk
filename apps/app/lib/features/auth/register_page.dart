import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validarCampos() {
    final nome = _name.text.trim();
    final emailTexto = _email.text.trim();
    final senha = _password.text.trim();

    if (nome.isEmpty || emailTexto.isEmpty || senha.isEmpty) {
      _snack('Preencha nome, email e senha.');
      return false;
    }
    if (!emailTexto.contains('@') || !emailTexto.contains('.')) {
      _snack('Digite um email válido.');
      return false;
    }
    if (senha.length < 6) {
      _snack('A senha deve ter pelo menos 6 caracteres.');
      return false;
    }
    return true;
  }

  Future<void> _register() async {
    if (!_validarCampos()) return;

    setState(() => _loading = true);

    final result = await ApiService.post(
      '/auth/register',
      {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text.trim(),
      },
      requiresAuth: false,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      final token = data['token']?.toString() ?? '';
      final user = data['user'];

      if (token.isEmpty) {
        _snack('Token não retornado pelo servidor.');
        return;
      }

      await AuthService.saveSession(
        token: token,
        name: (user is Map ? user['name']?.toString() : null) ?? '',
        email: (user is Map ? user['email']?.toString() : null) ??
            _email.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro realizado com sucesso!')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(themeService: ThemeService.instance),
        ),
        (_) => false,
      );
    } else {
      _snack(result['error'] ?? 'Erro no cadastro');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Criar conta'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/logo.jpeg',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                        'Crie sua conta',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Organize suas escalas e ganhos em um só lugar.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: secondaryColor),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'NOME',
                        style: AppTheme.labelCaps(color: secondaryColor),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Seu nome artístico',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'E-MAIL',
                        style: AppTheme.labelCaps(color: secondaryColor),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'voce@exemplo.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SENHA',
                        style: AppTheme.labelCaps(color: secondaryColor),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_loading) _register();
                        },
                        decoration: InputDecoration(
                          hintText: 'Mínimo 6 caracteres',
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
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          child: Text(
                            _loading ? 'Criando...' : 'Criar conta de artista',
                          ),
                        ),
                      ),
                    ],
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
