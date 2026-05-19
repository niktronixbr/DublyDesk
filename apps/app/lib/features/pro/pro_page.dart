import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/services/billing_service.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/pro_badge.dart';

class ProPage extends StatefulWidget {
  const ProPage({super.key});

  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  bool _loading = false;
  String? _selectedProductId;
  late final bool _wasPro;

  static const _beneficios = [
    'Gerar recibos PDF profissionais',
    'Enviar recibos por email com 1 toque',
    'Dashboard de pagamentos pendentes',
    'Controle de status (pago/parcial/atrasado)',
    '7 dias grátis pra testar',
  ];

  @override
  void initState() {
    super.initState();
    _wasPro = EntitlementService.current.value.pro;
    BillingService.loadProducts().then((_) => mounted ? setState(() {}) : null);
    EntitlementService.current.addListener(_onEntitlementChanged);
  }

  @override
  void dispose() {
    EntitlementService.current.removeListener(_onEntitlementChanged);
    super.dispose();
  }

  /// Quando a compra completa, o purchaseStream do BillingService atualiza
  /// o EntitlementService. Aqui escutamos a transição Free→Pro pra fechar a paywall.
  void _onEntitlementChanged() {
    if (!mounted || _wasPro) return;
    if (EntitlementService.current.value.pro) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pro ativado · aproveite!')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _comprar(ProductDetails product) async {
    setState(() {
      _loading = true;
      _selectedProductId = product.id;
    });
    try {
      await BillingService.buy(product);
      // O ouvinte de purchaseStream cuida do resto (verify + entitlement)
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar compra: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restaurar() async {
    setState(() => _loading = true);
    try {
      await BillingService.restore();
      if (mounted && EntitlementService.isPro) {
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma compra ativa encontrada')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final produtos = BillingService.products;
    final monthly = produtos.where((p) => p.id == 'pro_monthly').firstOrNull;
    final annual = produtos.where((p) => p.id == 'pro_annual').firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('DublyDesk Pro')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ProBadge(fontSize: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Profissionalize sua dublagem',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ..._beneficios.map(
                (b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.secondary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(b, style: theme.textTheme.bodyLarge)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (monthly == null && annual == null) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                Text(
                  'Carregando planos…',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              if (annual != null)
                _PriceCard(
                  product: annual,
                  title: 'Anual',
                  badge: 'MAIS POPULAR · ~16% OFF',
                  highlighted: true,
                  loading: _loading && _selectedProductId == annual.id,
                  onTap: _loading ? null : () => _comprar(annual),
                ),
              if (annual != null && monthly != null) const SizedBox(height: 12),
              if (monthly != null)
                _PriceCard(
                  product: monthly,
                  title: 'Mensal',
                  loading: _loading && _selectedProductId == monthly.id,
                  onTap: _loading ? null : () => _comprar(monthly),
                ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _restaurar,
                  child: const Text('Restaurar compras'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '7 dias grátis. Cancele a qualquer momento pelo Google Play.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final ProductDetails product;
  final String title;
  final String? badge;
  final bool highlighted;
  final bool loading;
  final VoidCallback? onTap;

  const _PriceCard({
    required this.product,
    required this.title,
    this.badge,
    this.highlighted = false,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: highlighted
          ? AppColors.secondary.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? AppColors.secondary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(product.price, style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                product.description,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Iniciar teste grátis · $title'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
