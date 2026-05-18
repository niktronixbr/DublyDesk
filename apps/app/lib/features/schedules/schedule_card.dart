import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/entitlement_model.dart';
import '../../core/models/schedule_model.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../pro/pro_page.dart';
import '../pro/widgets/pro_badge.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

bool _temInfoPendente(ScheduleModel s) {
  if (s.isCompromisso) return false;
  return s.projeto.isEmpty ||
      (s.diretor == null || s.diretor!.isEmpty) ||
      (s.tipoTrabalho == null || s.tipoTrabalho!.isEmpty);
}

class ScheduleCard extends StatelessWidget {
  final ScheduleModel schedule;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleRealizado;
  final VoidCallback? onGenerateReceipt;
  final bool compact;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.onTap,
    required this.onDelete,
    required this.onToggleRealizado,
    this.onGenerateReceipt,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final realizado = schedule.realizado;
    final isCompromisso = schedule.isCompromisso;

    final accentGreen = isCompromisso
        ? AppColors.primaryLight
        : (realizado
            ? (theme.brightness == Brightness.dark
                ? AppColors.secondaryLight
                : AppColors.secondaryDark)
            : AppColors.secondary);

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isCompromisso
                  ? AppColors.primaryLight.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.18 : 0.10)
                  : (realizado
                      ? (theme.brightness == Brightness.dark
                          ? AppColors.secondary.withValues(alpha: 0.22)
                          : AppColors.secondary.withValues(alpha: 0.14))
                      : theme.colorScheme.surfaceContainer),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF8E96B8)
                    : const Color(0xFF8B8DA8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.45 : 0.22,
                  ),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        compact ? 10 : 14, compact ? 10 : 14, compact ? 6 : 8, compact ? 10 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Linha 1: título + badge + delete
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                schedule.projeto.isNotEmpty
                                    ? schedule.projeto
                                    : schedule.produtora,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: compact ? 13 : null,
                                  fontStyle: schedule.projeto.isEmpty
                                      ? FontStyle.italic
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            isCompromisso
                                ? _TipoBadge(label: 'COMPROMISSO')
                                : _StatusBadge(
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
                        // Linha 2: produtora • diretor ou descrição do compromisso
                        Text(
                          isCompromisso
                              ? (schedule.observacao?.isNotEmpty == true
                                  ? schedule.observacao!
                                  : '')
                              : (schedule.diretor != null &&
                                      schedule.diretor!.isNotEmpty
                                  ? '${schedule.produtora} · Dir. ${schedule.diretor}'
                                  : schedule.produtora),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: secondaryColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Badge "Info pendente" quando campos opcionais estão vazios
                        if (_temInfoPendente(schedule)) ...[
                          const SizedBox(height: 6),
                          _InfoPendenteBadge(),
                        ],

                        // Linha 3: contato (se preenchido, oculto em modo compacto ou para compromisso)
                        if (!isCompromisso &&
                            !compact &&
                            schedule.contatoNome != null &&
                            schedule.contatoNome!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _ContactRow(
                            nome: schedule.contatoNome!,
                            telefone: schedule.contatoTelefone,
                            secondaryColor: secondaryColor,
                            accentColor: accentGreen,
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
                              () {
                                try {
                                  final dateStr = DateFormat('d MMM', 'pt_BR').format(schedule.data);
                                  return '$dateStr · ${schedule.horaInicio} – ${schedule.horaFim}';
                                } catch (_) {
                                  return '${schedule.horaInicio} – ${schedule.horaFim}';
                                }
                              }(),
                              style: theme.textTheme.bodySmall,
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isCompromisso)
                                  schedule.remunerado
                                      ? Text(
                                          _moeda.format(schedule.valorTotal),
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: accentGreen,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : Text(
                                          'Não remunerado',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: secondaryColor,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                if (!isCompromisso &&
                                    schedule.tipoTrabalho != null &&
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
                        if (!isCompromisso && schedule.realizado && schedule.remunerado) ...[
                          const SizedBox(height: 12),
                          _BotaoRecibo(onTap: onGenerateReceipt),
                        ],
                      ],
                    ),
                  ),
                ),
                ],
              ),
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
    final theme = Theme.of(context);
    final solidoNoLight = realizado && theme.brightness == Brightness.light;
    final color = realizado ? AppColors.secondary : AppColors.statusPending;
    final label = realizado ? 'REALIZADO' : 'PENDENTE';

    final fillColor = solidoNoLight
        ? AppColors.secondaryDark
        : color.withValues(alpha: 0.15);
    final borderColor = solidoNoLight
        ? AppColors.secondaryDark
        : color.withValues(alpha: 0.6);
    final textColor = solidoNoLight ? Colors.white : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: AppTheme.labelCaps(color: textColor),
        ),
      ),
    );
  }
}

class _TipoBadge extends StatelessWidget {
  final String label;
  const _TipoBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? AppColors.primaryLight.withValues(alpha: 0.15)
        : AppColors.primary;
    final borderColor = isDark
        ? AppColors.primaryLight.withValues(alpha: 0.6)
        : AppColors.primary;
    final textColor = isDark ? AppColors.primaryLight : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: AppTheme.labelCaps(color: textColor),
      ),
    );
  }
}

class _InfoPendenteBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 11, color: Colors.amber),
          SizedBox(width: 4),
          Text(
            'INFO PENDENTE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.amber,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoRecibo extends StatelessWidget {
  final VoidCallback? onTap;
  const _BotaoRecibo({this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EntitlementModel>(
      valueListenable: EntitlementService.current,
      builder: (context, ent, _) {
        final theme = Theme.of(context);
        return InkWell(
          onTap: () {
            if (ent.pro) {
              onTap?.call();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProPage()),
              );
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Gerar recibo',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!ent.pro) ...[
                  const SizedBox(width: 6),
                  const ProBadge(fontSize: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String nome;
  final String? telefone;
  final Color secondaryColor;
  final Color accentColor;
  const _ContactRow({
    required this.nome,
    required this.telefone,
    required this.secondaryColor,
    required this.accentColor,
  });

  Future<void> _abrirWhatsApp(String tel, BuildContext ctx) async {
    final numero = tel.replaceAll(RegExp(r'\D'), '');
    if (numero.isEmpty) return;
    // Brazilian numbers without country code: 10 digits (landline) or 11 digits (mobile).
    // Numbers >= 12 digits are assumed to already carry a country code.
    // Numbers < 10 digits are passed through unchanged.
    final comDdd = (numero.length == 10 || numero.length == 11) && !numero.startsWith('55')
        ? '55$numero'
        : numero;
    final uri = Uri.parse('https://wa.me/$comDdd');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao abrir WhatsApp: $e');
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
        );
      }
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
            onTap: () => _abrirWhatsApp(tel, context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 12,
                    color: accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: accentColor,
                      decoration: TextDecoration.underline,
                      decorationColor: accentColor,
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
