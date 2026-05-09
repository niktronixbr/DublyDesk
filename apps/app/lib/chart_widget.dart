import 'package:flutter/material.dart';

class ChartWidget extends StatelessWidget {
  final List schedules;
  final int mes;

  const ChartWidget({super.key, required this.schedules, required this.mes});

  @override
  Widget build(BuildContext context) {
    Map<int, double> dias = {};

    for (var item in schedules) {
      final data = DateTime.parse(item['data']);

      if (data.month == mes) {
        final dia = data.day;
        final valor = double.tryParse(item['valor_total'].toString()) ?? 0;

        dias[dia] = (dias[dia] ?? 0) + valor;
      }
    }

    final entries = dias.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return Center(child: Text("Sem dados no mês"));
    }

    return ListView(
      children: entries.map((e) {
        return ListTile(
          title: Text("Dia ${e.key}"),
          trailing: Text("R\$ ${e.value.toStringAsFixed(2)}"),
        );
      }).toList(),
    );
  }
}
