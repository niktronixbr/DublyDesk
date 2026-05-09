import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'core/models/schedule_model.dart';
import 'core/services/api_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  List<ScheduleModel> _schedules = [];
  bool _carregando = false;
  int _mesSelecionado = DateTime.now().month;
  int _anoSelecionado = DateTime.now().year;

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _fetch();
  }

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

  // ---------- Cálculos ----------

  List<ScheduleModel> get _realizadasDoMes => _schedules
      .where((s) =>
          s.realizado &&
          s.data.month == _mesSelecionado &&
          s.data.year == _anoSelecionado)
      .toList();

  double get _totalMes =>
      _realizadasDoMes.fold(0, (soma, s) => soma + s.valorTotal);

  double get _totalMesAnterior {
    final prevMonth = _mesSelecionado == 1 ? 12 : _mesSelecionado - 1;
    final prevYear =
        _mesSelecionado == 1 ? _anoSelecionado - 1 : _anoSelecionado;
    return _schedules
        .where((s) =>
            s.realizado && s.data.month == prevMonth && s.data.year == prevYear)
        .fold(0, (soma, s) => soma + s.valorTotal);
  }

  /// Variação percentual entre mês selecionado e mês anterior.
  /// Retorna null se o mês anterior não tem dados (sem comparação possível).
  double? get _variacaoMensal {
    final prev = _totalMesAnterior;
    if (prev == 0) return null;
    return ((_totalMes - prev) / prev) * 100;
  }

  double get _totalHoras {
    double soma = 0;
    for (final s in _realizadasDoMes) {
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
    for (final s in _realizadasDoMes) {
      mapa[s.produtora] = (mapa[s.produtora] ?? 0) + s.valorTotal;
    }
    if (mapa.isEmpty) return null;
    final entry = mapa.entries.reduce((a, b) => a.value > b.value ? a : b);
    return entry.key;
  }

  /// Total por dia da semana atual (Seg=0..Dom=6) somando escalas realizadas
  /// dentro da semana ISO em curso.
  Map<int, double> _totaisDaSemana() {
    final hoje = DateTime.now();
    final inicioSemana = hoje.subtract(Duration(days: hoje.weekday - 1));
    final fimSemana = inicioSemana.add(const Duration(days: 7));

    final map = <int, double>{for (var i = 0; i < 7; i++) i: 0};
    for (final s in _schedules) {
      if (!s.realizado) continue;
      final dt = DateTime(s.data.year, s.data.month, s.data.day);
      final ini = DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
      if (dt.isBefore(ini) || !dt.isBefore(fimSemana)) continue;
      final idx = s.data.weekday - 1; // 0..6
      map[idx] = (map[idx] ?? 0) + s.valorTotal;
    }
    return map;
  }

  List<int> get _anosDisponiveis {
    final anos = _schedules.map((s) => s.data.year).toSet().toList()..sort();
    if (!anos.contains(DateTime.now().year)) anos.add(DateTime.now().year);
    return anos;
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
            _buildHeader(theme, secondaryColor),
            const SizedBox(height: 24),
            _buildSemanaChart(theme, secondaryColor),
            const SizedBox(height: 24),
            _buildFiltroMes(theme, secondaryColor),
            const SizedBox(height: 16),
            _buildEscalasRealizadas(theme, secondaryColor),
            const SizedBox(height: 24),
            _buildFooterStats(theme, secondaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color secondaryColor) {
    final variacao = _variacaoMensal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOTAL ACUMULADO (${_nomeMes(_mesSelecionado).toUpperCase()})',
          style: AppTheme.labelCaps(color: secondaryColor),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _moeda.format(_totalMes),
            style: AppTheme.financialDisplay(color: AppColors.secondary),
          ),
        ),
        const SizedBox(height: 8),
        if (variacao != null)
          _VariacaoBadge(variacao: variacao)
        else
          Text(
            'Sem comparação com mês anterior',
            style: theme.textTheme.bodySmall?.copyWith(color: secondaryColor),
          ),
      ],
    );
  }

  Widget _buildSemanaChart(ThemeData theme, Color secondaryColor) {
    const labels = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    final dados = _totaisDaSemana();
    final maxVal =
        (dados.values.isEmpty ? 0 : dados.values.reduce((a, b) => a > b ? a : b))
            .toDouble();
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.25;
    final hojeIdx = DateTime.now().weekday - 1;

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
          Text('SEMANA ATUAL',
              style: AppTheme.labelCaps(color: secondaryColor)),
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
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[value.toInt() % 7],
                          style: AppTheme.labelCaps(
                            color: value.toInt() == hojeIdx
                                ? AppColors.primaryLight
                                : secondaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(7, (i) {
                  final v = dados[i] ?? 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: v,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                        color: i == hojeIdx
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

  Widget _buildFiltroMes(ThemeData theme, Color secondaryColor) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: DropdownButton<int>(
              value: _mesSelecionado,
              isExpanded: true,
              dropdownColor: theme.colorScheme.surfaceContainer,
              underline: const SizedBox(),
              items: List.generate(12, (i) => i + 1)
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(_nomeMes(m))))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _mesSelecionado = v);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: DropdownButton<int>(
              value: _anosDisponiveis.contains(_anoSelecionado)
                  ? _anoSelecionado
                  : _anosDisponiveis.last,
              isExpanded: true,
              dropdownColor: theme.colorScheme.surfaceContainer,
              underline: const SizedBox(),
              items: _anosDisponiveis
                  .map((a) =>
                      DropdownMenuItem(value: a, child: Text(a.toString())))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _anoSelecionado = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEscalasRealizadas(ThemeData theme, Color secondaryColor) {
    if (_carregando) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }

    final lista = _realizadasDoMes
      ..sort((a, b) => b.data.compareTo(a.data));

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
              '${lista.length} no mês',
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
                'Nenhuma escala realizada neste mês.',
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
            '$sinal${variacao.toStringAsFixed(1)}% vs mês anterior',
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
                Text(schedule.projeto, style: theme.textTheme.titleMedium),
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
