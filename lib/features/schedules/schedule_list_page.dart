import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth_service.dart';
import '../../core/app_navigator.dart';
import '../../core/models/schedule_model.dart';
import '../../core/services/api_service.dart';
import '../../finance_page.dart';
import '../../notification_service.dart';
import '../../shared/widgets/cold_start_loading_widget.dart';
import 'schedule_card.dart';
import 'schedule_form_page.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class ScheduleListPage extends StatefulWidget {
  const ScheduleListPage({super.key});

  @override
  State<ScheduleListPage> createState() => _ScheduleListPageState();
}

class _ScheduleListPageState extends State<ScheduleListPage> {
  List<ScheduleModel> _schedules = [];
  List<ScheduleModel> _filtered = [];

  double _totalRealizado = 0;
  bool _carregando = false;
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

  Future<void> _logout() async {
    await AuthService.logout();
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _fetchSchedules() async {
    setState(() => _carregando = true);

    final result = await ApiService.get('/schedules');

    if (!mounted) return;

    if (result['success'] == true) {
      final responseData = result['data'];
      final List rawList = (responseData is Map && responseData.containsKey('data'))
          ? responseData['data'] as List
          : responseData as List;
      final parsed = rawList
          .map((e) => ScheduleModel.fromJson(e as Map<String, dynamic>))
          .toList();

      double soma = 0;
      for (final s in parsed) {
        if (s.realizado) soma += s.valorTotal;
      }

      setState(() {
        _schedules = parsed;
        _totalRealizado = soma;
      });
      _aplicarFiltros();
    } else {
      _snack(result['error'] ?? 'Erro ao buscar escalas.');
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
      MaterialPageRoute(builder: (_) => ScheduleFormPage(item: item)),
    ).then((_) => _fetchSchedules());
  }

  Future<void> _toggleRealizado(ScheduleModel item) async {
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

  Widget _buildResumoTopo() {
    final realizadas = _schedules.where((s) => s.realizado).length;
    final pendentes = _schedules.where((s) => !s.realizado).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C2B), Color(0xFF2A2A40)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _userName.isEmpty ? 'DublyDesk' : 'Olá, $_userName',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            _moeda.format(_totalRealizado),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStatusCard(
                  titulo: 'Realizadas',
                  valor: realizadas.toString(),
                  cor: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatusCard(
                  titulo: 'Pendentes',
                  valor: pendentes.toString(),
                  cor: Colors.orangeAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          TextField(
            controller: _buscaController,
            decoration: const InputDecoration(
              hintText: 'Buscar por projeto, produtora ou diretor',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButton<String>(
              value: _filtroProdutora,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E2E),
              underline: const SizedBox(),
              items: _produtorasDisponiveis()
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _filtroProdutora = value);
                _aplicarFiltros();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (_carregando) {
      return const Expanded(child: ColdStartLoadingWidget());
    }

    if (_filtered.isEmpty) {
      return const Expanded(
        child: Center(child: Text('Nenhuma escala encontrada.')),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _fetchSchedules,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          itemCount: _filtered.length,
          itemBuilder: (context, index) {
            final schedule = _filtered[index];
            return ScheduleCard(
              schedule: schedule,
              onTap: () => _openForm(item: schedule),
              onDelete: () => _deletar(schedule.id),
              onToggleRealizado: () => _toggleRealizado(schedule),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DublyDesk'),
        actions: [
          IconButton(
            tooltip: 'Nova escala',
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(),
          ),
          IconButton(
            tooltip: 'Financeiro',
            icon: const Icon(Icons.attach_money),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FinancePage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildResumoTopo(),
          _buildFiltros(),
          _buildLista(),
        ],
      ),
    );
  }
}

class _MiniStatusCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;

  const _MiniStatusCard({
    required this.titulo,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}
