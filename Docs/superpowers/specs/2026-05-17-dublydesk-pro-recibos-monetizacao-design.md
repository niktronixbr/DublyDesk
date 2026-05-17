# DublyDesk Pro — Recibos & Cobrança Automatizada (MVP de Monetização)

**Data:** 2026-05-17
**Status:** Design aprovado, pendente plano de implementação
**Sessão de brainstorm:** conversa de 2026-05-17 sobre monetização e domínio próprio

## Contexto e motivação

O DublyDesk hoje é gratuito e tem todas as funcionalidades core (escalas, calendário, finance básico, conflito de horário, biometria, compromissos) já em produção. O objetivo deste design é **validar disposição de pagar** do público alvo — dubladores autônomos que usam o app pra gerir trabalho e finanças.

Estratégia escolhida: **freemium feature-gated**, mantendo todas as features atuais 100% gratuitas pra sempre (não trair a base existente) e introduzindo uma única feature paga de alto valor percebido: **Recibos & Cobrança automatizada**.

Análise e Sync Nuvem multi-dispositivo foram considerados pro MVP mas adiados pra v2/v3 do Pro após validação. Lançar uma feature por vez acelera o ciclo de feedback em 2-3x.

Critério de sucesso (90 dias pós-lançamento):
- Conversão trial→pago ≥ 30%
- Retenção em 30d ≥ 70% dos pagantes
- Se não bater: ajustar preço/copy ou repensar feature

## Escopo do produto

### Feature única: Recibos & Cobrança

**Capacidades entregues ao assinante Pro:**

1. **Geração de recibo em PDF** a partir de qualquer escala marcada como realizada
   - Dados do dublador (nome, CPF/CNPJ opcional, contato)
   - Dados da produtora (nome, projeto, diretor, data, valor)
   - Layout profissional (logo DublyDesk discreto no rodapé)
2. **Envio do recibo por email** direto pela produtora cadastrada (com cópia pro dublador)
3. **Compartilhamento por WhatsApp** via Share Sheet nativo do sistema
4. **Status de pagamento** por escala: pendente, pago, parcial, atrasado
5. **Lembretes automáticos de cobrança** via push notification (`flutter_local_notifications`)
6. **Listagem "a receber"** com totais agregados na finance_page
7. **Recibos ilimitados** — sem teto de quantidade durante a assinatura

**Capacidades NÃO incluídas no MVP (deferidas pra v2+):**
- Análise financeira avançada (projeções, ranking, comparativos)
- Sync nuvem multi-dispositivo em tempo real
- Cobrança automática via boleto/PIX (apenas envio de recibo)
- Personalização visual do recibo (logo próprio, cores)
- Múltiplas moedas, idioma diferente de pt-BR

### Modelo comercial

| Plano | Preço | Cobrança |
|-------|-------|----------|
| Mensal | R$ 9,90 | Recorrência mensal, auto-renew |
| Anual | R$ 99,90 | Recorrência anual, auto-renew, ~16% off vs 12× mensal |
| Trial | 7 dias | **Cartão obrigatório**, cobrança automática no dia 7 se não cancelar |

### Plataformas no MVP

| Plataforma | Status MVP | Cobrança |
|-----------|-----------|----------|
| Android (Play Store) | ✅ MVP | Google Play Billing |
| Web (PWA `app.dublydesk.com`) | ✅ MVP | Stripe Checkout + Subscriptions |
| iOS | ⏸️ Fase 2 (quando tiver Mac ou build remoto) | App Store IAP |
| Windows/desktop | ⏸️ Fase 2 | Mesmo PWA serve via navegador |

## Arquitetura técnica

### Princípio fundamental: backend é fonte de verdade

A questão "esse usuário tem acesso Pro?" sempre é resolvida server-side via endpoint `GET /me/entitlements`. O cliente cacheia a resposta por ~15 minutos mas nunca decide sozinho. Isso garante que:
- Cobrança no web reflete imediatamente no Android (e vice-versa)
- Cancelamento no Stripe Portal desbloqueia o paywall em até 15 min
- Restore após troca de celular é seguro e simples

### Componentes

```
┌──────────────────────┐
│  Flutter app         │
│  - Trigger paywall   │
│  - Play Billing SDK  │
│  - Cache entitlement │
└──────────┬───────────┘
           │ HTTPS
           ▼
┌──────────────────────┐       ┌────────────────────┐
│  apps/api (Node)     │◄──────┤  Stripe Webhooks   │
│  - Routes /billing/* │       │  (sub events)      │
│  - Routes /receipts/*│       └────────────────────┘
│  - Verify Play API   │       ┌────────────────────┐
│  - Entitlements      │◄──────┤  Google Play       │
│  - PDF generation    │       │  Developer API     │
│  - Email via SMTP    │       │  (verify receipt)  │
└──────────┬───────────┘       └────────────────────┘
           │ SQL
           ▼
┌──────────────────────┐
│  PostgreSQL          │
│  - subscriptions     │
│  - subscription_events
│  - receipts          │
│  - analytics_events  │
│  - schedules (+col)  │
└──────────────────────┘

PWA Web (Flutter Web no mesmo codebase) ─► mesmo backend, mas
                                          Stripe Checkout em vez de Play Billing
```

### Componentes do cliente Flutter

**Novos:**
- `core/services/billing_service.dart` — wrapper sobre `in_app_purchase` (package oficial Flutter)
- `core/services/entitlement_service.dart` — consulta `/me/entitlements`, mantém cache local com TTL 15min, expõe `bool isPro` reativo
- `core/services/receipt_service.dart` — chama endpoints de geração/envio de recibo
- `features/pro/pro_page.dart` — tela de venda do Pro
- `features/pro/pro_status_widget.dart` — badge no drawer ("Pro", "Trial X dias")
- `features/receipts/receipt_preview_page.dart` — preview do PDF antes de enviar
- `features/receipts/payment_status_widget.dart` — chips pago/pendente/atrasado
- `features/receipts/payments_dashboard_page.dart` — listagem "a receber" com totais

**Modificados:**
- `features/schedules/schedule_card.dart` — adiciona botão "Gerar recibo" (Pro) e chip de status
- `features/schedules/schedule_form_page.dart` — adiciona campo opcional de email da produtora
- `finance_page.dart` — banner de promoção do Pro + integração com `payments_dashboard`
- `home_page.dart` — item "DublyDesk Pro" no drawer com badge dinâmico
- `notification_service.dart` — agendamento de notificações de cobrança vencendo

### Componentes do backend (`apps/api`)

**Novas rotas:**

```
POST /billing/play/verify
  Body: { purchaseToken, productId, packageName }
  Faz: chama Google Play Developer API pra validar o token; cria/atualiza
       linha em subscriptions; retorna entitlement atualizado

POST /billing/stripe/checkout
  Body: { planType: 'monthly' | 'annual' }
  Auth: requerida
  Faz: cria Stripe Checkout Session, retorna URL pra redirect

POST /billing/stripe/webhook
  Header: Stripe-Signature obrigatório
  Faz: valida assinatura HMAC; processa eventos
       (customer.subscription.created, .updated, .deleted, 
        invoice.payment_succeeded, invoice.payment_failed)

POST /billing/stripe/portal
  Auth: requerida
  Faz: gera Customer Portal session URL para autoatendimento

POST /billing/restore
  Auth: requerida (Android)
  Faz: re-consulta Play API com purchase tokens já vinculados, reconcilia

GET /me/entitlements
  Auth: requerida
  Resposta: { 
    pro: bool, 
    trial: bool, 
    until: ISO timestamp | null,
    source: 'play' | 'stripe' | null,
    cancelAtPeriodEnd: bool
  }

POST /receipts/generate
  Auth: requerida + Pro
  Body: { scheduleId, dadosDublador?: {...} }
  Faz: gera PDF via pdfkit, salva em uploads/receipts/{id}.pdf, 
       retorna URL pública e id do recibo

POST /receipts/:id/send-email
  Auth: requerida + Pro
  Body: { destinatario, copiaPara?, mensagem? }
  Faz: envia email via Nodemailer com PDF anexo

PATCH /schedules/:id/payment
  Auth: requerida
  Body: { status: 'pendente'|'pago'|'parcial'|'atrasado', valorPago?, vencimento? }
  Faz: atualiza colunas de pagamento na escala

GET /receipts/pending
  Auth: requerida
  Resposta: lista de escalas com status_pagamento != 'pago' + soma total

POST /events
  Auth: requerida (ou anônima com session_id)
  Body: { type, payload }
  Faz: insere em analytics_events (instrumentação leve)
```

**Schema SQL adicional:**

```sql
-- Subscription state (única source of truth pra Pro)
CREATE TABLE IF NOT EXISTS subscriptions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source TEXT NOT NULL CHECK (source IN ('play', 'stripe')),
  external_id TEXT NOT NULL,  -- purchase_token ou stripe_subscription_id
  product_id TEXT NOT NULL,   -- 'pro_monthly' | 'pro_annual'
  status TEXT NOT NULL CHECK (status IN ('trialing','active','past_due','cancelled','expired')),
  current_period_end TIMESTAMPTZ NOT NULL,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  trial_ends_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (source, external_id)
);
CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_active ON subscriptions(user_id, status, current_period_end);

-- Audit trail de webhooks
CREATE TABLE IF NOT EXISTS subscription_events (
  id SERIAL PRIMARY KEY,
  subscription_id INTEGER REFERENCES subscriptions(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  raw_payload JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Recibos gerados
CREATE TABLE IF NOT EXISTS receipts (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  schedule_id INTEGER NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  pdf_path TEXT NOT NULL,
  sent_email TEXT NULL,
  sent_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_receipts_user ON receipts(user_id, created_at DESC);

-- Eventos pra instrumentação
CREATE TABLE IF NOT EXISTS analytics_events (
  id BIGSERIAL PRIMARY KEY,
  user_id INTEGER NULL REFERENCES users(id) ON DELETE SET NULL,
  session_id TEXT NULL,
  event_type TEXT NOT NULL,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_events_user_type ON analytics_events(user_id, event_type, created_at DESC);
CREATE INDEX idx_events_type_time ON analytics_events(event_type, created_at DESC);

-- Adições à tabela schedules existente
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS status_pagamento TEXT 
  DEFAULT 'pendente' CHECK (status_pagamento IN ('pendente','pago','parcial','atrasado'));
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS valor_pago NUMERIC(10,2) DEFAULT 0;
ALTER TABLE schedules ADD COLUMN IF NOT EXISTS vencimento DATE NULL;
```

### Geração de PDF

**Stack:** `pdfkit` (npm). Razões:
- Lib pura Node, sem dependência de headless Chrome (mais leve que puppeteer)
- ~200KB instalado vs ~300MB do puppeteer
- Suporte nativo a fontes embeddadas, encoding UTF-8, layouts complexos
- Maturity > 10 anos, manutenção ativa

**Layout do recibo:**
- A4 portrait
- Header: nome do dublador + dados (CPF opcional, email, telefone)
- Bloco "Recebi(de)": nome da produtora
- Bloco "A quantia de": R$ XX,XX (extenso opcional via `numero-por-extenso` package)
- Bloco "Referente a": projeto + papel + diretor + data do trabalho
- Footer: cidade/data, espaço pra assinatura, rodapé discreto "Gerado pelo DublyDesk · dublydesk.com"

**Armazenamento:** `apps/api/uploads/receipts/{user_id}/{receipt_id}.pdf`. Acessível via URL assinada com expiração de 7 dias pra download. Em produção (EasyPanel), montar volume persistente pra essa pasta.

### Fluxo de pagamento Android (Play Billing)

```
1. App: usuário toca "Assinar Anual" na pro_page
2. App: chama in_app_purchase.buyNonConsumable(productDetails)
3. Play Store UI: usuário confirma com cartão já salvo (ou cadastra)
4. App recebe PurchaseDetails com purchaseToken
5. App: POST /billing/play/verify { purchaseToken, productId, packageName }
6. Backend: chama Google Play Developer API (service account auth)
7. Backend: valida que purchaseToken é legítimo e ativo
8. Backend: cria/atualiza subscriptions, retorna entitlement
9. App: atualiza EntitlementService, UI desbloqueia recibos
10. App: chama purchase.complete() (libera a Play Store)

Renovação automática:
- Google notifica backend via Real-time Developer Notifications (Pub/Sub)
- Backend processa e atualiza subscriptions.current_period_end
```

### Fluxo de pagamento Web (Stripe)

```
1. PWA: usuário toca "Assinar Anual" na pro_page
2. PWA: POST /billing/stripe/checkout { planType: 'annual' }
3. Backend: cria Stripe Checkout Session com:
   - mode: 'subscription'
   - line_items: [{ price: 'price_XYZ', quantity: 1 }]
   - trial_period_days: 7
   - success_url: https://app.dublydesk.com/pro/success?session_id={CHECKOUT_SESSION_ID}
   - cancel_url: https://app.dublydesk.com/pro
   - customer_email: user.email
   - metadata: { user_id: user.id }
4. Backend retorna URL → PWA redireciona
5. Stripe Checkout: usuário paga
6. Stripe envia webhook customer.subscription.created → POST /billing/stripe/webhook
7. Backend valida assinatura HMAC, cria subscription
8. PWA na success_url chama GET /me/entitlements e desbloqueia
```

### Segurança

- **Validação server-side sempre.** Cliente nunca decide "tem Pro".
- **Webhook signature verification obrigatória.** Stripe usa `Stripe-Signature` HMAC; Play Real-time Notifications usa Pub/Sub authenticated push.
- **Service account credentials do Google Play como secret no servidor.** Nunca empacotar no app.
- **Endpoint `/me/entitlements` rate-limited.** Express-rate-limit já no projeto: 60 req/min por usuário.
- **PDFs com URL não-listável.** UUID v4 no path, sem incremento sequencial. URL expira em 7 dias se for download externo.
- **Email rate-limited.** Máximo 10 recibos enviados por hora por usuário (anti-spam).

### Convenções respeitadas (do `dublydesk-conventions` skill)

- Sem ORM — `pool.query()` com SQL direto
- Auth via middleware `auth.js`
- Validação via `express-validator`
- Naming: snake_case nos arquivos, camelCase em código, PascalCase em classes
- Flutter sem bloc/riverpod, `StatefulWidget` + `ChangeNotifier`
- HTTP via `ApiService` que injeta JWT
- Theme via `Theme.of(context)`, sem hardcode

## UX do paywall

### Onde aparece

1. **Botão "Gerar recibo" no `schedule_card`** (gatilho principal)
   - Free → abre `pro_page` em modal
   - Trial/Pro → gera direto
2. **Item "DublyDesk Pro" no drawer** com badge dinâmico
3. **Banner discreto no `finance_page`** quando há valores pendentes
4. **Toast leve** após criar escala marcada como realizada
5. **NÃO usar** pop-up de upgrade ao abrir o app

### Tela "DublyDesk Pro" (`pro_page.dart`)

Layout vertical:
- Header com ícone ⭐ e título "DublyDesk Pro"
- Subtítulo: "Recibos automáticos pras suas cobranças, sem dor de cabeça"
- Lista de checkmarks com os 6 benefícios principais
- Card "Anual — R$ 99,90 · R$ 8,33/mês · Economize 16%" com botão "Assinar" (destacado)
- Card "Mensal — R$ 9,90 · Cancele quando quiser" com botão "Assinar"
- Texto pequeno: "Comece com 7 dias grátis"
- Link "Restaurar compras"
- Links rodapé: Termos · Privacidade · Cancelar a qualquer momento

### Estados de assinatura no app

| Estado | App mostra |
|--------|-----------|
| Free | CTA pra Pro, gerar recibo bloqueado |
| Trial ativo | Badge "Trial X dias", recibo desbloqueado, push de aviso D-2 e D-1 |
| Pro ativo | Badge "Pro" discreto, todas as features liberadas |
| Pro cancelado (no período) | Aviso "Termina em DD/MM. Reativar?" |
| Expirado | CTA "Volte pro Pro" |

### Cancelamento

- Android: deep link pra `https://play.google.com/store/account/subscriptions` filtrado por app
- Web: link pro Stripe Customer Portal (gerado server-side)
- Mensagem clara: "Você pode usar o Pro até DD/MM/YYYY"

### Restore purchase

- Botão visível na `pro_page`
- Executado também no login se houver purchase_token vinculado
- Resolve "troquei de celular" sem fricção

## Métricas de validação

### Eventos instrumentados via `POST /events`

| Evento | Quando |
|--------|--------|
| `paywall_viewed` | Abriu `pro_page` |
| `paywall_cta_clicked` | Clicou "Assinar" mensal ou anual |
| `checkout_started` | Play Billing ou Stripe Checkout iniciado |
| `trial_started` | Cartão cadastrado, trial 7d ativo |
| `recibo_generated` | Gerou PDF |
| `recibo_sent_email` | Enviou por email |
| `recibo_sent_whatsapp` | Compartilhou via Share Sheet |
| `trial_cancelled` | Cancelou antes do dia 7 |
| `subscription_charged` | Primeira cobrança bem sucedida |
| `subscription_cancelled` | Cancelou após virar pagante |
| `subscription_expired` | Não renovou |

### Critérios go/no-go (decisão em 90 dias)

| Cenário | trial→pago | pago ativo 30d | Ação |
|---------|-----------|----------------|------|
| 🟢 Validado | ≥ 30% | ≥ 70% | Lança v2 (Análise) + v3 (Sync) |
| 🟡 Ambíguo | 15-30% | 50-70% | Ajusta preço/copy/gatilhos. +90 dias |
| 🔴 Não validado | < 15% ou < 50% | qualquer | Repensar feature, público ou modelo |

### Queries SQL pra acompanhamento

```sql
-- Funil últimos 30 dias
SELECT
  COUNT(DISTINCT CASE WHEN event_type='paywall_viewed' THEN user_id END) AS viewed,
  COUNT(DISTINCT CASE WHEN event_type='trial_started' THEN user_id END) AS trialed,
  COUNT(DISTINCT CASE WHEN event_type='subscription_charged' THEN user_id END) AS paid
FROM analytics_events
WHERE created_at >= NOW() - INTERVAL '30 days';

-- MRR estimado
SELECT 
  SUM(CASE WHEN product_id='pro_monthly' THEN 9.90 ELSE 99.90/12 END) AS mrr_brl
FROM subscriptions
WHERE status='active';

-- Cohort de retenção
SELECT 
  DATE_TRUNC('month', s.created_at) AS cohort_month,
  COUNT(DISTINCT s.user_id) AS started,
  COUNT(DISTINCT CASE WHEN s.status='active' THEN s.user_id END) AS still_active
FROM subscriptions s
GROUP BY 1 ORDER BY 1 DESC;
```

## Pré-requisitos externos

Antes do desenvolvimento começar, providenciar:

1. **Google Play Console** — projeto cadastrado, app publicado em ao menos internal testing track, produtos in-app `pro_monthly` e `pro_annual` cadastrados como subscriptions
2. **Service account no Google Cloud** com permissão na Play Developer API; credenciais JSON salvas como secret no EasyPanel
3. **Conta Stripe** ativada com domínio `app.dublydesk.com` cadastrado, produtos `pro_monthly` e `pro_annual` criados com prices em BRL, webhook endpoint configurado apontando pra `https://api.dublydesk.com/billing/stripe/webhook`
4. **Termos de uso e política de privacidade** publicados em `dublydesk.com/termos` e `dublydesk.com/privacidade` (Play Store e Stripe exigem)
5. **Email transacional verificado** no domínio dublydesk.com (`pro@dublydesk.com` ou `suporte@dublydesk.com`) — pode reutilizar SMTP atual mas com sender atualizado
6. **Volume persistente no EasyPanel** pra `apps/api/uploads/receipts/`

## Riscos e mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| Google Play rejeita por política de assinaturas | Média | Alto | Seguir Play Console guidelines à risca; cancelamento sempre via Play; preços claros |
| Stripe webhook não chega (dropped) | Baixa | Médio | Webhook handler idempotente; cron job de reconciliação a cada hora consultando Stripe API |
| Conflito de cobrança Android + Web mesmo user | Baixa | Médio | `subscriptions.UNIQUE (source, external_id)`; entitlement retorna a assinatura mais "longe" no futuro |
| PDF com acentos quebrados | Média | Alto | Embed font Helvetica/Roboto que suporte latin-extended; testar com nomes acentuados no QA |
| Reclamação "fui cobrado de surpresa" no Trial | Média | Alto | Push D-2 e D-1; email no D0; cancelar trial = 1 clique sem fricção |
| LET's Encrypt expira em api.dublydesk.com | Baixa | Crítico | EasyPanel renova automaticamente; monitor + alerta no painel |

## Roadmap de implementação (alto nível)

A ser detalhado no plano de implementação (próximo passo: skill `writing-plans`). Fases prováveis:

**Fase 1 — Infraestrutura de billing (5-7 dias)**
- Schema SQL (subscriptions, events, analytics_events)
- Rotas `/billing/*` e `/me/entitlements`
- Integração Play Billing + verify
- Integração Stripe Checkout + webhook
- Testes manuais com sandbox

**Fase 2 — Geração e envio de recibo (4-5 dias)**
- Endpoint `/receipts/generate` com pdfkit
- Endpoint `/receipts/send-email`
- Status de pagamento na tabela schedules
- Endpoint `/receipts/pending`

**Fase 3 — Frontend Flutter (5-7 dias)**
- `EntitlementService` + cache
- `BillingService` wrapper Play Billing
- `pro_page.dart` (tela de venda)
- Botão "Gerar recibo" no `schedule_card`
- `payments_dashboard_page`
- Banner no `finance_page`
- Item no drawer com badge

**Fase 4 — PWA Web Flutter (3-4 dias)**
- Configurar Flutter Web target
- Build pipeline → deploy em `app.dublydesk.com`
- Stripe Checkout flow (redirect)
- PWA manifest + service worker
- Adaptações de UX desktop/touch

**Fase 5 — Instrumentação e go-live (2-3 dias)**
- Endpoint `/events` + tabela
- Eventos disparados de pontos-chave no app
- Queries SQL pra dashboard ad-hoc
- Push notifications de trial expirando
- Soft launch em internal testing (Android)
- Promoção pra closed beta após 1 semana sem regressões
- Promoção pra produção

**Tempo total estimado:** 19-26 dias úteis (~4-5 semanas focadas).

## Próximo passo

Invocar skill `writing-plans` pra gerar plano de implementação detalhado com tasks rastreáveis, dependências e checkpoints de review.
