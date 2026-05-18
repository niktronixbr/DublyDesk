import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'api_service.dart';
import 'entitlement_service.dart';

class BillingService {
  static const productIds = {'pro_monthly', 'pro_annual'};

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static List<ProductDetails> _products = [];

  static List<ProductDetails> get products => _products;

  /// Deve ser chamado uma vez no startup (após login).
  static Future<bool> init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('BillingService: store indisponível');
      return false;
    }
    _sub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _sub?.cancel(),
      onError: (e) => debugPrint('BillingService stream error: $e'),
    );
    await loadProducts();
    return true;
  }

  static Future<void> loadProducts() async {
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint('BillingService.loadProducts error: ${response.error}');
    }
    _products = response.productDetails;
  }

  static Future<void> buy(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    // Subscriptions usam buyNonConsumable (Play não diferencia subs/non-consumable na API)
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  static Future<void> restore() async {
    await _iap.restorePurchases();
    // Após restore, validar no backend
    await ApiService.post('/billing/restore', {});
    await EntitlementService.refresh(force: true);
  }

  static Future<void> _onPurchaseUpdate(List<PurchaseDetails> updates) async {
    for (final p in updates) {
      switch (p.status) {
        case PurchaseStatus.pending:
          debugPrint('BillingService: compra pendente ${p.productID}');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyOnBackend(p);
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;
        case PurchaseStatus.error:
          debugPrint('BillingService: erro ${p.error}');
          break;
        case PurchaseStatus.canceled:
          debugPrint('BillingService: cancelada ${p.productID}');
          break;
      }
    }
  }

  static Future<void> _verifyOnBackend(PurchaseDetails p) async {
    final token = p.verificationData.serverVerificationData;
    final response = await ApiService.post('/billing/play/verify', {
      'purchaseToken': token,
      'productId': p.productID,
    });
    if (response['success'] == true && response['data'] is Map) {
      await EntitlementService.updateFromJson(
          response['data'] as Map<String, dynamic>);
    }
  }

  @visibleForTesting
  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _products = [];
  }
}
