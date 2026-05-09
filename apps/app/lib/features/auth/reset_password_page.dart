import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/api_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;

  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _redefinir() async {
    final code = _code.text.trim();
    final novaSenha = _newPassword.text.trim();
    final confirmacao = _confirmPassword.text.trim();

    if (code.length != 6) {
      _snack('Digite o código de 6 dígitos recebido por email.');
      return;
    }
    if (novaSenha.length < 6) {
      _snack('A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (novaSenha != confirmacao) {
      _snack('As senhas não coincidem.');
      return;
    }

    setState(() => _loading = true);

    final result = await ApiService.post(
      '/auth/reset-password',
      {
        'email': widget.email,
        'token': code,
        'newPassword': novaSenha,
      },
      requiresAuth: false,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha redefinida com sucesso! Faça login.')),
      );
      // Volta para login removendo toda a pilha
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _snack(result['error'] ?? 'Erro ao redefinir senha.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova senha')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C1C2B), Color(0xFF2A2A40)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.mark_email_read_outlined,
                      size: 32, color: Colors.white70),
                  const SizedBox(height: 12),
                  const Text(
                    'Digite o código recebido',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enviamos um código de 6 dígitos para ${widget.email}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 12,
              ),
              decoration: const InputDecoration(
                labelText: 'Código de 6 dígitos',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPassword,
              obscureText: _obscureNew,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nova senha',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPassword,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_loading) _redefinir();
              },
              decoration: InputDecoration(
                labelText: 'Confirmar nova senha',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _redefinir,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: Text(_loading ? 'Redefinindo...' : 'Redefinir senha'),
            ),
          ],
        ),
      ),
    );
  }
}
