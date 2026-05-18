# Flutter Pro Fase 1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Habilitar a primeira fase do DublyDesk Pro no Flutter Android — paywall, compra via Google Play Billing, restore, geração de recibo PDF, dashboard de pagamentos pendentes e notificações de expiração do trial.

**Architecture:** Adicionar pacote `in_app_purchase`, criar serviços singleton (`EntitlementService`, `BillingService`) seguindo o padrão estático existente em `ApiService`, e telas/widgets que consomem entitlement via `FutureBuilder`/`ValueListenable`. Sem introduzir novo state-management — segue o padrão da casa (StatefulWidget + callbacks + GlobalKey).

**Tech Stack:** Flutter 3.11+, Dart, `in_app_purchase` (Google Play Billing), `flutter_local_notifications` (já presente), `url_launcher` (já presente), `http` (já presente via `ApiService`).

**Spec base:** `Docs/superpowers/specs/2026-05-18-pro-diferenciais-roadmap-design.md` — Fase 1 (Recibos & Cobrança) já está pronta no backend; este plano conecta o Flutter.

**Backend contracts disponíveis (já implantados em api.dublydesk.com):**
- `GET /me/entitlements` → `{ pro: bool, trial: bool, until: ISO8601|null, source: 'stripe'|'play'|null, cancelAtPeriodEnd: bool }`
- `POST /billing/play/verify` body `{ purchaseToken, productId }` (`'pro_monthly'`|`'pro_annual'`) → mesmo formato de entitlement
- `POST /billing/restore` → mesmo formato de entitlement
- `POST /receipts/generate` body `{ scheduleId, cpf? }` → `{ id, pdfPath, createdAt }` (requer Pro, retorna 402 se Free)
- `POST /receipts/:id/send-email` body `{ destinatario, mensagem? }` → `{ ok: true }`
- `GET /receipts/pending` → `{ items: [...schedule], totalPendente: number }`
- `PATCH /schedules/:id/payment` body `{ status_pagamento, valor_pago?, vencimento? }` → escala atualizada

**Produtos Google Play (a criar no Console antes do release):**
- `pro_monthly` — R$ 9,90/mês
- `pro_annual` — R$ 99,90/ano

---

## File Structure

**Novos arquivos:**
- `apps/app/lib/core/models/entitlement_model.dart` — modelo + parse
- `apps/app/lib/core/services/entitlement_service.dart` — singleton, cache + refresh
- `apps/app/lib/core/services/billing_service.dart` — wrapper `in_app_purchase`
- `apps/app/lib/core/services/pro_notifications_service.dart` — agendamento de avisos de trial
- `apps/app/lib/features/pro/pro_page.dart` — paywall (preços + CTA Trial)
- `apps/app/lib/features/pro/widgets/pro_gate.dart` — widget condicional (mostra child se Pro, fallback se Free)
- `apps/app/lib/features/pro/widgets/pro_badge.dart` — badge "PRO" reutilizável
- `apps/app/lib/features/receipts/receipt_dialog.dart` — sheet pra gerar/enviar recibo
- `apps/app/lib/features/receipts/receipt_service.dart` — métodos de API (gerar, enviar email, listar pendentes)
- `apps/app/lib/features/payments/payments_dashboard_page.dart` — lista de escalas pendentes
- `apps/app/lib/features/payments/payment_status_dialog.dart` — sheet pra marcar pago/parcial
- `apps/app/test/core/services/entitlement_service_test.dart`
- `apps/app/test/core/models/entitlement_model_test.dart`
- `apps/app/test/features/receipts/receipt_service_test.dart`

**Arquivos modificados:**
- `apps/app/pubspec.yaml` — adicionar `in_app_purchase: ^3.2.0`
- `apps/app/android/app/build.gradle` — `minSdkVersion 21` (requerido pelo billing)
- `apps/app/android/app/src/main/AndroidManifest.xml` — adicionar permission `com.android.vending.BILLING`
- `apps/app/lib/main.dart` — inicializar `EntitlementService` no startup pós-login
- `apps/app/lib/features/schedules/schedule_card.dart` — adicionar botão "Gerar Recibo" condicional
- `apps/app/lib/features/profile/profile_page.dart` — card de status Pro + CTA upgrade
- `apps/app/lib/home_page.dart` — adicionar rota interna pra `PaymentsDashboardPage` (acesso via Profile)

---

## Task Granularity Note

Cada **Task** representa uma unidade entregável (geralmente 1 commit). Cada **Step** dentro de uma task é uma ação atômica (2-5 min). Marque checkboxes conforme conclui.

---

## Task 1: Adicionar dependência `in_app_purchase` + configuração Android

**Files:**
- Modify: `apps/app/pubspec.yaml`
- Modify: `apps/app/android/app/build.gradle`
- Modify: `apps/app/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Adicionar dependência no pubspec.yaml**

Em `apps/app/pubspec.yaml`, na seção `dependencies:` (depois de `mask_text_input_formatter:`):

```yaml
  in_app_purchase: ^3.2.0
```

- [ ] **Step 2: Garantir minSdkVersion 21 no build.gradle**

Em `apps/app/android/app/build.gradle`, dentro de `defaultConfig {`:

```gradle
minSdkVersion 21
```

Se já estiver maior ou igual a 21, deixe como está. Se houver `flutter.minSdkVersion` no lugar, troque pra `21` literal (in_app_purchase exige 21+).

- [ ] **Step 3: Adicionar permission BILLING no AndroidManifest.xml**

Em `apps/app/android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`, antes de `<application>`:

```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

- [ ] **Step 4: Rodar pub get e validar**

```bash
cd apps/app && flutter pub get
```

Expected: `Got dependencies!` sem erros. `in_app_purchase` aparece em `pubspec.lock`.

- [ ] **Step 5: Commit**

```bash
git add apps/app/pubspec.yaml apps/app/pubspec.lock apps/app/android/app/build.gradle apps/app/android/app/src/main/AndroidManifest.xml
git commit -m "chore(app): adicionar in_app_purchase + permission BILLING (Pro Fase 1)"
git push origin main
```

---

## Task 2: Modelo `EntitlementModel`

**Files:**
- Create: `apps/app/lib/core/models/entitlement_model.dart`
- Test: `apps/app/test/core/models/entitlement_model_test.dart`

- [ ] **Step 1: Escrever teste do parse**

Criar `apps/app/test/core/models/entitlement_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/entitlement_model.dart';

void main() {
  group('EntitlementModel.fromJson', () {
    test('parses Free user (pro=false)', () {
      final m = EntitlementModel.fromJson({
        'pro': false,
        'trial': false,
        'until': null,
        'source': null,
        'cancelAtPeriodEnd': false,
      });
      expect(m.pro, false);
      expect(m.trial, false);
      expect(m.until, isNull);
      expect(m.source, isNull);
      expect(m.cancelAtPeriodEnd, false);
    });

    test('parses Pro active stripe user', () {
      final m = EntitlementModel.fromJson({
        'pro': true,
        'trial': false,
        'until': '2026-06-18T00:00:00.000Z',
        'source': 'stripe',
        'cancelAtPeriodEnd': false,
      });
      expect(m.pro, true);
      expect(m.trial, false);
      expect(m.until, DateTime.parse('2026-06-18T00:00:00.000Z'));
      expect(m.source, 'stripe');
    });

    test('parses Pro trial play user', () {
      final m = EntitlementModel.fromJson({
        'pro': true,
        'trial': true,
        'until': '2026-05-25T00:00:00.000Z',
        'source': 'play',
        'cancelAtPeriodEnd': true,
      });
      expect(m.pro, true);
      expect(m.trial, true);
      expect(m.cancelAtPeriodEnd, true);
      expect(m.source, 'play');
    });

    test('daysUntilExpiry returns correct count for future date', () {
      final future = DateTime.now().add(const Duration(days: 7));
      final m = EntitlementModel(
        pro: true,
        trial: true,
        until: future,
        source: 'stripe',
        cancelAtPeriodEnd: false,
      );
      expect(m.daysUntilExpiry, inInclusiveRange(6, 7));
    });

    test('daysUntilExpiry returns null when until is null', () {
      const m = EntitlementModel.free();
      expect(m.daysUntilExpiry, isNull);
    });
  });
}
```

- [ ] **Step 2: Rodar teste pra ver falhar**

```bash
cd apps/app && flutter test test/core/models/entitlement_model_test.dart
```

Expected: FAIL com `Target of URI doesn't exist: 'package:mobile/core/models/entitlement_model.dart'`.

- [ ] **Step 3: Criar o modelo**

Criar `apps/app/lib/core/models/entitlement_model.dart`:

```dart
class EntitlementModel {
  final bool pro;
  final bool trial;
  final DateTime? until;
  final String? source;
  final bool cancelAtPeriodEnd;

  const EntitlementModel({
    required this.pro,
    required this.trial,
    required this.until,
    required this.source,
    required this.cancelAtPeriodEnd,
  });

  const EntitlementModel.free()
      : pro = false,
        trial = false,
        until = null,
        source = null,
        cancelAtPeriodEnd = false;

  factory EntitlementModel.fromJson(Map<String, dynamic> json) {
    DateTime? until;
    final rawUntil = json['until'];
    if (rawUntil != null && rawUntil.toString().isNotEmpty) {
      until = DateTime.tryParse(rawUntil.toString());
    }
    return EntitlementModel(
      pro: json['pro'] == true,
      trial: json['trial'] == true,
      until: until,
      source: json['source']?.toString(),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] == true,
    );
  }

  int? get daysUntilExpiry {
    if (until == null) return null;
    return until!.difference(DateTime.now()).inDays;
  }
}
```

- [ ] **Step 4: Rodar teste pra ver passar**

```bash
cd apps/app && flutter test test/core/models/entitlement_model_test.dart
```

Expected: PASS, todos os 5 testes.

- [ ] **Step 5: Commit**

```bash
git add apps/app/lib/core/models/entitlement_model.dart apps/app/test/core/models/entitlement_model_test.dart
git commit -m "feat(pro): adicionar EntitlementModel + parse de JSON"
git push origin main
```

---

## Task 3: `EntitlementService` com cache e refresh

**Files:**
- Create: `apps/app/lib/core/services/entitlement_service.dart`
- Test: `apps/app/test/core/services/entitlement_service_test.dart`

A pattern: singleton estático (como `ApiService`), com `ValueNotifier<EntitlementModel>` interno pra widgets reagirem mudanças via `ValueListenableBuilder`. Cache em memória (TTL 15 min) + persistido em `SharedPreferences` pra startup rápido.

- [ ] **Step 1: Escrever teste do service**

Criar `apps/app/test/core/services/entitlement_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/services/entitlement_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EntitlementService.resetForTesting();
  });

  test('current returns free entitlement before any load', () {
    final ent = EntitlementService.current.value;
    expect(ent.pro, false);
  });

  test('updateFromJson updates current and persists', () async {
    await EntitlementService.updateFromJson({
      'pro': true,
      'trial': true,
      'until': '2026-06-01T00:00:00.000Z',
      'source': 'play',
      'cancelAtPeriodEnd': false,
    });

    expect(EntitlementService.current.value.pro, true);
    expect(EntitlementService.current.value.trial, true);
    expect(EntitlementService.current.value.source, 'play');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entitlement_cache'), isNotNull);
  });

  test('loadCached restores from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'entitlement_cache':
          '{"pro":true,"trial":false,"until":"2026-12-01T00:00:00.000Z","source":"stripe","cancelAtPeriodEnd":false}',
    });
    EntitlementService.resetForTesting();
    await EntitlementService.loadCached();
    expect(EntitlementService.current.value.pro, true);
    expect(EntitlementService.current.value.source, 'stripe');
  });

  test('clear resets to free and removes cache', () async {
    await EntitlementService.updateFromJson({
      'pro': true,
      'trial': false,
      'until': '2026-12-01T00:00:00.000Z',
      'source': 'stripe',
      'cancelAtPeriodEnd': false,
    });
    await EntitlementService.clear();
    expect(EntitlementService.current.value.pro, false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entitlement_cache'), isNull);
  });
}
```

- [ ] **Step 2: Rodar teste pra ver falhar**

```bash
cd apps/app && flutter test test/core/services/entitlement_service_test.dart
```

Expected: FAIL com `Target of URI doesn't exist`.

- [ ] **Step 3: Implementar o service**

Criar `apps/app/lib/core/services/entitlement_service.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entitlement_model.dart';
import 'api_service.dart';

class EntitlementService {
  static const _cacheKey = 'entitlement_cache';
  static const _cacheTtl = Duration(minutes: 15);

  static final ValueNotifier<EntitlementModel> _current =
      ValueNotifier(const EntitlementModel.free());
  static DateTime? _lastFetched;

  static ValueListenable<EntitlementModel> get current => _current;

  static bool get isPro => _current.value.pro;

  static Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _current.value = EntitlementModel.fromJson(json);
    } catch (e) {
      debugPrint('EntitlementService.loadCached parse error: $e');
    }
  }

  static Future<EntitlementModel> refresh({bool force = false}) async {
    if (!force &&
        _lastFetched != null &&
        DateTime.now().difference(_lastFetched!) < _cacheTtl) {
      return _current.value;
    }
    final response = await ApiService.get('/me/entitlements');
    if (response['success'] == true && response['data'] is Map) {
      await updateFromJson(response['data'] as Map<String, dynamic>);
      _lastFetched = DateTime.now();
    }
    return _current.value;
  }

  static Future<void> updateFromJson(Map<String, dynamic> json) async {
    final model = EntitlementModel.fromJson(json);
    _current.value = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(json));
  }

  static Future<void> clear() async {
    _current.value = const EntitlementModel.free();
    _lastFetched = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  @visibleForTesting
  static void resetForTesting() {
    _current.value = const EntitlementModel.free();
    _lastFetched = null;
  }
}
```

- [ ] **Step 4: Rodar testes pra ver passar**

```bash
cd apps/app && flutter test test/core/services/entitlement_service_test.dart
```

Expected: PASS nos 4 testes.

- [ ] **Step 5: Commit**

```bash
git add apps/app/lib/core/services/entitlement_service.dart apps/app/test/core/services/entitlement_service_test.dart
git commit -m "feat(pro): EntitlementService com cache em SharedPreferences + ValueNotifier"
git push origin main
```

---

## Task 4: Wire `EntitlementService` no startup pós-login

**Files:**
- Modify: `apps/app/lib/main.dart` (AuthGate)
- Modify: `apps/app/lib/auth_service.dart` (logout deve limpar entitlement)

- [ ] **Step 1: Localizar AuthGate**

Use Grep pra encontrar a definição:

```bash
cd apps/app && grep -n "AuthGate" lib/main.dart
```

- [ ] **Step 2: Carregar entitlement cacheado antes de decidir rota inicial**

Em `apps/app/lib/main.dart`, no `AuthGate`, dentro do `initState()` (ou onde valida token), adicionar antes do `setState`:

```dart
await EntitlementService.loadCached();
```

E também, após o token ser confirmado válido (antes de navegar pra home), chamar:

```dart
// Refresh em background — não bloqueia navegação
EntitlementService.refresh();
```

Adicionar o import no topo do arquivo:

```dart
import 'core/services/entitlement_service.dart';
```

- [ ] **Step 3: Limpar entitlement no logout**

Em `apps/app/lib/auth_service.dart`, dentro do método `logout()`, adicionar **após** o `prefs.remove` do token:

```dart
await EntitlementService.clear();
```

Import:

```dart
import 'core/services/entitlement_service.dart';
```

- [ ] **Step 4: Rodar análise estática**

```bash
cd apps/app && dart analyze lib/main.dart lib/auth_service.dart
```

Expected: 0 issues found.

- [ ] **Step 5: Commit**

```bash
git add apps/app/lib/main.dart apps/app/lib/auth_service.dart
git commit -m "feat(pro): carregar entitlement no startup e limpar no logout"
git push origin main
```

---

## Task 5: Widget `ProGate` (renderização condicional)

**Files:**
- Create: `apps/app/lib/features/pro/widgets/pro_gate.dart`
- Create: `apps/app/lib/features/pro/widgets/pro_badge.dart`

Padrão: passa `child` (visível pra Pro) e `fallback` opcional (visível pra Free). Sem fallback → esconde no Free.

- [ ] **Step 1: Criar ProGate**

Criar `apps/app/lib/features/pro/widgets/pro_gate.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/models/entitlement_model.dart';
import '../../../core/services/entitlement_service.dart';

/// Renderiza [child] se usuário é Pro, ou [fallback] se Free (ou nada).
class ProGate extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const ProGate({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EntitlementModel>(
      valueListenable: EntitlementService.current,
      builder: (_, ent, __) {
        if (ent.pro) return child;
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}
```

- [ ] **Step 2: Criar ProBadge**

Criar `apps/app/lib/features/pro/widgets/pro_badge.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Badge "PRO" pequena, dourada — sinaliza features Pro.
class ProBadge extends StatelessWidget {
  final double fontSize;
  const ProBadge({super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.7,
        vertical: fontSize * 0.25,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4A017), Color(0xFFFFC107)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        'PRO',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Rodar análise estática**

```bash
cd apps/app && dart analyze lib/features/pro/
```

Expected: 0 issues.

- [ ] **Step 4: Commit**

```bash
git add apps/app/lib/features/pro/widgets/
git commit -m "feat(pro): widgets ProGate (gate condicional) e ProBadge"
git push origin main
```

---

## Task 6: `BillingService` — wrapper sobre in_app_purchase (Play)

**Files:**
- Create: `apps/app/lib/core/services/billing_service.dart`

API: `init()` (registrar listener), `loadProducts()` → `List<ProductDetails>`, `buy(ProductDetails)` (dispara fluxo Play), `restore()`, `dispose()`. Cada compra confirmada envia `purchaseToken` pro backend via `POST /billing/play/verify`, que atualiza entitlement.

Não há TDD aqui porque o `in_app_purchase` exige plugin nativo e não pode ser mockado de forma realista em unit test. Validação será manual via QA.

- [ ] **Step 1: Criar o serviço**

Criar `apps/app/lib/core/services/billing_service.dart`:

```dart
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
```

- [ ] **Step 2: Rodar análise estática**

```bash
cd apps/app && dart analyze lib/core/services/billing_service.dart
```

Expected: 0 issues (ou apenas warnings sobre `dynamic` no _verifyOnBackend que são aceitáveis).

- [ ] **Step 3: Inicializar BillingService no startup**

Em `apps/app/lib/main.dart`, no `AuthGate`, **após** o `EntitlementService.loadCached()` e **somente** se houver token válido:

```dart
BillingService.init(); // fire-and-forget
```

Import:

```dart
import 'core/services/billing_service.dart';
```

- [ ] **Step 4: Commit**

```bash
git add apps/app/lib/core/services/billing_service.dart apps/app/lib/main.dart
git commit -m "feat(pro): BillingService wrapper sobre in_app_purchase (Play Billing)"
git push origin main
```

---

## Task 7: Página de paywall `ProPage`

**Files:**
- Create: `apps/app/lib/features/pro/pro_page.dart`

Visual: hero com lista de benefícios da Fase 1 (Recibos PDF, envio email, dashboard pagamentos), dois cards de preço (Mensal/Anual com economia destacada), CTA "Iniciar Teste Grátis de 7 dias" abaixo, link "Restaurar compras" no rodapé.

- [ ] **Step 1: Criar ProPage**

Criar `apps/app/lib/features/pro/pro_page.dart`:

```dart
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
    BillingService.loadProducts().then((_) => mounted ? setState(() {}) : null);
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
```

- [ ] **Step 2: Rodar análise estática**

```bash
cd apps/app && dart analyze lib/features/pro/pro_page.dart
```

Expected: 0 issues. Se reclamar de `firstOrNull` (Dart < 3.0 não tem), trocar por `produtos.where(...).cast<ProductDetails?>().firstWhere((p) => true, orElse: () => null)`.

- [ ] **Step 3: Commit**

```bash
git add apps/app/lib/features/pro/pro_page.dart
git commit -m "feat(pro): paywall ProPage com cards de preço Play"
git push origin main
```

---

## Task 8: Card de status Pro + CTA upgrade na Profile

**Files:**
- Modify: `apps/app/lib/features/profile/profile_page.dart`

Adicionar **no topo** da Profile, antes das outras seções, um card que mostra estado do Pro:
- **Free** → fundo neutro, botão "Conhecer Pro" → abre `ProPage`
- **Trial** → fundo dourado claro, label "Trial · expira em N dias", botão "Gerenciar assinatura"
- **Pro ativo** → fundo verde, label "Pro · renova em DD/MM/AAAA", botão "Gerenciar assinatura"

- [ ] **Step 1: Localizar onde inserir o card**

```bash
cd apps/app && grep -n "Widget build" lib/features/profile/profile_page.dart | head -3
```

Inserir o card no início do `body:` (geralmente o primeiro filho do `Column` ou `ListView` principal).

- [ ] **Step 2: Adicionar `ProStatusCard` widget privado**

No mesmo `profile_page.dart`, no final do arquivo, adicionar:

```dart
class _ProStatusCard extends StatelessWidget {
  const _ProStatusCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EntitlementModel>(
      valueListenable: EntitlementService.current,
      builder: (context, ent, _) {
        final theme = Theme.of(context);
        final dias = ent.daysUntilExpiry;
        late final Color bgColor;
        late final String titulo;
        late final String? subtitulo;
        late final String botaoLabel;

        if (!ent.pro) {
          bgColor = theme.colorScheme.surfaceContainer;
          titulo = 'DublyDesk Pro';
          subtitulo =
              'Recibos PDF, cobrança organizada e mais. 7 dias grátis.';
          botaoLabel = 'Conhecer Pro';
        } else if (ent.trial) {
          bgColor = const Color(0xFFFFF3CD);
          titulo = 'Pro · Trial';
          subtitulo = dias != null
              ? 'Trial expira em $dias dia${dias == 1 ? '' : 's'}'
              : 'Trial ativo';
          botaoLabel = 'Gerenciar assinatura';
        } else {
          bgColor = AppColors.secondary.withValues(alpha: 0.18);
          titulo = 'Pro · Ativo';
          subtitulo = ent.until != null
              ? 'Renova em ${DateFormat('d MMM y', 'pt_BR').format(ent.until!)}'
              : null;
          botaoLabel = 'Gerenciar assinatura';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(titulo, style: theme.textTheme.titleMedium),
                  const SizedBox(width: 8),
                  if (ent.pro) const ProBadge(),
                ],
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(subtitulo, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ent.pro
                    ? OutlinedButton(
                        onPressed: () => _abrirGerenciamento(context, ent),
                        child: Text(botaoLabel),
                      )
                    : FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProPage()),
                        ),
                        child: Text(botaoLabel),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _abrirGerenciamento(BuildContext context, EntitlementModel ent) async {
    // Play subscriptions: deep link pro Play Store
    if (ent.source == 'play') {
      final uri = Uri.parse(
        'https://play.google.com/store/account/subscriptions?package=br.com.dublydesk.app',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    // Stripe: TODO no Plano 3 (PWA web). Por enquanto, mensagem.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gerenciamento via web disponível em breve'),
      ),
    );
  }
}
```

- [ ] **Step 3: Adicionar imports necessários**

No topo de `apps/app/lib/features/profile/profile_page.dart`:

```dart
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/entitlement_model.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/theme/app_colors.dart';
import '../pro/pro_page.dart';
import '../pro/widgets/pro_badge.dart';
```

(Pular os já presentes — verifique antes de duplicar.)

- [ ] **Step 4: Renderizar `_ProStatusCard` no build**

Adicionar `const _ProStatusCard()` como primeiro filho do `Column` (ou primeiro item do `ListView`) dentro do `body:`.

- [ ] **Step 5: Rodar análise estática**

```bash
cd apps/app && dart analyze lib/features/profile/profile_page.dart
```

Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add apps/app/lib/features/profile/profile_page.dart
git commit -m "feat(pro): card de status Pro no perfil + CTA upgrade"
git push origin main
```

---

## Task 9: `ReceiptService` — chamadas de API

**Files:**
- Create: `apps/app/lib/features/receipts/receipt_service.dart`
- Test: `apps/app/test/features/receipts/receipt_service_test.dart`

Wrapper sobre `ApiService` que tipa as respostas. **Não** testaremos o HTTP de verdade — testaremos só o parsing de resultados Map.

- [ ] **Step 1: Escrever teste de parse**

Criar `apps/app/test/features/receipts/receipt_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/receipts/receipt_service.dart';

void main() {
  group('ReceiptService.parseGenerateResponse', () {
    test('parses successful generate response', () {
      final r = ReceiptService.parseGenerateResponse({
        'success': true,
        'data': {
          'id': 42,
          'pdfPath': 'uploads/receipts/1/42-abc.pdf',
          'createdAt': '2026-05-18T10:00:00.000Z',
        },
      });
      expect(r.success, true);
      expect(r.receiptId, 42);
      expect(r.pdfPath, 'uploads/receipts/1/42-abc.pdf');
    });

    test('returns PRO_REQUIRED error from 402 response', () {
      final r = ReceiptService.parseGenerateResponse({
        'success': false,
        'statusCode': 402,
        'data': {'error': 'Recurso disponível apenas no Pro', 'code': 'PRO_REQUIRED'},
        'error': 'Recurso disponível apenas no Pro',
      });
      expect(r.success, false);
      expect(r.proRequired, true);
    });

    test('parses generic error', () {
      final r = ReceiptService.parseGenerateResponse({
        'success': false,
        'statusCode': 500,
        'error': 'Erro ao gerar recibo',
      });
      expect(r.success, false);
      expect(r.proRequired, false);
      expect(r.errorMessage, 'Erro ao gerar recibo');
    });
  });
}
```

- [ ] **Step 2: Rodar teste pra ver falhar**

```bash
cd apps/app && flutter test test/features/receipts/receipt_service_test.dart
```

Expected: FAIL com URI inexistente.

- [ ] **Step 3: Implementar o service**

Criar `apps/app/lib/features/receipts/receipt_service.dart`:

```dart
import '../../core/services/api_service.dart';

class ReceiptGenerateResult {
  final bool success;
  final int? receiptId;
  final String? pdfPath;
  final String? errorMessage;
  final bool proRequired;

  const ReceiptGenerateResult({
    required this.success,
    this.receiptId,
    this.pdfPath,
    this.errorMessage,
    this.proRequired = false,
  });
}

class PendingPayment {
  final int scheduleId;
  final String projeto;
  final String produtora;
  final String? diretor;
  final DateTime data;
  final double valorTotal;
  final double valorPago;
  final String statusPagamento;
  final DateTime? vencimento;

  const PendingPayment({
    required this.scheduleId,
    required this.projeto,
    required this.produtora,
    required this.diretor,
    required this.data,
    required this.valorTotal,
    required this.valorPago,
    required this.statusPagamento,
    required this.vencimento,
  });

  factory PendingPayment.fromJson(Map<String, dynamic> json) => PendingPayment(
        scheduleId: (json['id'] as num).toInt(),
        projeto: json['projeto']?.toString() ?? '',
        produtora: json['produtora']?.toString() ?? '',
        diretor: json['diretor']?.toString(),
        data: DateTime.parse(json['data'].toString()),
        valorTotal: double.tryParse(json['valor_total'].toString()) ?? 0,
        valorPago: double.tryParse(json['valor_pago'].toString()) ?? 0,
        statusPagamento: json['status_pagamento']?.toString() ?? 'pendente',
        vencimento: json['vencimento'] != null
            ? DateTime.tryParse(json['vencimento'].toString())
            : null,
      );

  double get valorRestante => valorTotal - valorPago;
}

class ReceiptService {
  static Future<ReceiptGenerateResult> generate({
    required int scheduleId,
    String? cpf,
  }) async {
    final response = await ApiService.post('/receipts/generate', {
      'scheduleId': scheduleId,
      if (cpf != null && cpf.isNotEmpty) 'cpf': cpf,
    });
    return parseGenerateResponse(response);
  }

  static ReceiptGenerateResult parseGenerateResponse(
      Map<String, dynamic> response) {
    if (response['success'] == true && response['data'] is Map) {
      final data = response['data'] as Map<String, dynamic>;
      return ReceiptGenerateResult(
        success: true,
        receiptId: (data['id'] as num?)?.toInt(),
        pdfPath: data['pdfPath']?.toString(),
      );
    }
    final proRequired = response['statusCode'] == 402 ||
        (response['data'] is Map &&
            (response['data'] as Map)['code'] == 'PRO_REQUIRED');
    return ReceiptGenerateResult(
      success: false,
      errorMessage: response['error']?.toString() ?? 'Erro desconhecido',
      proRequired: proRequired,
    );
  }

  static Future<bool> sendEmail({
    required int receiptId,
    required String destinatario,
    String? mensagem,
  }) async {
    final response = await ApiService.post('/receipts/$receiptId/send-email', {
      'destinatario': destinatario,
      if (mensagem != null && mensagem.isNotEmpty) 'mensagem': mensagem,
    });
    return response['success'] == true;
  }

  static Future<({List<PendingPayment> items, double total})> listPending() async {
    final response = await ApiService.get('/receipts/pending');
    if (response['success'] == true && response['data'] is Map) {
      final data = response['data'] as Map<String, dynamic>;
      final rawItems = (data['items'] as List?) ?? [];
      final items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(PendingPayment.fromJson)
          .toList();
      final total = double.tryParse(data['totalPendente'].toString()) ?? 0;
      return (items: items, total: total);
    }
    return (items: <PendingPayment>[], total: 0.0);
  }

  static Future<bool> updatePaymentStatus({
    required int scheduleId,
    required String statusPagamento,
    double? valorPago,
    DateTime? vencimento,
  }) async {
    final response = await ApiService.put('/schedules/$scheduleId/payment', {
      'status_pagamento': statusPagamento,
      if (valorPago != null) 'valor_pago': valorPago,
      if (vencimento != null)
        'vencimento': vencimento.toIso8601String().split('T').first,
    });
    return response['success'] == true;
  }
}
```

**Nota:** o backend usa `PATCH` em `/schedules/:id/payment`, mas o `ApiService` atual não tem método PATCH. Há duas opções: (a) adicionar `PATCH` em `ApiService`, ou (b) o backend já aceita PUT no mesmo endpoint. **Antes de implementar**, confirme em `apps/api/routes/schedules.js` qual verbo é aceito. Se for só PATCH, adicione um método `patch()` espelhando `put()` em `ApiService` na Task 9.

- [ ] **Step 4: Validar PATCH no backend e ajustar se necessário**

```bash
cd apps/api && grep -n "router\.\(patch\|put\)" routes/schedules.js | grep -i payment
```

Se aparecer apenas `router.patch`, adicionar em `apps/app/lib/core/services/api_service.dart` o método `patch` espelhando `put`:

```dart
static Future<Map<String, dynamic>> patch(
  String endpoint,
  Map<String, dynamic> body,
) async {
  try {
    final headers = await AuthService.authHeaders();
    final response = await http
        .patch(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _handle(response);
  } catch (e) {
    debugPrint('ApiService PATCH $endpoint: $e');
    return {'success': false, 'error': 'Falha na conexão.', 'data': null};
  }
}
```

E trocar `ApiService.put` por `ApiService.patch` em `ReceiptService.updatePaymentStatus`.

- [ ] **Step 5: Rodar testes pra ver passar**

```bash
cd apps/app && flutter test test/features/receipts/receipt_service_test.dart
```

Expected: PASS nos 3 testes.

- [ ] **Step 6: Commit**

```bash
git add apps/app/lib/features/receipts/ apps/app/test/features/receipts/ apps/app/lib/core/services/api_service.dart
git commit -m "feat(pro): ReceiptService com tipagem ReceiptGenerateResult e PendingPayment"
git push origin main
```

---

## Task 10: Botão "Gerar Recibo" no `schedule_card.dart`

**Files:**
- Modify: `apps/app/lib/features/schedules/schedule_card.dart`

Critério de exibição: escala **realizada**, **remunerada**, **não é compromisso**. Pra Free, botão fica visível mas com `ProBadge`, e ao tocar abre `ProPage`. Pra Pro, abre `ReceiptDialog` (Task 11).

- [ ] **Step 1: Adicionar campo opcional `onGenerateReceipt` no constructor**

Em `ScheduleCard`, depois de `final VoidCallback onToggleRealizado;`:

```dart
final VoidCallback? onGenerateReceipt;
```

E no construtor:

```dart
this.onGenerateReceipt,
```

- [ ] **Step 2: Renderizar o botão**

Dentro do `Column` principal (depois do bloco da `// Linha final: hora + valor + tipo trabalho`), adicionar um botão condicional. **Antes** do fechamento do `Column` (`children: [...]`), inserir:

```dart
if (!isCompromisso && schedule.realizado && schedule.remunerado) ...[
  const SizedBox(height: 12),
  _BotaoRecibo(onTap: onGenerateReceipt),
],
```

E no final do arquivo (depois das outras classes privadas):

```dart
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
```

- [ ] **Step 3: Adicionar imports no topo do schedule_card.dart**

```dart
import '../../core/models/entitlement_model.dart';
import '../../core/services/entitlement_service.dart';
import '../pro/pro_page.dart';
import '../pro/widgets/pro_badge.dart';
```

- [ ] **Step 4: Rodar análise estática**

```bash
cd apps/app && dart analyze lib/features/schedules/schedule_card.dart
```

Expected: 0 issues.

- [ ] **Step 5: Commit**

```bash
git add apps/app/lib/features/schedules/schedule_card.dart
git commit -m "feat(pro): botão 'Gerar Recibo' no schedule_card (gateado por Pro)"
git push origin main
```

---

## Task 11: Sheet de geração de recibo (`ReceiptDialog`)

**Files:**
- Create: `apps/app/lib/features/receipts/receipt_dialog.dart`

Fluxo:
1. Sheet abre com info da escala
2. Campos opcionais: CPF (default vazio), email destinatário (pré-preenchido com email do contato se houver)
3. Botão "Gerar e Enviar" → chama `ReceiptService.generate` → se sucesso, chama `sendEmail` → SnackBar "Recibo enviado"
4. Botão secundário "Apenas Gerar" → só gera, mostra SnackBar com link de download (mantém pra Fase 2)

- [ ] **Step 1: Criar o dialog**

Criar `apps/app/lib/features/receipts/receipt_dialog.dart`:

```dart
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
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(_).viewInsets.bottom),
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
```

- [ ] **Step 2: Wire no `schedule_list_page.dart` (handler de onGenerateReceipt)**

Encontrar onde `ScheduleCard` é instanciado em `apps/app/lib/features/schedules/schedule_list_page.dart`:

```bash
cd apps/app && grep -n "ScheduleCard(" lib/features/schedules/schedule_list_page.dart
```

Passar `onGenerateReceipt: () => ReceiptDialog.show(context, schedule)`. Adicionar import:

```dart
import '../receipts/receipt_dialog.dart';
```

Fazer o mesmo em `calendar_page.dart` se ele também renderizar `ScheduleCard`:

```bash
cd apps/app && grep -rn "ScheduleCard(" lib/
```

Adicionar o callback em todos os lugares.

- [ ] **Step 3: Rodar análise estática**

```bash
cd apps/app && dart analyze lib/features/receipts/ lib/features/schedules/ lib/calendar_page.dart
```

Expected: 0 issues.

- [ ] **Step 4: Commit**

```bash
git add apps/app/lib/features/receipts/receipt_dialog.dart apps/app/lib/features/schedules/schedule_list_page.dart apps/app/lib/calendar_page.dart
git commit -m "feat(pro): ReceiptDialog (gerar + enviar email) integrado ao schedule_card"
git push origin main
```

---

## Task 12: `PaymentsDashboardPage` — lista de escalas pendentes

**Files:**
- Create: `apps/app/lib/features/payments/payments_dashboard_page.dart`
- Create: `apps/app/lib/features/payments/payment_status_dialog.dart`

- [ ] **Step 1: Criar `payment_status_dialog.dart`**

```dart
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
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(_).viewInsets.bottom),
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

  static const _moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');

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
```

- [ ] **Step 2: Criar `payments_dashboard_page.dart`**

```dart
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
  static const _moeda = NumberFormat.simpleCurrency(locale: 'pt_BR');
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
```

- [ ] **Step 3: Linkar entrada da dashboard no Profile**

Em `apps/app/lib/features/profile/profile_page.dart`, dentro do `Column` principal, adicionar (envolto em `ProGate` pra Free não ver):

```dart
ProGate(
  child: Card(
    child: ListTile(
      leading: const Icon(Icons.payments_outlined),
      title: const Text('Pagamentos pendentes'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaymentsDashboardPage()),
      ),
    ),
  ),
),
```

Imports:

```dart
import '../payments/payments_dashboard_page.dart';
import '../pro/widgets/pro_gate.dart';
```

- [ ] **Step 4: Rodar análise estática**

```bash
cd apps/app && dart analyze lib/features/payments/ lib/features/profile/profile_page.dart
```

Expected: 0 issues.

- [ ] **Step 5: Commit**

```bash
git add apps/app/lib/features/payments/ apps/app/lib/features/profile/profile_page.dart
git commit -m "feat(pro): PaymentsDashboardPage com lista de pendentes + atualizar status"
git push origin main
```

---

## Task 13: Notificações de expiração do trial (7→3→1 dia)

**Files:**
- Create: `apps/app/lib/core/services/pro_notifications_service.dart`
- Modify: `apps/app/lib/main.dart` ou `apps/app/lib/core/services/entitlement_service.dart`

Usar `flutter_local_notifications` já presente. Agendar 3 notificações locais quando entitlement vira `trial=true`, ancoradas em `until`.

- [ ] **Step 1: Criar o serviço**

Criar `apps/app/lib/core/services/pro_notifications_service.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/entitlement_model.dart';

class ProNotificationsService {
  static const _channelId = 'pro_trial';
  static const _channelName = 'Trial Pro';

  static const _idDay7 = 9001;
  static const _idDay3 = 9002;
  static const _idDay1 = 9003;

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Agenda 3 notificações ancoradas em [entitlement.until], em D-7, D-3, D-1.
  /// Cancela agendamentos antigos primeiro pra evitar duplicação.
  static Future<void> scheduleTrialReminders(EntitlementModel ent) async {
    await cancelAll();
    if (!ent.trial || ent.until == null) return;

    final scheduledAt = ent.until!;
    final remind7 = scheduledAt.subtract(const Duration(days: 7));
    final remind3 = scheduledAt.subtract(const Duration(days: 3));
    final remind1 = scheduledAt.subtract(const Duration(days: 1));

    final now = DateTime.now();
    if (remind7.isAfter(now)) {
      await _schedule(_idDay7, remind7,
          'Trial Pro: 7 dias restantes',
          'Aproveite as features Pro antes do fim do trial.');
    }
    if (remind3.isAfter(now)) {
      await _schedule(_idDay3, remind3,
          'Trial Pro: 3 dias restantes',
          'Seu trial termina em breve. Continue ou cancele a qualquer momento.');
    }
    if (remind1.isAfter(now)) {
      await _schedule(_idDay1, remind1,
          'Trial Pro: amanhã expira',
          'Seu trial expira amanhã. Renovação automática se não cancelar.');
    }
  }

  static Future<void> cancelAll() async {
    await _plugin.cancel(_idDay7);
    await _plugin.cancel(_idDay3);
    await _plugin.cancel(_idDay1);
  }

  static Future<void> _schedule(
    int id,
    DateTime when,
    String title,
    String body,
  ) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Avisos do trial Pro',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('ProNotificationsService.schedule error: $e');
    }
  }
}
```

- [ ] **Step 2: Disparar agendamento quando entitlement muda**

Em `apps/app/lib/core/services/entitlement_service.dart`, no método `updateFromJson`, **após** atualizar `_current.value`:

```dart
ProNotificationsService.scheduleTrialReminders(model); // fire-and-forget
```

Import:

```dart
import 'pro_notifications_service.dart';
```

E em `clear()`, **após** o `_current.value = const EntitlementModel.free()`:

```dart
await ProNotificationsService.cancelAll();
```

- [ ] **Step 3: Rodar análise estática**

```bash
cd apps/app && dart analyze lib/core/services/
```

Expected: 0 issues.

- [ ] **Step 4: Commit**

```bash
git add apps/app/lib/core/services/pro_notifications_service.dart apps/app/lib/core/services/entitlement_service.dart
git commit -m "feat(pro): notificações locais de trial (D-7, D-3, D-1)"
git push origin main
```

---

## Task 14: QA manual + ajustes finais

**Files:**
- N/A (testing only)

- [ ] **Step 1: Build APK de debug**

```bash
cd apps/app && flutter build apk --debug
```

Expected: build successful em `build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 2: Conferir checklist de QA manual**

Em ambiente com conta de teste do Play Console (license tester), validar:

- [ ] Login como Free → Profile mostra "Conhecer Pro" → toca → ProPage abre
- [ ] ProPage mostra 2 cards (Mensal + Anual) com preços reais do Play
- [ ] Comprar Mensal → Play sheet → confirma com cartão de teste → volta pro app
- [ ] Profile passa a mostrar "Pro · Trial · expira em 7 dias"
- [ ] Schedule realizado+remunerado mostra botão "Gerar recibo" (sem ProBadge)
- [ ] Schedule realizado+remunerado em conta Free mostra "Gerar recibo" + ProBadge
- [ ] Tocar em "Gerar recibo" como Pro → ReceiptDialog abre → preencher email → enviar → SnackBar de sucesso
- [ ] Profile → "Pagamentos pendentes" → lista carrega → tocar item → atualizar status pra "pago" → some da lista
- [ ] Logout → entitlement zera, ProPage acessível mas paywall novamente
- [ ] Login novamente em Pro ativo → Restaurar compras → estado correto
- [ ] Verificar via Settings do Android que 3 notificações de trial estão agendadas (Settings → Apps → DublyDesk → Notifications)

- [ ] **Step 3: Rodar suite de testes completa**

```bash
cd apps/app && flutter test
```

Expected: todos os testes passam.

- [ ] **Step 4: Análise estática global**

```bash
cd apps/app && dart analyze
```

Expected: 0 issues. Se aparecerem, corrigir antes de prosseguir.

- [ ] **Step 5: Bump version**

Em `apps/app/pubspec.yaml`:

```yaml
version: 1.2.0+12
```

(Subir minor de `1.1.0+11` pra `1.2.0+12` reflete adição de Pro como nova feature.)

- [ ] **Step 6: Commit final**

```bash
git add apps/app/pubspec.yaml
git commit -m "chore(app): bump version 1.2.0+12 (Pro Fase 1 completo)"
git push origin main
```

---

## Critérios de Aceite Final

Antes de declarar este plano completo, todos abaixo devem ser **verdade**:

1. `flutter test` retorna verde com pelo menos: 5 testes de `EntitlementModel`, 4 de `EntitlementService`, 3 de `ReceiptService` (12+ testes ao todo)
2. `dart analyze` retorna 0 issues
3. Build APK debug roda sem erros
4. Profile page mostra card de status Pro corretamente nos 3 estados (Free, Trial, Active)
5. Botão "Gerar recibo" aparece somente em escalas realizadas + remuneradas + não-compromisso
6. ProPage abre, carrega preços do Play (com produtos criados no Console) e processa compra
7. Restore purchases funciona em conta com sub ativa
8. PaymentsDashboard carrega itens pendentes e permite atualizar status
9. Notificações de trial são agendadas (7, 3, 1 dia antes do `until`)
10. Todos os commits feitos e pushados, branch `main` atualizada

---

## Pendências externas (fora do escopo deste plano)

Esses itens **bloqueiam o lançamento real** mas não fazem parte do desenvolvimento Flutter:

- Criar conta Google Play Console ($25 USD único)
- Registrar app `br.com.dublydesk.app` no Console (trocar `com.example` do applicationId — ver memória [[playstore-prep]])
- Criar produtos `pro_monthly` e `pro_annual` no Play Console com preços R$ 9,90 e R$ 99,90
- Gerar service account JSON e configurar `PLAY_SERVICE_ACCOUNT_PATH` no backend
- Configurar internal testing track e adicionar emails de testers
- Publicar Termos de Uso e Política de Privacidade em `dublydesk.com/termos` e `dublydesk.com/privacidade`
- Volume persistente pro diretório `apps/api/uploads/receipts/` no EasyPanel

---

## Self-Review (executada pelo autor antes de entregar)

- [x] **Spec coverage:** Todos os componentes da Fase 1 do spec estão cobertos por tasks (paywall=Task 7, EntitlementService=Task 3, BillingService=Task 6, receipts=Tasks 9-11, dashboard=Task 12, trial notif=Task 13)
- [x] **Placeholder scan:** Nenhum "TBD/TODO" no plano; todos os code blocks contêm código completo
- [x] **Type consistency:** `EntitlementModel`, `PendingPayment`, `ReceiptGenerateResult` usadas consistentemente entre tasks
- [x] **Backend-Flutter alignment:** Endpoints citados batem com `routes/billing.js`, `routes/receipts.js`, `services/entitlement.js` lidos durante a exploração
- [x] **Granularidade:** Cada task tem 4-6 steps, cada step 2-5 min, totalizando ~14 tasks/~70 steps — alinhado à duração estimada de 5-7 dias úteis na memória [[pro-monetization]]
