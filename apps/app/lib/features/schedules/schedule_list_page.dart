import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth_service.dart';
import '../../calendar_page.dart';
import '../../core/models/schedule_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/schedule_cache_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../notification_service.dart';
import 'schedule_card.dart';
import 'schedule_form_page.dart';

class ScheduleListPage extends StatefulWidget {
  final ThemeService? themeService;
  const ScheduleListPage({super.key, this.themeService});

  @override
  State<ScheduleListPage> createState() => ScheduleListPageState();
}

class ScheduleListPageState extends State<ScheduleListPage> {
  /// Permite que o shell de navegação dispare um refresh externo.
  Future<void> refresh() => _fetchSchedules();

  List<ScheduleModel> _schedules = [];
  List<ScheduleModel> _filtered = [];

  bool _carregando = false;
  bool _isOffline = false;
  String _userName = '';

  final _buscaController = TextEditingController();
  String _filtroProdutora = 'Todas';

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
    _fetchSchedules();
    _buscaController.addListener(_aplicarFiltros);
    NotificationService.requestAndroidPermissions();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarUsuario() async {
    final nome = await AuthService.getUserName();
    if (!mounted) return;
    setState(() => _userName = nome ?? '');
  }

  Future<void> _fetchSchedules() async {
    setState(() => _carregando = true);

    final result = await ApiService.get('/schedules');

    if (!mounted) return;

    if (result['success'] == true) {
      final responseData = result['data'];
      final List rawList =
          (responseData is Map && responseData.containsKey('data'))
              ? responseData['data'] as List
              : responseData as List;
      final parsed = rawList
          .map((e) => ScheduleModel.fromJson(e as Map<String, dynamic>))
          .toList();

      await ScheduleCacheService.save(parsed);

      if (!mounted) return;
      setState(() {
        _schedules = parsed;
        _isOffline = false;
      });
      _aplicarFiltros();
    } else {
      final cached = await ScheduleCacheService.load();
      if (!mounted) return;

      if (cached.isNotEmpty) {
        setState(() {
          _schedules = cached;
          _isOffline = true;
        });
        _aplicarFiltros();
      } else {
        _snack(result['error'] ?? 'Erro ao buscar escalas.');
      }
    }

    if (mounted) setState(() => _carregando = false);
  }

  void _aplicarFiltros() {
    final termo = _buscaController.text.trim().toLowerCase();

    final lista = _schedules.where((s) {
      final atendeBusca = termo.isEmpty ||
          s.produtora.toLowerCase().contains(termo) ||
          s.projeto.toLowerCase().contains(termo) ||
          (s.diretor ?? '').toLowerCase().contains(termo);

      final atendeProdutora =
          _filtroProdutora == 'Todas' || s.produtora == _filtroProdutora;

      return atendeBusca && atendeProdutora;
    }).toList();

    if (!mounted) return;
    setState(() => _filtered = lista);
  }

  List<String> _produtorasDisponiveis() {
    final produtoras = _schedules
        .map((s) => s.produtora)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Todas', ...produtoras];
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openForm({ScheduleModel? item}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleFormPage(
          item: item,
          escalasExistentes: _schedules,
        ),
      ),
    ).then((_) => _fetchSchedules());
  }

  Future<void> _toggleRealizado(ScheduleModel item) async {
    if (!item.realizado && DateTime.now().isBefore(item.data)) {
      _snack(
        'A escala ainda não ocorreu. Só é possível marcar como realizada após o horário agendado.',
      );
      return;
    }

    final result = await ApiService.put(
      '/schedules/${item.id}',
      {'realizado': !item.realizado},
    );

    if (result['success'] == true) {
      await _fetchSchedules();
    } else {
      _snack(result['error'] ?? 'Não foi possível atualizar a escala.');
    }
  }

  Future<void> _deletar(int id) async {
    final result = await ApiService.delete('/schedules/$id');

    if (result['success'] == true) {
      await NotificationService.cancelAgendaNotifications(id);
      await _fetchSchedules();
    } else {
      _snack(result['error'] ?? 'Não foi possível apagar a escala.');
    }
  }

  String get _iniciais {
    final partes = _userName.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first.characters.first.toUpperCase();
    return (partes.first.characters.first + partes.last.characters.first)
        .toUpperCase();
  }

  // ----------------------------------------------------------------
  // UI
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          if (_isOffline) _buildOfflineBanner(),
          const SizedBox(height: 8),
          _buildSearch(theme),
          const SizedBox(height: 12),
          _buildChips(theme),
          const SizedBox(height: 8),
          _buildSecaoHoje(theme),
          Expanded(child: _buildLista(theme)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainer,
              border: Border.all(color: AppColors.primaryLight, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              _iniciais,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: AppColors.primaryLight),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'DublyDesk',
            style: theme.appBarTheme.titleTextStyle,
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Notificações',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Notificações em breve.')),
            );
          },
        ),
        IconButton(
          tooltip: 'Calendário',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CalendarPage(escalas: _schedules),
            ),
          ).then((_) => _fetchSchedules()),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFB45309),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Você está offline — exibindo dados salvos',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: _fetchSchedules,
            child: const Text(
              'Tentar novamente',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _buscaController,
        decoration: InputDecoration(
          hintText: 'Buscar por projeto, produtora ou diretor',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9999),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9999),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9999),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildChips(ThemeData theme) {
    final produtoras = _produtorasDisponiveis();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: produtoras.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = produtoras[i];
          final selected = _filtroProdutora == p;
          return GestureDetector(
            onTap: () {
              setState(() => _filtroProdutora = p);
              _aplicarFiltros();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryLight
                    : theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: selected
                      ? AppColors.primaryLight
                      : theme.dividerColor,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                p,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? const Color(0xFF1000A9)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSecaoHoje(ThemeData theme) {
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final hoje = DateFormat('EEEE, dd MMM', 'pt_BR').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _userName.isEmpty
                  ? 'Suas escalas'
                  : 'Olá, ${_userName.split(' ').first}',
              style: theme.textTheme.titleLarge,
            ),
          ),
          Text(
            hoje[0].toUpperCase() + hoje.substring(1),
            style: AppTheme.labelCaps(color: secondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(ThemeData theme) {
    if (_carregando && _schedules.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filtered.isEmpty) {
      return const Center(child: Text('Nenhuma escala encontrada.'));
    }

    return RefreshIndicator(
      onRefresh: _fetchSchedules,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        itemCount: _filtered.length,
        itemBuilder: (context, index) {
          final schedule = _filtered[index];
          return ScheduleCard(
            schedule: schedule,
            onTap: () => _openForm(item: schedule),
            onDelete: () => _confirmarDelete(schedule.id),
            onToggleRealizado: () => _toggleRealizado(schedule),
          );
        },
      ),
    );
  }

  void _confirmarDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir escala'),
        content: const Text('Deseja apagar esta escala?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletar(id);
            },
            child: const Text(
              'Excluir',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
