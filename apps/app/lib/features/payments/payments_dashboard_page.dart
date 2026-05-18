import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../receipts/receipt_service.dart';
import 'payment_status_dialog.dart';

class PaymentsDashboardPage extends StatefulWidget {
  const PaymentsDashboardPage({super.key});

  @override
  State<PaymentsDashboardPage> createState() => _PaymentsDashboardPageState();
}

class _PaymentsDashboardPageState extends State<PaymentsDashboardPage> {
  static final _moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');
  static final _dataFmt = DateFormat('d MMM y', 'pt_BR');

  List<PendingPayment> _items = [];
  double _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final r = await ReceiptService.listPending();
    if (!mounted) return;
    setState(() {
      _items = r.items;
      _total = r.total;
      _loading = false;
    });
  }

  Future<void> _atualizar(PendingPayment p) async {
    final atualizou = await PaymentStatusDialog.show(context, p);
    if (atualizou == true) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamentos pendentes')),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Text('Total a receber',
                            style: theme.textTheme.titleMedium),
                        const Spacer(),
                        Text(
                          _moeda.format(_total),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _items.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhuma escala pendente 🎉',
                              style: theme.textTheme.bodyLarge,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final p = _items[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(p.projeto),
                                  subtitle: Text(
                                    '${p.produtora} · ${_dataFmt.format(p.data)}',
                                  ),
                                  trailing: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _moeda.format(p.valorRestante),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        p.statusPagamento.toUpperCase(),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  onTap: () => _atualizar(p),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
