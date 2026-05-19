import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth_service.dart';
import '../../core/app_navigator.dart';
import '../../core/models/entitlement_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/user_avatar.dart';
import '../auth/change_password_page.dart';
import '../payments/payments_dashboard_page.dart';
import '../pro/pro_page.dart';
import '../pro/widgets/pro_badge.dart';
import '../pro/widgets/pro_gate.dart';

class ProfilePage extends StatefulWidget {
  final ThemeService themeService;
  const ProfilePage({super.key, required this.themeService});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = '';
  String _email = '';
  String? _avatarUrl;
  bool _uploading = false;
  String _versao = '';

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
    _carregarVersao();
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

  Future<void> _carregarVersao() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _versao = 'v${info.version}+${info.buildNumber}');
  }

  Future<void> _carregarUsuario() async {
    final n = await AuthService.getUserName();
    final e = await AuthService.getUserEmail();
    final a = await AuthService.getAvatarUrl();
    if (!mounted) return;
    setState(() {
      _name = n ?? '';
      _email = e ?? '';
      _avatarUrl = a;
    });
  }

  Future<void> _abrirAvatarPicker() async {
    if (_uploading) return;

    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tirar foto'),
                onTap: () => Navigator.pop(ctx, _AvatarAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da galeria'),
                onTap: () => Navigator.pop(ctx, _AvatarAction.gallery),
              ),
              if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: AppColors.error),
                  title: const Text('Remover foto',
                      style: TextStyle(color: AppColors.error)),
                  onTap: () => Navigator.pop(ctx, _AvatarAction.remove),
                ),
            ],
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    if (action == _AvatarAction.remove) {
      await _removerAvatar();
    } else {
      await _enviarAvatar(action == _AvatarAction.camera
          ? ImageSource.camera
          : ImageSource.gallery);
    }
  }

  Future<void> _enviarAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploading = true);

      final result =
          await ApiService.uploadFile('/auth/avatar', picked.path);

      if (!mounted) return;

      if (result['success'] == true) {
        final url = (result['data'] as Map?)?['avatarUrl'] as String?;
        await AuthService.saveAvatarUrl(url);
        if (!mounted) return;
        setState(() => _avatarUrl = url);
        _snack('Foto atualizada.');
      } else {
        _snack(result['error']?.toString() ?? 'Erro ao enviar foto.');
      }
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      if (mounted) _snack('Erro ao enviar foto: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removerAvatar() async {
    setState(() => _uploading = true);
    try {
      final result = await ApiService.delete('/auth/avatar');
      if (!mounted) return;

      if (result['success'] == true) {
        await AuthService.saveAvatarUrl(null);
        if (!mounted) return;
        setState(() => _avatarUrl = null);
        _snack('Foto removida.');
      } else {
        _snack(result['error']?.toString() ?? 'Erro ao remover foto.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text(
          'Ao sair, você precisará informar seu e-mail e senha novamente para entrar.',
        ),
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
          const _ProStatusCard(),
          ProGate(
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Pagamentos pendentes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PaymentsDashboardPage()),
                ),
              ),
            ),
          ),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                UserAvatar(
                  size: 96,
                  name: _name,
                  avatarUrl: _avatarUrl,
                  borderWidth: 2,
                  onTap: _uploading ? null : _abrirAvatarPicker,
                ),
                if (_uploading)
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black45,
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    ),
                  ),
              ],
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
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Icon(
                Icons.lock_outline,
                color: AppColors.primaryLight,
              ),
              title: Text(
                'Alterar senha',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'DublyDesk · $_versao',
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

enum _AvatarAction { camera, gallery, remove }

class _ProStatusCard extends StatelessWidget {
  const _ProStatusCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EntitlementModel>(
      valueListenable: EntitlementService.current,
      builder: (context, ent, _) {
        final theme = Theme.of(context);
        final dias = ent.daysUntilExpiry;
        late final Color bgColor;
        late final String titulo;
        late final String? subtitulo;
        late final String botaoLabel;

        if (!ent.pro) {
          bgColor = theme.colorScheme.surfaceContainer;
          titulo = 'DublyDesk Pro';
          subtitulo =
              'Recibos PDF, cobrança organizada e mais. 7 dias grátis.';
          botaoLabel = 'Conhecer Pro';
        } else if (ent.trial) {
          // tertiary (peach/laranja claro) com alpha respeita ambos os temas
          bgColor = AppColors.tertiary.withValues(alpha: 0.18);
          titulo = 'Pro · Trial';
          subtitulo = dias != null
              ? 'Trial expira em $dias dia${dias == 1 ? '' : 's'}'
              : 'Trial ativo';
          botaoLabel = 'Gerenciar assinatura';
        } else {
          bgColor = AppColors.secondary.withValues(alpha: 0.18);
          titulo = 'Pro · Ativo';
          subtitulo = ent.until != null
              ? 'Renova em ${DateFormat('d MMM y', 'pt_BR').format(ent.until!)}'
              : null;
          botaoLabel = 'Gerenciar assinatura';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(titulo, style: theme.textTheme.titleMedium),
                  const SizedBox(width: 8),
                  if (ent.pro) const ProBadge(),
                ],
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(subtitulo, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ent.pro
                    ? OutlinedButton(
                        onPressed: () => _abrirGerenciamento(context, ent),
                        child: Text(botaoLabel),
                      )
                    : FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProPage()),
                        ),
                        child: Text(botaoLabel),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _abrirGerenciamento(
      BuildContext context, EntitlementModel ent) async {
    // Play subscriptions: deep link pro Play Store
    if (ent.source == 'play') {
      final uri = Uri.parse(
        'https://play.google.com/store/account/subscriptions?package=br.com.dublydesk.app',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    // Stripe: TODO no Plano 3 (PWA web). Por enquanto, mensagem.
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gerenciamento via web disponível em breve'),
      ),
    );
  }
}
