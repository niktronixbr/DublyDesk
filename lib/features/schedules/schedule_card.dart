import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/schedule_model.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class ScheduleCard extends StatelessWidget {
  final ScheduleModel schedule;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleRealizado;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.onTap,
    required this.onDelete,
    required this.onToggleRealizado,
  });

  @override
  Widget build(BuildContext context) {
    final dataFormatada =
        DateFormat('dd/MM/yyyy HH:mm').format(schedule.data);

    // Toggle só habilitado após a data/hora da escala (ou para desmarcar)
    final podeToggle =
        schedule.realizado || DateTime.now().isAfter(schedule.data);

    return Dismissible(
      key: Key('schedule_${schedule.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final result = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Excluir escala'),
            content: const Text('Deseja apagar esta escala?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
        if (result == true) onDelete();
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E2E), Color(0xFF2A2A3C)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Cabeçalho ---
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${schedule.produtora} • ${schedule.projeto}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Apagar',
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),

              // --- Corpo ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (schedule.diretor != null &&
                        schedule.diretor!.isNotEmpty)
                      Text(
                        'Diretor: ${schedule.diretor}',
                        style:
                            const TextStyle(color: Colors.white70),
                      ),
                    if (schedule.observacao != null &&
                        schedule.observacao!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notes,
                              size: 14, color: Colors.white38),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              schedule.observacao!,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: Colors.white60),
                            const SizedBox(width: 6),
                            Text(dataFormatada),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time,
                                size: 14, color: Colors.white60),
                            const SizedBox(width: 6),
                            Text(
                                '${schedule.horaInicio} - ${schedule.horaFim}'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- Rodapé: toggle + valor ---
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white12),
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
                child: Row(
                  children: [
                    Text(
                      'Pendente',
                      style: TextStyle(
                        fontSize: 12,
                        color: schedule.realizado
                            ? Colors.white30
                            : Colors.orangeAccent,
                        fontWeight: schedule.realizado
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                    Switch(
                      value: schedule.realizado,
                      onChanged: podeToggle
                          ? (_) => onToggleRealizado()
                          : null,
                      activeColor: Colors.greenAccent,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    Text(
                      'Realizado',
                      style: TextStyle(
                        fontSize: 12,
                        color: schedule.realizado
                            ? Colors.greenAccent
                            : Colors.white30,
                        fontWeight: schedule.realizado
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _moeda.format(schedule.valorTotal),
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
          ),
        ),
      ),
    );
  }
}
