import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth_service.dart';
import '../../core/models/schedule_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/schedule_cache_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../notification_service.dart';
import '../../shared/widgets/user_avatar.dart';
import '../profile/profile_page.dart';
import 'schedule_card.dart';
import 'schedule_form_page.dart';

class ScheduleListPage extends StatefulWidget {
  final ThemeService? themeService;
  final VoidCallback? onToggleView;
  const ScheduleListPage({super.key, this.themeService, this.onToggleView});

  @override
  State<ScheduleListPage> createState() => ScheduleListPageState();
}

class ScheduleListPageState extends State<ScheduleListPage> {
  /// Permite que o shell de navegação dispare um refresh externo.
  Future<void> refresh() => _fetchSchedules();

  /// Recarrega os dados do usuário (nome + avatar) a partir do SharedPreferences.
  /// Chamado pelo shell de navegação ao retornar à aba de Escalas.
  Future<void> reloadUser() => _carregarUsuario();

  List<ScheduleModel> _schedules = [];
  List<ScheduleModel> _filtered = [];

  bool _carregando = false;
  bool _isOffline = false;
  bool _ordemCrescente = false;
  String _userName = '';
  String? _avatarUrl;

  final _buscaController = TextEditingController();
  String _filtroProdutora = 'Todas';
  String _filtroProjeto = 'Todos';
  DateTime? _filtroDataInicio;
  DateTime? _filtroDataFim;

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
    final avatar = await AuthService.getAvatarUrl();
    if (!mounted) return;
    setState(() {
      _userName = nome ?? '';
      _avatarUrl = avatar;
    });
  }

  Future<void> _abrirPerfil() async {
    if (widget.themeService == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(themeService: widget.themeService!),
      ),
    );
    if (!mounted) return;
    _carregarUsuario();
  }

  Future<void> _fetchSchedules() async {
    setState(() => _carregando = true);

    final result = await ApiService.get('/schedules?limit=1000');

    if (!mounted) return;

    if (result['success'] == true) {
      final responseData = result['data'];
      final List rawList =
          (responseData is Map && responseData.containsKey('data'))
              ? responseData['data'] as List
              : responseData as List;

      final parsed = <ScheduleModel>[];
      for (final raw in rawList) {
        try {
          parsed.add(ScheduleModel.fromJson(raw as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[Schedules] parse error: $e | raw=$raw');
        }
      }
      debugPrint(
          '[Schedules] received=${rawList.length} parsed=${parsed.length}');

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

      final atendeProjeto =
          _filtroProjeto == 'Todos' || s.projeto == _filtroProjeto;

      final atendeDataInicio = _filtroDataInicio == null ||
          !s.data.isBefore(_filtroDataInicio!);

      final atendeDataFim = _filtroDataFim == null ||
          !s.data.isAfter(_filtroDataFim!.add(const Duration(days: 1)));

      return atendeBusca &&
          atendeProdutora &&
          atendeProjeto &&
          atendeDataInicio &&
          atendeDataFim;
    }).toList();

    lista.sort((a, b) => _ordemCrescente
        ? a.data.compareTo(b.data)
        : b.data.compareTo(a.data));

    if (!mounted) return;
    setState(() => _filtered = lista);

    debugPrint(
        '[Schedules] filtros aplicados: ${lista.length}/${_schedules.length} '
        '(produtora=$_filtroProdutora, projeto=$_filtroProjeto, '
        'busca="${_buscaController.text}")');
    for (final s in lista) {
      debugPrint(
          '  → id=${s.id} ${s.produtora}/${s.projeto} ${s.data.toIso8601String()}');
    }
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

  List<String> _projetosDisponiveis() {
    final projetos = _schedules
        .map((s) => s.projeto)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Todos', ...projetos];
  }

  bool get _temFiltroAtivo =>
      _filtroProdutora != 'Todas' ||
      _filtroProjeto != 'Todos' ||
      _filtroDataInicio != null ||
      _filtroDataFim != null;

  void _limparFiltros() {
    setState(() {
      _filtroProdutora = 'Todas';
      _filtroProjeto = 'Todos';
      _filtroDataInicio = null;
      _filtroDataFim = null;
    });
    _aplicarFiltros();
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
          _buildFiltroBar(theme),
          const SizedBox(height: 8),
          _buildSecaoHoje(theme),
          Expanded(child: _buildListaAgrupada(theme)),
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
          UserAvatar(
            size: 40,
            name: _userName,
            avatarUrl: _avatarUrl,
            onTap: _abrirPerfil,
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
          tooltip: _ordemCrescente ? 'Mais antigas primeiro' : 'Mais recentes primeiro',
          icon: Icon(_ordemCrescente ? Icons.arrow_upward : Icons.arrow_downward),
          onPressed: () {
            setState(() => _ordemCrescente = !_ordemCrescente);
            _aplicarFiltros();
          },
        ),
        if (widget.onToggleView != null)
          IconButton(
            tooltip: 'Ver como calendário',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: widget.onToggleView,
          ),
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

  Widget _buildFiltroBar(ThemeData theme) {
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (_temFiltroAtivo) ...[
            Expanded(
              child: Text(
                '${_filtered.length} de ${_schedules.length} escalas',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primaryFor(theme.brightness),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: _limparFiltros,
              child: Text(
                'Limpar',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ] else
            Expanded(
              child: Text(
                '${_schedules.length} escalas',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondaryColor,
                ),
              ),
            ),
          GestureDetector(
            onTap: () {
              setState(() => _ordemCrescente = !_ordemCrescente);
              _aplicarFiltros();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _ordemCrescente
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: _ordemCrescente
                      ? AppColors.primaryFor(theme.brightness)
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _ordemCrescente
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                    color: _ordemCrescente
                        ? AppColors.primaryFor(theme.brightness)
                        : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _ordemCrescente ? 'Mais antigas' : 'Mais recentes',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: _ordemCrescente
                          ? AppColors.primaryFor(theme.brightness)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _abrirFiltros(theme),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _temFiltroAtivo
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: _temFiltroAtivo
                      ? AppColors.primaryFor(theme.brightness)
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune,
                    size: 16,
                    color: _temFiltroAtivo
                        ? AppColors.primaryFor(theme.brightness)
                        : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filtros',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: _temFiltroAtivo
                          ? AppColors.primaryFor(theme.brightness)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirFiltros(ThemeData theme) {
    final produtoras = _produtorasDisponiveis();
    final projetos = _projetosDisponiveis();
    var tempProdutora = _filtroProdutora;
    var tempProjeto = _filtroProjeto;
    var tempInicio = _filtroDataInicio;
    var tempFim = _filtroDataFim;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final secondaryColor = theme.brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> pickDate({required bool isInicio}) async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: (isInicio ? tempInicio : tempFim) ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                locale: const Locale('pt', 'BR'),
              );
              if (picked != null) {
                setSheet(() {
                  if (isInicio) {
                    tempInicio = picked;
                  } else {
                    tempFim = picked;
                  }
                });
              }
            }

            Widget secao(String titulo, Widget conteudo) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text(titulo,
                          style: AppTheme.labelCaps(color: secondaryColor)),
                    ),
                    conteudo,
                  ],
                );

            Widget seletorFiltro({
              required String valorAtual,
              required List<String> opcoes,
              required void Function(String) onSelecionar,
            }) =>
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final escolhido = await showDialog<String>(
                        context: ctx,
                        builder: (dialogCtx) => SimpleDialog(
                          title: null,
                          children: opcoes
                              .map(
                                (op) => SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, op),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(op,
                                            style:
                                                theme.textTheme.bodyMedium),
                                      ),
                                      if (op == valorAtual)
                                        const Icon(Icons.check,
                                            color: AppColors.primary,
                                            size: 18),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                      if (escolhido != null) {
                        setSheet(() => onSelecionar(escolhido));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(valorAtual,
                                style: theme.textTheme.bodyMedium),
                          ),
                          Icon(Icons.chevron_right,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20),
                        ],
                      ),
                    ),
                  ),
                );

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.55,
              maxChildSize: 0.75,
              builder: (_, scrollCtrl) => Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Text('Filtros',
                            style: theme.textTheme.titleMedium),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheet(() {
                              tempProdutora = 'Todas';
                              tempProjeto = 'Todos';
                              tempInicio = null;
                              tempFim = null;
                            });
                          },
                          child: const Text('Limpar tudo'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      children: [
                        secao(
                          'PRODUTORA',
                          seletorFiltro(
                            valorAtual: tempProdutora,
                            opcoes: produtoras,
                            onSelecionar: (v) => tempProdutora = v,
                          ),
                        ),
                        secao(
                          'PROJETO',
                          seletorFiltro(
                            valorAtual: tempProjeto,
                            opcoes: projetos,
                            onSelecionar: (v) => tempProjeto = v,
                          ),
                        ),
                        secao(
                          'DATA',
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _DatePickerTile(
                                    label: 'De',
                                    date: tempInicio,
                                    onTap: () => pickDate(isInicio: true),
                                    onClear: tempInicio != null
                                        ? () => setSheet(() => tempInicio = null)
                                        : null,
                                    theme: theme,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DatePickerTile(
                                    label: 'Até',
                                    date: tempFim,
                                    onTap: () => pickDate(isInicio: false),
                                    onClear: tempFim != null
                                        ? () => setSheet(() => tempFim = null)
                                        : null,
                                    theme: theme,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20, 8, 20,
                      24 + MediaQuery.of(ctx).viewPadding.bottom,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _filtroProdutora = tempProdutora;
                            _filtroProjeto = tempProjeto;
                            _filtroDataInicio = tempInicio;
                            _filtroDataFim = tempFim;
                          });
                          _aplicarFiltros();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Aplicar filtros'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

  Widget _buildListaAgrupada(ThemeData theme) {
    if (_carregando && _schedules.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filtered.isEmpty) {
      return const Center(child: Text('Nenhuma escala encontrada.'));
    }

    final hoje = DateTime.now();
    final inicioDia = DateTime(hoje.year, hoje.month, hoje.day);
    final fimSemana = inicioDia.add(const Duration(days: 7));

    final anteriores = <ScheduleModel>[];
    final deHoje = <ScheduleModel>[];
    final estaSemana = <ScheduleModel>[];
    final futuras = <ScheduleModel>[];

    for (final s in _filtered) {
      final dataLocal = s.data.toLocal();
      final dia =
          DateTime(dataLocal.year, dataLocal.month, dataLocal.day);
      if (dia.isBefore(inicioDia)) {
        anteriores.add(s);
      } else if (dia.isAtSameMomentAs(inicioDia)) {
        deHoje.add(s);
      } else if (dia.isBefore(fimSemana)) {
        estaSemana.add(s);
      } else {
        futuras.add(s);
      }
    }
    final secoes = <_Secao>[
      if (deHoje.isNotEmpty) _Secao('HOJE', deHoje),
      if (estaSemana.isNotEmpty) _Secao('ESTA SEMANA', estaSemana),
      if (futuras.isNotEmpty) _Secao('FUTURAS', futuras),
      if (anteriores.isNotEmpty) _Secao('ANTERIORES', anteriores),
    ];

    final items = <Object>[];
    for (final s in secoes) {
      items.add(s.titulo);
      items.addAll(s.items);
    }

    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final List<Widget> children = [
      const SizedBox(height: 4),
      for (final item in items)
        if (item is String)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child:
                Text(item, style: AppTheme.labelCaps(color: secondaryColor)),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ScheduleCard(
              schedule: item as ScheduleModel,
              onTap: () => _openForm(item: item),
              onDelete: () => _confirmarDelete(item.id),
              onToggleRealizado: () => _toggleRealizado(item),
            ),
          ),
      const SizedBox(height: 96),
    ];

    return RefreshIndicator(
      onRefresh: _fetchSchedules,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
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

class _Secao {
  final String titulo;
  final List<ScheduleModel> items;
  const _Secao(this.titulo, this.items);
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final ThemeData theme;

  const _DatePickerTile({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final text = date != null
        ? DateFormat('dd/MM/yyyy', 'pt_BR').format(date!)
        : 'Selecionar';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryFor(theme.brightness))),
                  const SizedBox(height: 2),
                  Text(text, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 16, color: AppColors.error),
              )
            else
              Icon(Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.primaryFor(theme.brightness)),
          ],
        ),
      ),
    );
  }
}
