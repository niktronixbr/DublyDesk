import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/models/schedule_model.dart';
import 'core/services/api_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

enum _PeriodoModo { semana, mes, ano }

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => FinancePageState();
}

class FinancePageState extends State<FinancePage> {
  List<ScheduleModel> _schedules = [];
  bool _carregando = false;
  _PeriodoModo _periodoModo = _PeriodoModo.mes;
  DateTime _dataNavegacao = DateTime.now();

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _carregarPeriodo().then((_) => _fetch());
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    setState(() => _carregando = true);
    final result = await ApiService.get('/schedules?limit=1000');

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
      setState(() => _schedules = parsed);
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _carregarPeriodo() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('finance_period_mode');
    if (saved != null && mounted) {
      setState(() {
        _periodoModo = _PeriodoModo.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => _PeriodoModo.mes,
        );
      });
    }
  }

  Future<void> _salvarPeriodo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('finance_period_mode', _periodoModo.name);
  }

  // ---------- Navegação ----------

  DateTime _semanaInicio(DateTime ref) =>
      ref.subtract(Duration(days: ref.weekday - 1));

  void _navAnterior() {
    setState(() {
      switch (_periodoModo) {
        case _PeriodoModo.semana:
          _dataNavegacao = _dataNavegacao.subtract(const Duration(days: 7));
        case _PeriodoModo.mes:
          _dataNavegacao =
              DateTime(_dataNavegacao.year, _dataNavegacao.month - 1, 1);
        case _PeriodoModo.ano:
          _dataNavegacao = DateTime(_dataNavegacao.year - 1, 1, 1);
      }
    });
  }

  void _navProximo() {
    setState(() {
      switch (_periodoModo) {
        case _PeriodoModo.semana:
          _dataNavegacao = _dataNavegacao.add(const Duration(days: 7));
        case _PeriodoModo.mes:
          _dataNavegacao =
              DateTime(_dataNavegacao.year, _dataNavegacao.month + 1, 1);
        case _PeriodoModo.ano:
          _dataNavegacao = DateTime(_dataNavegacao.year + 1, 1, 1);
      }
    });
  }

  // ---------- Cálculos ----------

  List<ScheduleModel> get _realizadasDoPeriodo {
    switch (_periodoModo) {
      case _PeriodoModo.semana:
        final ini = _semanaInicio(_dataNavegacao);
        final fim = ini.add(const Duration(days: 7));
        return _schedules
            .where((s) =>
                s.realizado &&
                !DateTime(s.data.year, s.data.month, s.data.day)
                    .isBefore(ini) &&
                DateTime(s.data.year, s.data.month, s.data.day).isBefore(fim))
            .toList();
      case _PeriodoModo.mes:
        return _schedules
            .where((s) =>
                s.realizado &&
                s.data.month == _dataNavegacao.month &&
                s.data.year == _dataNavegacao.year)
            .toList();
      case _PeriodoModo.ano:
        return _schedules
            .where((s) =>
                s.realizado && s.data.year == _dataNavegacao.year)
            .toList();
    }
  }

  double get _totalPeriodo =>
      _realizadasDoPeriodo.fold(0, (soma, s) => soma + s.valorTotal);

  double get _totalPeriodoAnterior {
    switch (_periodoModo) {
      case _PeriodoModo.semana:
        final ini =
            _semanaInicio(_dataNavegacao).subtract(const Duration(days: 7));
        final fim = ini.add(const Duration(days: 7));
        return _schedules
            .where((s) =>
                s.realizado &&
                !DateTime(s.data.year, s.data.month, s.data.day)
                    .isBefore(ini) &&
                DateTime(s.data.year, s.data.month, s.data.day).isBefore(fim))
            .fold(0, (a, b) => a + b.valorTotal);
      case _PeriodoModo.mes:
        final prevMonth =
            _dataNavegacao.month == 1 ? 12 : _dataNavegacao.month - 1;
        final prevYear =
            _dataNavegacao.month == 1
                ? _dataNavegacao.year - 1
                : _dataNavegacao.year;
        return _schedules
            .where((s) =>
                s.realizado &&
                s.data.month == prevMonth &&
                s.data.year == prevYear)
            .fold(0, (a, b) => a + b.valorTotal);
      case _PeriodoModo.ano:
        return _schedules
            .where((s) =>
                s.realizado && s.data.year == _dataNavegacao.year - 1)
            .fold(0, (a, b) => a + b.valorTotal);
    }
  }

  double? get _variacaoPeriodo {
    final prev = _totalPeriodoAnterior;
    if (prev == 0) return null;
    return ((_totalPeriodo - prev) / prev) * 100;
  }

  double get _totalHoras {
    double soma = 0;
    for (final s in _realizadasDoPeriodo) {
      final inicio = s.horaInicio.split(':');
      final fim = s.horaFim.split(':');
      if (inicio.length != 2 || fim.length != 2) continue;
      final iMin = int.parse(inicio[0]) * 60 + int.parse(inicio[1]);
      final fMin = int.parse(fim[0]) * 60 + int.parse(fim[1]);
      soma += (fMin - iMin) / 60.0;
    }
    return soma;
  }

  String? get _melhorProdutora {
    final mapa = <String, double>{};
    for (final s in _realizadasDoPeriodo) {
      mapa[s.produtora] = (mapa[s.produtora] ?? 0) + s.valorTotal;
    }
    if (mapa.isEmpty) return null;
    return mapa.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Map<int, double> _totaisPorDiaDaSemana() {
    final ini = _semanaInicio(_dataNavegacao);
    final fim = ini.add(const Duration(days: 7));
    final map = <int, double>{for (var i = 0; i < 7; i++) i: 0};
    for (final s in _schedules) {
      if (!s.realizado) continue;
      final dt = DateTime(s.data.year, s.data.month, s.data.day);
      if (dt.isBefore(ini) || !dt.isBefore(fim)) continue;
      final idx = s.data.weekday - 1;
      map[idx] = (map[idx] ?? 0) + s.valorTotal;
    }
    return map;
  }

  Map<int, double> _totaisPorSemanasDoMes() {
    final map = <int, double>{for (var i = 0; i < 5; i++) i: 0};
    for (final s in _schedules) {
      if (!s.realizado) continue;
      if (s.data.month != _dataNavegacao.month ||
          s.data.year != _dataNavegacao.year) {
        continue;
      }
      final semana = (s.data.day - 1) ~/ 7;
      map[semana] = (map[semana] ?? 0) + s.valorTotal;
    }
    return map;
  }

  Map<int, double> _totaisPorMesDoAno() {
    final map = <int, double>{for (var i = 1; i <= 12; i++) i: 0};
    for (final s in _schedules) {
      if (!s.realizado) continue;
      if (s.data.year != _dataNavegacao.year) continue;
      map[s.data.month] = (map[s.data.month] ?? 0) + s.valorTotal;
    }
    return map;
  }

  String get _periodoLabel {
    switch (_periodoModo) {
      case _PeriodoModo.semana:
        final ini = _semanaInicio(_dataNavegacao);
        final fim = ini.add(const Duration(days: 6));
        final fIni = DateFormat('dd MMM', 'pt_BR');
        final fFim = DateFormat('dd MMM yyyy', 'pt_BR');
        return '${fIni.format(ini)} – ${fFim.format(fim)}';
      case _PeriodoModo.mes:
        return '${_nomeMes(_dataNavegacao.month)} ${_dataNavegacao.year}';
      case _PeriodoModo.ano:
        return '${_dataNavegacao.year}';
    }
  }

  String get _periodoLabelCurto {
    switch (_periodoModo) {
      case _PeriodoModo.semana:
        return 'NA SEMANA';
      case _PeriodoModo.mes:
        return 'NO MÊS';
      case _PeriodoModo.ano:
        return 'NO ANO';
    }
  }

  String get _countLabel {
    final count = _realizadasDoPeriodo.length;
    switch (_periodoModo) {
      case _PeriodoModo.semana:
        return '$count na semana';
      case _PeriodoModo.mes:
        return '$count no mês';
      case _PeriodoModo.ano:
        return '$count no ano';
    }
  }

  String _nomeMes(int mes) {
    const meses = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return meses[mes];
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganhos'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _fetch,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _buildPeriodoSelector(theme, secondaryColor),
            const SizedBox(height: 24),
            _buildHeader(theme, secondaryColor),
            const SizedBox(height: 24),
            _buildGrafico(theme, secondaryColor),
            const SizedBox(height: 24),
            _buildEscalasRealizadas(theme, secondaryColor),
            const SizedBox(height: 24),
            _buildFooterStats(theme, secondaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodoSelector(ThemeData theme, Color secondaryColor) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_PeriodoModo>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 13),
            ),
            segments: const [
              ButtonSegment(
                value: _PeriodoModo.semana,
                label: Text('Semana'),
              ),
              ButtonSegment(
                value: _PeriodoModo.mes,
                label: Text('Mês'),
              ),
              ButtonSegment(
                value: _PeriodoModo.ano,
                label: Text('Ano'),
              ),
            ],
            selected: {_periodoModo},
            onSelectionChanged: (s) {
              if (s.isEmpty) return;
              setState(() => _periodoModo = s.first);
              _salvarPeriodo();
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _navAnterior,
            ),
            Expanded(
              child: Text(
                _periodoLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _navProximo,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, Color secondaryColor) {
    final variacao = _variacaoPeriodo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOTAL ACUMULADO $_periodoLabelCurto',
          style: AppTheme.labelCaps(color: secondaryColor),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _moeda.format(_totalPeriodo),
            style: AppTheme.financialDisplay(color: AppColors.secondary),
          ),
        ),
        const SizedBox(height: 8),
        if (variacao != null)
          _VariacaoBadge(variacao: variacao)
        else
          Text(
            'Sem comparação com período anterior',
            style: theme.textTheme.bodySmall?.copyWith(color: secondaryColor),
          ),
      ],
    );
  }

  Widget _buildGrafico(ThemeData theme, Color secondaryColor) {
    switch (_periodoModo) {
      case _PeriodoModo.semana:
        return _buildGraficoSemana(theme, secondaryColor);
      case _PeriodoModo.mes:
        return _buildGraficoMes(theme, secondaryColor);
      case _PeriodoModo.ano:
        return _buildGraficoAno(theme, secondaryColor);
    }
  }

  Widget _buildGraficoSemana(ThemeData theme, Color secondaryColor) {
    const labels = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    final dados = _totaisPorDiaDaSemana();
    final maxVal = dados.values.isEmpty
        ? 0.0
        : dados.values.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.25;
    final refSemana = _semanaInicio(_dataNavegacao);
    final hoje = DateTime.now();
    final hojeIdx =
        (DateTime(hoje.year, hoje.month, hoje.day).difference(refSemana).inDays)
            .clamp(0, 6);

    return _buildGraficoContainer(
      theme: theme,
      secondaryColor: secondaryColor,
      title: 'DISTRIBUIÇÃO NA SEMANA',
      maxY: maxY,
      count: 7,
      getValue: (i) => dados[i] ?? 0,
      getLabel: (i) => labels[i],
      highlightIndex: hojeIdx,
    );
  }

  Widget _buildGraficoMes(ThemeData theme, Color secondaryColor) {
    final dados = _totaisPorSemanasDoMes();
    final maxVal = dados.values.isEmpty
        ? 0.0
        : dados.values.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.25;

    return _buildGraficoContainer(
      theme: theme,
      secondaryColor: secondaryColor,
      title: 'DISTRIBUIÇÃO NO MÊS',
      maxY: maxY,
      count: 5,
      getValue: (i) => dados[i] ?? 0,
      getLabel: (i) => 'S${i + 1}',
      highlightIndex: -1,
    );
  }

  Widget _buildGraficoAno(ThemeData theme, Color secondaryColor) {
    final dados = _totaisPorMesDoAno();
    final maxVal = dados.values.isEmpty
        ? 0.0
        : dados.values.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.25;
    final hoje = DateTime.now();
    final mesAtualIdx =
        (_dataNavegacao.year == hoje.year) ? hoje.month - 1 : -1;

    return _buildGraficoContainer(
      theme: theme,
      secondaryColor: secondaryColor,
      title: 'DISTRIBUIÇÃO NO ANO',
      maxY: maxY,
      count: 12,
      getValue: (i) => dados[i + 1] ?? 0,
      getLabel: (i) => '${i + 1}',
      highlightIndex: mesAtualIdx,
    );
  }

  Widget _buildGraficoContainer({
    required ThemeData theme,
    required Color secondaryColor,
    required String title,
    required double maxY,
    required int count,
    required double Function(int) getValue,
    required String Function(int) getLabel,
    required int highlightIndex,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.labelCaps(color: secondaryColor)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= count) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            getLabel(i),
                            style: AppTheme.labelCaps(
                              color: i == highlightIndex
                                  ? AppColors.primaryLight
                                  : secondaryColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(count, (i) {
                  final v = getValue(i);
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: v,
                        width: count > 7 ? 14 : 18,
                        borderRadius: BorderRadius.circular(6),
                        color: i == highlightIndex
                            ? AppColors.primaryLight
                            : AppColors.primary,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscalasRealizadas(ThemeData theme, Color secondaryColor) {
    if (_carregando) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }

    final lista = _realizadasDoPeriodo..sort((a, b) => b.data.compareTo(a.data));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Escalas Realizadas',
                style: theme.textTheme.titleLarge,
              ),
            ),
            Text(
              _countLabel,
              style: AppTheme.labelCaps(color: secondaryColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (lista.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Center(
              child: Text(
                'Nenhuma escala realizada neste período.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: secondaryColor),
              ),
            ),
          )
        else
          ...lista.take(10).map(
                (s) => _RealizadaTile(
                  schedule: s,
                  secondaryColor: secondaryColor,
                ),
              ),
      ],
    );
  }

  Widget _buildFooterStats(ThemeData theme, Color secondaryColor) {
    final melhor = _melhorProdutora;
    final horas = _totalHoras;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'MELHOR PRODUTORA',
            value: melhor ?? '—',
            secondaryColor: secondaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'HORAS GRAVADAS',
            value: '${horas.toStringAsFixed(1)}h',
            secondaryColor: secondaryColor,
            valueColor: AppColors.primaryLight,
          ),
        ),
      ],
    );
  }
}

class _VariacaoBadge extends StatelessWidget {
  final double variacao;
  const _VariacaoBadge({required this.variacao});

  @override
  Widget build(BuildContext context) {
    final positivo = variacao >= 0;
    final color = positivo ? AppColors.secondary : AppColors.error;
    final sinal = positivo ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positivo ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$sinal${variacao.toStringAsFixed(1)}% vs período anterior',
            style: AppTheme.labelCaps(color: color),
          ),
        ],
      ),
    );
  }
}

class _RealizadaTile extends StatelessWidget {
  final ScheduleModel schedule;
  final Color secondaryColor;
  const _RealizadaTile({
    required this.schedule,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titulo = schedule.projeto.isNotEmpty
        ? schedule.projeto
        : schedule.produtora;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  schedule.diretor != null && schedule.diretor!.isNotEmpty
                      ? '${schedule.produtora} · Dir. ${schedule.diretor}'
                      : schedule.produtora,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: secondaryColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                    .format(schedule.valorTotal),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (schedule.tipoTrabalho != null &&
                  schedule.tipoTrabalho!.isNotEmpty)
                Text(
                  schedule.tipoTrabalho!,
                  style: AppTheme.labelCaps(color: secondaryColor),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color secondaryColor;
  final Color? valueColor;
  const _StatTile({
    required this.label,
    required this.value,
    required this.secondaryColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.labelCaps(color: secondaryColor)),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: valueColor ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
