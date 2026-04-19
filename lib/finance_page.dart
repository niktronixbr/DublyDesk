import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'core/services/api_service.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  List<Map<String, dynamic>> _schedules = [];
  Map<String, dynamic>? _summary;
  bool _carregando = false;
  int _mesSelecionado = DateTime.now().month;

  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _carregando = true);

    final results = await Future.wait([
      ApiService.get('/schedules?limit=1000'),
      ApiService.get('/schedules/summary'),
    ]);

    if (!mounted) return;

    final schedulesResult = results[0];
    final summaryResult = results[1];

    if (schedulesResult['success'] == true) {
      final responseData = schedulesResult['data'];
      final List rawList =
          (responseData is Map && responseData.containsKey('data'))
              ? responseData['data'] as List
              : responseData as List;
      setState(() {
        _schedules = rawList.cast<Map<String, dynamic>>();
      });
    }

    if (summaryResult['success'] == true &&
        summaryResult['data'] is Map<String, dynamic>) {
      setState(() => _summary = summaryResult['data'] as Map<String, dynamic>);
    }

    if (mounted) setState(() => _carregando = false);
  }

  List<Map<String, dynamic>> get _realizadasDoMes {
    return _schedules.where((item) {
      final data = DateTime.parse(item['data'].toString());
      return data.month == _mesSelecionado && item['realizado'] == true;
    }).toList();
  }

  double get _totalMes {
    return _realizadasDoMes.fold(
        0, (soma, item) => soma + (double.tryParse(item['valor_total'].toString()) ?? 0));
  }

  double get _totalHoras {
    double soma = 0;
    for (final item in _realizadasDoMes) {
      final inicio = item['hora_inicio'].toString().split(':');
      final fim = item['hora_fim'].toString().split(':');
      final inicioMin = int.parse(inicio[0]) * 60 + int.parse(inicio[1]);
      final fimMin = int.parse(fim[0]) * 60 + int.parse(fim[1]);
      soma += (fimMin - inicioMin) / 60.0;
    }
    return soma;
  }

  Map<String, double> _totalPorProdutora() {
    final mapa = <String, double>{};
    for (final item in _realizadasDoMes) {
      final p = (item['produtora'] ?? 'Sem produtora').toString();
      mapa[p] = (mapa[p] ?? 0) + (double.tryParse(item['valor_total'].toString()) ?? 0);
    }
    return mapa;
  }

  Map<int, double> _totalPorDia() {
    final mapa = <int, double>{};
    for (final item in _realizadasDoMes) {
      final dia = DateTime.parse(item['data'].toString()).day;
      mapa[dia] = (mapa[dia] ?? 0) + (double.tryParse(item['valor_total'].toString()) ?? 0);
    }
    return mapa;
  }

  String _nomeMes(int mes) {
    const meses = [
      '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return meses[mes];
  }

  // --- Widgets ---

  Widget _skeletonBox({double height = 80, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3C),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _summaryCards() {
    if (_carregando || _summary == null) {
      return Column(
        children: [
          Row(children: [
            Expanded(child: _skeletonBox()),
            const SizedBox(width: 10),
            Expanded(child: _skeletonBox()),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _skeletonBox(height: 64)),
            const SizedBox(width: 10),
            Expanded(child: _skeletonBox(height: 64)),
          ]),
        ],
      );
    }

    final totalRealizado =
        double.tryParse(_summary!['total_realizado'].toString()) ?? 0;
    final totalPendente =
        double.tryParse(_summary!['total_pendente'].toString()) ?? 0;
    final countRealizado =
        int.tryParse(_summary!['count_realizado'].toString()) ?? 0;
    final countPendente =
        int.tryParse(_summary!['count_pendente'].toString()) ?? 0;
    final media =
        countRealizado > 0 ? totalRealizado / countRealizado : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumo geral',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _metricCard(
            'Realizado',
            _moeda.format(totalRealizado),
            Colors.greenAccent,
            Icons.check_circle_outline,
          ),
          const SizedBox(width: 10),
          _metricCard(
            'Pendente',
            _moeda.format(totalPendente),
            Colors.orangeAccent,
            Icons.schedule,
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _metricCard(
            'Escalas realizadas',
            countRealizado.toString(),
            Colors.cyanAccent,
            Icons.event_available,
          ),
          const SizedBox(width: 10),
          _metricCard(
            'Escalas pendentes',
            countPendente.toString(),
            Colors.amberAccent,
            Icons.event_busy,
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Média por escala realizada',
                  style: TextStyle(color: Colors.white70)),
              Text(
                _moeda.format(media),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricCard(
      String titulo, String valor, Color cor, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: cor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(titulo,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(valor,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: cor,
                )),
          ],
        ),
      ),
    );
  }

  Widget _cardMes(String titulo, String valor, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Text(valor,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: cor)),
          ],
        ),
      ),
    );
  }

  Widget _grafico() {
    final mapa = _totalPorDia();
    final dias = mapa.keys.toList()..sort();

    if (dias.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('Sem dados para o gráfico',
            style: TextStyle(color: Colors.white54)),
      ));
    }

    final maxY = mapa.values.reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 10 : maxY,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(
                sideTitles:
                    SideTitles(showTitles: true, reservedSize: 42)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) =>
                    Text(value.toInt().toString(),
                        style: const TextStyle(fontSize: 11)),
              ),
            ),
          ),
          barGroups: dias
              .map((dia) => BarChartGroupData(
                    x: dia,
                    barRods: [
                      BarChartRodData(
                        toY: mapa[dia] ?? 0,
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.greenAccent,
                      ),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final porProdutora = _totalPorProdutora().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final mediaPorHora =
        _totalHoras > 0 ? _totalMes / _totalHoras : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Financeiro')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Resumo global ---
            _summaryCards(),
            const SizedBox(height: 24),

            // --- Filtro por mês ---
            const Text(
              'Detalhes por mês',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: DropdownButton<int>(
                value: _mesSelecionado,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E2E),
                underline: const SizedBox(),
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text(_nomeMes(m))))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _mesSelecionado = v);
                },
              ),
            ),
            const SizedBox(height: 16),

            // --- Total do mês destaque ---
            if (_carregando)
              _skeletonBox(height: 90)
            else
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                      colors: [Colors.green, Colors.greenAccent]),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total realizado em ${_nomeMes(_mesSelecionado)}',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _moeda.format(_totalMes),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            if (_carregando) ...[
              Row(children: [
                Expanded(child: _skeletonBox(height: 64)),
                const SizedBox(width: 10),
                Expanded(child: _skeletonBox(height: 64)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _skeletonBox(height: 64)),
                const SizedBox(width: 10),
                Expanded(child: _skeletonBox(height: 64)),
              ]),
            ] else ...[
              Row(children: [
                _cardMes(
                    'Escalas', _realizadasDoMes.length.toString(),
                    Colors.cyanAccent),
                const SizedBox(width: 10),
                _cardMes(
                    'Média / escala',
                    _realizadasDoMes.isEmpty
                        ? '—'
                        : _moeda.format(
                            _totalMes / _realizadasDoMes.length),
                    Colors.orangeAccent),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _cardMes('Horas', _totalHoras.toStringAsFixed(1),
                    Colors.purpleAccent),
                const SizedBox(width: 10),
                _cardMes('Média / hora', _moeda.format(mediaPorHora),
                    Colors.greenAccent),
              ]),
            ],

            const SizedBox(height: 20),
            const Text('Ganhos por dia',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _carregando
                  ? _skeletonBox(height: 220)
                  : _grafico(),
            ),

            const SizedBox(height: 20),
            const Text('Total por produtora',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (_carregando)
              _skeletonBox(height: 100)
            else if (porProdutora.isEmpty)
              const Text('Sem dados no mês',
                  style: TextStyle(color: Colors.white54))
            else
              ...porProdutora.map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(entry.key)),
                      Text(
                        _moeda.format(entry.value),
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
