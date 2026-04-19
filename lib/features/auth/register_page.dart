import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../core/services/api_service.dart';
import '../schedules/schedule_list_page.dart';

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
        MaterialPageRoute(builder: (_) => const ScheduleListPage()),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 30),
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
                    'Crie sua conta para organizar suas agendas',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_loading) _register();
              },
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
              onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: Text(_loading ? 'Criando...' : 'Criar conta'),
            ),
          ],
        ),
      ),
    );
  }
}
