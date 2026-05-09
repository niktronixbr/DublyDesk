import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../core/services/api_service.dart';
import '../../shared/widgets/cold_start_loading_widget.dart';
import '../schedules/schedule_list_page.dart';
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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
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
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ScheduleListPage()),
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
    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(title: const Text('DublyDesk')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 50),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C1C2B), Color(0xFF2A2A40)],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DublyDesk',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Gestão premium de escalas de dublagem',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: Text(_loading ? 'Entrando...' : 'Entrar'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ForgotPasswordPage()),
                );
              },
              child: const Text(
                'Esqueci minha senha',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                );
              },
              child: const Text('Criar conta'),
            ),
          ],
        ),
      ),
        ),
        if (_loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xCC0F0F1A),
              child: ColdStartLoadingWidget(),
            ),
          ),
      ],
    );
  }
}
