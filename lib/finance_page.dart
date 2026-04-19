import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'api_config.dart';
import 'auth_service.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  List schedules = [];
  bool carregando = false;
  int mesSelecionado = DateTime.now().month;

  final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    fetch();
  }

  Future<void> fetch() async {
    setState(() => carregando = true);

    try {
      final headers = await AuthService.authHeaders();

      final res = await http
          .get(Uri.parse('$baseUrl/schedules'), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final List data = json.decode(res.body);

        if (!mounted) return;
        setState(() {
          schedules = data;
        });
      }
    } catch (e) {
      debugPrint('Erro financeiro: $e');
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  List get realizadasDoMes {
    return schedules.where((item) {
      final data = DateTime.parse(item['data']);
      return data.month == mesSelecionado && item['realizado'] == true;
    }).toList();
  }

  double get totalMes {
    double soma = 0;
    for (final item in realizadasDoMes) {
      soma += double.tryParse(item['valor_total'].toString()) ?? 0;
    }
    return soma;
  }

  double get totalHoras {
    double soma = 0;
    for (final item in realizadasDoMes) {
      final inicio = item['hora_inicio'].toString().split(':');
      final fim = item['hora_fim'].toString().split(':');

      final inicioMin =
          (int.parse(inicio[0]) * 60) + int.parse(inicio[1]);
      final fimMin = (int.parse(fim[0]) * 60) + int.parse(fim[1]);

      soma += (fimMin - inicioMin) / 60.0;
    }
    return soma;
  }

  double get mediaPorEscala {
    if (realizadasDoMes.isEmpty) return 0;
    return totalMes / realizadasDoMes.length;
  }

  double get mediaPorHora {
    if (totalHoras == 0) return 0;
    return totalMes / totalHoras;
  }

  Map<String, double> totalPorProdutora() {
    final mapa = <String, double>{};

    for (final item in realizadasDoMes) {
      final produtora = (item['produtora'] ?? 'Sem produtora').toString();
      final valor = double.tryParse(item['valor_total'].toString()) ?? 0;
      mapa[produtora] = (mapa[produtora] ?? 0) + valor;
    }

    return mapa;
  }

  Map<int, double> totalPorDia() {
    final mapa = <int, double>{};

    for (final item in realizadasDoMes) {
      final data = DateTime.parse(item['data']);
      final valor = double.tryParse(item['valor_total'].toString()) ?? 0;
      mapa[data.day] = (mapa[data.day] ?? 0) + valor;
    }

    return mapa;
  }

  String nomeMes(int mes) {
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
      'Dezembro'
    ];
    return meses[mes];
  }

  Widget cardResumo(String titulo, String valor, Color cor) {
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
            Text(titulo, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
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
      ),
    );
  }

  Widget grafico() {
    final mapa = totalPorDia();
    final dias = mapa.keys.toList()..sort();

    if (dias.isEmpty) {
      return const Center(child: Text('Sem dados para o gráfico'));
    }

    final maxY = (mapa.values.reduce((a, b) => a > b ? a : b) * 1.2);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 10 : maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 42),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString());
                },
              ),
            ),
          ),
          barGroups: dias.map((dia) {
            return BarChartGroupData(
              x: dia,
              barRods: [
                BarChartRodData(
                  toY: mapa[dia] ?? 0,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final porProdutora = totalPorProdutora().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('DublyDesk Financeiro'),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButton<int>(
                    value: mesSelecionado,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E2E),
                    underline: const SizedBox(),
                    items: List.generate(12, (i) => i + 1)
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(nomeMes(m)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        mesSelecionado = v;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Colors.green, Colors.greenAccent],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total do mês',
                        style: TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        moeda.format(totalMes),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    cardResumo(
                      'Escalas',
                      realizadasDoMes.length.toString(),
                      Colors.cyanAccent,
                    ),
                    const SizedBox(width: 10),
                    cardResumo(
                      'Média / escala',
                      moeda.format(mediaPorEscala),
                      Colors.orangeAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    cardResumo(
                      'Horas',
                      totalHoras.toStringAsFixed(1),
                      Colors.purpleAccent,
                    ),
                    const SizedBox(width: 10),
                    cardResumo(
                      'Média / hora',
                      moeda.format(mediaPorHora),
                      Colors.greenAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ganhos por dia',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: grafico(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Total por produtora',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (porProdutora.isEmpty)
                  const Text('Sem dados no mês')
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
                            moeda.format(entry.value),
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
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
}