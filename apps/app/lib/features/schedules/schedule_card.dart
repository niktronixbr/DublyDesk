import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/schedule_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

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
    final theme = Theme.of(context);
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final realizado = schedule.realizado;
    final borderColor =
        realizado ? AppColors.secondary : AppColors.statusPending;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? AppColors.darkTextSecondary.withValues(alpha: 0.5)
                    : AppColors.lightOutline,
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Borda esquerda colorida
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Linha 1: título + badge + delete
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                schedule.projeto,
                                style: theme.textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(
                              realizado: realizado,
                              onTap: onToggleRealizado,
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: onDelete,
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Linha 2: produtora • diretor
                        Text(
                          schedule.diretor != null &&
                                  schedule.diretor!.isNotEmpty
                              ? '${schedule.produtora} · Dir. ${schedule.diretor}'
                              : schedule.produtora,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: secondaryColor),
                        ),

                        // Linha 3: contato (se preenchido)
                        if (schedule.contatoNome != null &&
                            schedule.contatoNome!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _ContactRow(
                            nome: schedule.contatoNome!,
                            telefone: schedule.contatoTelefone,
                            secondaryColor: secondaryColor,
                          ),
                        ],

                        const SizedBox(height: 10),
                        // Linha final: hora + valor + tipo trabalho
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: secondaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${schedule.horaInicio} – ${schedule.horaFim}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _moeda.format(schedule.valorTotal),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (schedule.tipoTrabalho != null &&
                                    schedule.tipoTrabalho!.isNotEmpty)
                                  Text(
                                    schedule.tipoTrabalho!,
                                    style: AppTheme.labelCaps(
                                      color: secondaryColor,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool realizado;
  final VoidCallback onTap;
  const _StatusBadge({required this.realizado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = realizado ? AppColors.secondary : AppColors.statusPending;
    final label = realizado ? 'REALIZADO' : 'PENDENTE';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(
          label,
          style: AppTheme.labelCaps(color: color),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String nome;
  final String? telefone;
  final Color secondaryColor;
  const _ContactRow({
    required this.nome,
    required this.telefone,
    required this.secondaryColor,
  });

  Future<void> _abrirWhatsApp(String tel) async {
    final numero = tel.replaceAll(RegExp(r'\D'), '');
    if (numero.isEmpty) return;
    final comDdd =
        numero.length <= 11 && !numero.startsWith('55') ? '55$numero' : numero;
    final uri = Uri.parse('https://wa.me/$comDdd');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tel = telefone?.trim();

    return Row(
      children: [
        Icon(Icons.phone, size: 14, color: secondaryColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            nome,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (tel != null && tel.isNotEmpty) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _abrirWhatsApp(tel),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 12,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.secondary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
