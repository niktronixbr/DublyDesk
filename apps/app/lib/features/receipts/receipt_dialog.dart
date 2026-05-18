import 'package:flutter/material.dart';

import '../../core/models/schedule_model.dart';
import 'receipt_service.dart';

class ReceiptDialog extends StatefulWidget {
  final ScheduleModel schedule;

  const ReceiptDialog({super.key, required this.schedule});

  /// Helper: abre como modal bottom sheet.
  static Future<void> show(BuildContext context, ScheduleModel schedule) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: ReceiptDialog(schedule: schedule),
      ),
    );
  }

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  final _cpfCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _cpfCtrl.dispose();
    _emailCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _gerarEEnviar() async {
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o email destinatário')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ReceiptService.generate(
        scheduleId: widget.schedule.id,
        cpf: _cpfCtrl.text.trim().isEmpty ? null : _cpfCtrl.text.trim(),
      );
      if (!result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage ?? 'Erro ao gerar')),
          );
        }
        return;
      }
      final ok = await ReceiptService.sendEmail(
        receiptId: result.receiptId!,
        destinatario: _emailCtrl.text.trim(),
        mensagem: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Recibo enviado pra ${_emailCtrl.text.trim()}'
                : 'Recibo gerado, mas falhou enviar email'),
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Gerar recibo', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${widget.schedule.projeto} · ${widget.schedule.produtora}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cpfCtrl,
            decoration: const InputDecoration(
              labelText: 'CPF (opcional, aparece no recibo)',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Enviar pra',
              hintText: 'email@cliente.com',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _msgCtrl,
            decoration: const InputDecoration(
              labelText: 'Mensagem (opcional)',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _gerarEEnviar,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Gerar e enviar'),
          ),
        ],
      ),
    );
  }
}
