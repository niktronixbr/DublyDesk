import 'package:flutter/material.dart';

import '../../auth_service.dart';
import '../../core/app_navigator.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class ProfilePage extends StatefulWidget {
  final ThemeService themeService;
  const ProfilePage({super.key, required this.themeService});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
    widget.themeService.addListener(_onTheme);
  }

  @override
  void dispose() {
    widget.themeService.removeListener(_onTheme);
    super.dispose();
  }

  void _onTheme() {
    if (mounted) setState(() {});
  }

  Future<void> _carregarUsuario() async {
    final n = await AuthService.getUserName();
    final e = await AuthService.getUserEmail();
    if (!mounted) return;
    setState(() {
      _name = n ?? '';
      _email = e ?? '';
    });
  }

  String get _iniciais {
    final partes = _name.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first.characters.first.toUpperCase();
    return (partes.first.characters.first + partes.last.characters.first)
        .toUpperCase();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await AuthService.logout();
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainer,
                border: Border.all(color: AppColors.primaryLight, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                _iniciais,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _name.isEmpty ? 'Sem nome' : _name,
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: AppColors.primaryLight,
                  ),
                  title: Text(
                    'Tema',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isDark ? 'Escuro' : 'Claro',
                    style: AppTheme.labelCaps(
                      color: theme.brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  trailing: Switch(
                    value: isDark,
                    activeThumbColor: AppColors.primaryLight,
                    onChanged: (_) => widget.themeService.toggle(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text(
              'Sair',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'DublyDesk · v1.0.0',
              style: AppTheme.labelCaps(
                color: theme.brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
