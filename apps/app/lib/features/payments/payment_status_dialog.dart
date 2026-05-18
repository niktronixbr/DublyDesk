import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../receipts/receipt_service.dart';

class PaymentStatusDialog extends StatefulWidget {
  final PendingPayment payment;
  const PaymentStatusDialog({super.key, required this.payment});

  static Future<bool?> show(BuildContext context, PendingPayment payment) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: PaymentStatusDialog(payment: payment),
      ),
    );
  }

  @override
  State<PaymentStatusDialog> createState() => _PaymentStatusDialogState();
}

class _PaymentStatusDialogState extends State<PaymentStatusDialog> {
  late final TextEditingController _valorCtrl;
  String _status = 'pago';
  bool _loading = false;

  static final _moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

  @override
  void initState() {
    super.initState();
    _valorCtrl = TextEditingController(
      text: widget.payment.valorRestante.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() => _loading = true);
    final valor = double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? 0;
    final ok = await ReceiptService.updatePaymentStatus(
      scheduleId: widget.payment.scheduleId,
      statusPagamento: _status,
      valorPago: valor,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao atualizar status')),
      );
      setState(() => _loading = false);
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
          Text('Atualizar pagamento', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${widget.payment.projeto} · ${_moeda.format(widget.payment.valorTotal)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'pago', child: Text('Pago')),
              DropdownMenuItem(value: 'parcial', child: Text('Parcial')),
              DropdownMenuItem(value: 'pendente', child: Text('Pendente')),
              DropdownMenuItem(value: 'atrasado', child: Text('Atrasado')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'pago'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valorCtrl,
            decoration: const InputDecoration(labelText: 'Valor pago (R\$)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _confirmar,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
