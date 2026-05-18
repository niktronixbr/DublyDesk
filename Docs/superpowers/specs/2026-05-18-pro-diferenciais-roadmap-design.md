# Pro — Diferenciais e Roadmap (Fase 2 + Fase 3)

**Data:** 2026-05-18
**Status:** Aprovado, aguardando review final
**Abordagem:** A — Pro único, entrega faseada
**Contexto prévio:** Plano 1 (Recibos & Cobrança backend) já concluído em 2026-05-17, deploy em 2026-05-18.

---

## 1. Visão Geral

DublyDesk Pro é um plano único, entregue em 3 fases incrementais. Cada fase agrega novas features ao mesmo paywall — sem tiers, sem add-ons, sem fragmentação comercial.

### Princípios

1. **Free permanece intocado.** Tudo que existe hoje no app (agenda, escalas, gráficos, calendário, produtoras/projetos/diretores) continua grátis pra sempre. Pro só adiciona.
2. **Cada fase entrega valor isolado.** Permite pausar entre fases pra medir conversão antes de investir na próxima.
3. **Grandfathering como retenção.** A cada aumento de preço, assinantes ativos mantêm o preço antigo enquanto a assinatura permanecer contínua. Cria urgência pra novos e fidelidade pros atuais.
4. **Sem responsabilidade fiscal.** Nenhuma feature emite NF-e, calcula imposto devido ou assina como contador. App é ferramenta de gestão, não agente fiscal.

### Composição final do Pro (após 3 fases)

- **Fase 1** (já implementada no backend): Recibos PDF + envio email + dashboard pagamentos + status financeiro nas escalas
- **Fase 2** (próxima): Cobrança automática + integração WhatsApp + link de pagamento Pix
- **Fase 3** (futura): Analytics de carreira + sync multi-device (Flutter Web)

---

## 2. Fase 2 — Cobrança Automática + WhatsApp + Pix

### 2.1 Objetivo

Transformar o app de "registro passivo de pagamento" em "agente ativo de cobrança". Hoje o dublador marca quem pagou; depois da Fase 2, o app avisa o cliente e fornece link pra pagar.

### 2.2 Componentes

**Régua de cobrança automática**
- Configurável por escala ou regra geral
- Disparos padrão: 3 dias antes do vencimento, no dia do vencimento, 3 dias após, 7 dias após
- Canais: email (já implementado via nodemailer) e WhatsApp (novo, via deep link)
- Dublador aprova cada disparo antes de enviar — sem disparo automático sem revisão

**Integração WhatsApp (Opção A — deep link)**
- Botão "Cobrar via WhatsApp" gera URL `whatsapp://send?phone={cliente_tel}&text={mensagem_pronta}`
- Abre o WhatsApp do celular do dublador com mensagem pronta + PDF anexável manualmente
- Zero custo, zero compliance — mensagem sai do número pessoal do dublador
- WhatsApp Business API oficial fica fora de escopo (custo por mensagem + templates pré-aprovados Meta)

**Link de pagamento Pix**
- Dublador cadastra chave Pix uma vez no perfil (CPF/email/celular/aleatória)
- Recibo PDF passa a incluir QR Code Pix + Copia-e-Cola com valor preenchido (geração local via lib `pix-utils` ou equivalente — sem gateway)
- **Sem custódia de dinheiro** — Pix cai direto na conta do dublador, DublyDesk não toca no dinheiro
- Confirmação de pagamento permanece manual (dublador marca como pago após receber)

**Templates de mensagem editáveis**
- 3 templates default: "lembrete amigável", "cobrança formal", "última tentativa"
- Editáveis com placeholders: `{cliente}`, `{valor}`, `{vencimento}`, `{dias_atraso}`, `{produtora}`
- Prévia antes de enviar

### 2.3 Mudanças no backend

**Novas tabelas:**
- `cobranca_templates(id, user_id, nome, conteudo, tipo, created_at, updated_at)` — `tipo` ∈ `{lembrete, formal, ultima_tentativa, custom}`
- `cobranca_envios(id, schedule_id, canal, template_id, enviado_em, status)` — auditoria, `canal` ∈ `{email, whatsapp}`, `status` ∈ `{enviado, erro, cancelado}`

**Alterações em tabelas existentes:**
- `schedules`: adicionar coluna `regua_cobranca_id INTEGER NULL` (FK opcional pra `cobranca_templates`)
- `users`: adicionar colunas `pix_chave VARCHAR(120) NULL`, `pix_tipo VARCHAR(20) NULL` — `pix_tipo` ∈ `{cpf, cnpj, email, celular, aleatoria}`

**Novos endpoints:**
- `GET /cobranca-templates` — lista templates do usuário
- `POST /cobranca-templates` — cria template
- `PUT /cobranca-templates/:id` — atualiza template
- `DELETE /cobranca-templates/:id` — remove template
- `POST /receipts/:id/whatsapp-link` — retorna `{ url: "whatsapp://...", pdf_url: "..." }`
- `POST /receipts/:id/cobrar` — registra envio em `cobranca_envios` (chamado pelo Flutter após dublador confirmar disparo)
- `PUT /me/pix` — atualiza chave Pix do usuário

**Alterações em endpoints existentes:**
- `POST /receipts/generate` passa a embutir QR Code Pix no PDF quando `users.pix_chave` está preenchida

Todos os endpoints novos requerem entitlement Pro via `middleware/require_pro.js`.

### 2.4 Mudanças no Flutter

- **Tela "Régua de Cobrança"** nas configurações Pro — define dias de disparo padrão
- **Tela "Editor de Templates"** — CRUD de templates com prévia
- **Campo Pix no perfil** — input com seletor de tipo
- **Botão "Cobrar via WhatsApp"** no card de escala pendente — abre confirmação → deep link
- **Botão "Cobrar via Email"** no card — abre confirmação → POST `/receipts/:id/cobrar`
- Geração de QR Code Pix delegada ao backend (PDF já vem pronto)

### 2.5 Trade-offs e mitigações

| Risco | Mitigação |
|-------|-----------|
| Deep link WhatsApp dispara do número pessoal — pode irritar cliente se mal usado | Revisão obrigatória da mensagem antes do disparo |
| Pix sem gateway não confirma pagamento automaticamente | Aceito — dublador marca manualmente, simplifica MVP |
| Templates editáveis = risco de mensagens mal escritas | 3 defaults profissionais + prévia obrigatória |
| Régua automática pode ficar pesada com muitas escalas | Disparo on-demand, não cron — backend só responde quando Flutter pede |

---

## 3. Fase 3 — Analytics de Carreira + Multi-device Sync

### 3.1 Objetivo

Transformar dados brutos (escalas + pagamentos) em inteligência de carreira, e garantir acesso ao trabalho em qualquer dispositivo (celular, web, desktop futuro).

### 3.2 Analytics de Carreira

Dashboard Pro com foco em decisões de carreira, não vaidade.

**Visões inclusas:**
1. **Top clientes** — produtoras/diretores que mais contrataram (volume + receita) nos últimos 6/12/24 meses. Identifica concentração de risco.
2. **Sazonalidade** — meses fortes vs fracos no ano. Planejamento de reserva.
3. **Comparativo anual** — receita atual vs ano anterior, escalas/mês, ticket médio.
4. **Inadimplência por cliente** — quais clientes atrasam mais, taxa de pagamento por produtora.
5. **Projeção de receita** — escalas agendadas + média histórica dos próximos 30/60/90 dias.
6. **Ticket médio por tipo de projeto** — dublagem comercial, jogo, filme, série, etc.

**Fora de escopo (intencional):**
- Ranking nacional ou comparação com outros dubladores (LGPD complexa, valor duvidoso)
- Sugestão de preço (entra em aconselhamento, evitar)

### 3.3 Multi-device Sync

1. **Flutter Web build** — deploy em `app.dublydesk.com` (já planejado no roadmap Plano 3)
2. **Sync automático via API** — backend já é fonte da verdade. Cada cliente (Android, web, desktop) consome a mesma REST API.
3. **Sessões multi-device** — JWT atual já permite logins simultâneos
4. **Resolução de conflitos** — `updated_at` em todas as tabelas + estratégia last-write-wins + toast "essa escala foi atualizada em outro dispositivo" no Flutter

**Decisão:** sync é Pro porque a versão web custa hospedagem/CDN e abre acesso desktop (uso profissional). Free fica no mobile.

### 3.4 Mudanças no backend

**Novos endpoints:**
- `GET /analytics/top-clientes?periodo=12m`
- `GET /analytics/sazonalidade?ano=2026`
- `GET /analytics/comparativo?atual=2026&anterior=2025`
- `GET /analytics/inadimplencia?periodo=12m`
- `GET /analytics/projecao?dias=90`
- `GET /analytics/ticket-medio?periodo=12m`

**Alterações em tabelas existentes:**
- Adicionar `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()` em `schedules`, `produtoras`, `projetos`, `diretores` (com trigger de update automático)

**Cache:**
- Cache simples in-memory dos resultados de analytics (TTL 1h)
- Invalidação automática quando `schedules` é criada/editada (publish via event interno)

### 3.5 Mudanças no Flutter

- **Tela "Insights"** (drawer item Pro com badge)
- **Cards de visão** usando `fl_chart` (já presente como dependência)
- **Filtros de período** persistidos em `shared_preferences`
- **Web build** configurado (`flutter build web`), deploy em `app.dublydesk.com`
- **Tratamento de divergências de plataforma** — `flutter_local_notifications` não funciona no web; usar `kIsWeb` pra fallback (sem notificação no web é aceitável)

### 3.6 Trade-offs e mitigações

| Risco | Mitigação |
|-------|-----------|
| Queries de analytics pesadas em PostgreSQL | Cache 1h + índices em `(user_id, data_gravacao)`, `(user_id, status_pagamento)` |
| Flutter Web tem limitações de plataforma | Aceito — web é complemento, não substituto. Notificações ficam apenas no mobile. |
| Sync sem realtime (WebSocket) → "dado antigo até pull-to-refresh" | Aceito pro MVP. Full realtime seria over-engineering. |

---

## 4. Billing, Pricing e Grandfathering

### 4.1 Evolução de preços por fase

| Fase | Composição | Pro Mensal | Pro Anual |
|------|-----------|------------|-----------|
| Fase 1 | Recibos & Cobrança | R$ 9,90 | R$ 99,90 |
| Fase 2 | + Cobrança Automática + WhatsApp + Pix | R$ 14,90 | R$ 149,90 |
| Fase 3 | + Analytics + Multi-device | R$ 19,90 | R$ 199,90 |

Anual mantém ~16% off (≈2 meses grátis) em todas as fases.

### 4.2 Grandfathering

**Regra:** quem assinou enquanto o preço X estava ativo mantém o preço X enquanto a assinatura permanecer ativa e contínua.

**Implementação Stripe:**
- Cada assinatura fica atrelada ao `price_id` no momento da criação
- Aumento de preço = criar novos `price_id`s, sem mexer nos antigos
- Backend nunca força upgrade — quem está em `price_monthly_v1` continua nele até cancelar
- Cancelou e voltou depois → assina pelo preço vigente

**Implementação Google Play:**
- Manter SKU antigo ativo, criar novo SKU para o preço novo
- Mesmo comportamento de grandfathering nativo do Play

**Comunicação aos Free no aumento:**
- Email + push 30 dias antes: "Pro sobe pra R$X em N dias — assine agora por R$Y vitalício"
- Cria urgência real, não fake scarcity

### 4.3 Backend — mudanças

**Alterações em `subscriptions`:**
- Adicionar `price_tier VARCHAR(20) NULL` — guarda versão (`v1_monthly`, `v2_annual`, etc.) só pra analytics/relatório, não pra lógica de gate
- Adicionar `grandfathered_until TIMESTAMPTZ NULL` — opcional, casos manuais de suporte

**O que NÃO muda:**
- `getEntitlement(userId)` continua retornando `{ pro: true/false }` — não diferencia tier de preço
- Todas as features Pro são desbloqueadas igualmente independente do preço pago

### 4.4 Trial e cancelamento

Mantém o que já existe (Fase 1):
- 7 dias grátis, cartão exigido (Stripe trial nativo)
- Cancelamento via Stripe Customer Portal (sem fricção)
- Acesso permanece até fim do ciclo pago

Sem mudanças nas Fases 2 e 3.

### 4.5 Pricing experiments (pós-Fase 3, fora de escopo agora)

- Cupom promocional (BLACK FRIDAY) — Stripe nativo
- Anual com 20-25% off (LTV maior, churn menor)
- Indique-um-amigo: ambos ganham 1 mês grátis

Não construir antes de validar a base.

### 4.6 Trade-offs aceitos

| Decisão | Custo | Por quê aceito |
|---------|-------|----------------|
| Grandfathering vitalício | Abre mão de +R$10/mês por usuário antigo | Retenção > receita marginal; urgência ("assine antes do aumento") compensa em volume |
| Entitlement não diferencia tiers | Quem pagou R$9,90 ganha features de R$19,90 quando Fase 3 lança | Simplicidade > otimização; minoria de usuários, "bônus" pela lealdade |

---

## 5. Sequenciamento e Pendências

### 5.1 Ordem de execução

1. **Plano 2 — Flutter Android Fase 1** (pendente, ~5-7 dias úteis): paywall, EntitlementService, BillingService, botão "Gerar recibo", dashboard pagamentos
2. **Plano 3 — PWA Web Fase 1 + Go-live**: Flutter Web build, Stripe Checkout web, internal testing Play
3. **Plano 4 — Fase 2 backend**: tabelas, endpoints, integração Pix QR Code, deep link WhatsApp
4. **Plano 5 — Fase 2 Flutter**: telas de régua, templates, botões de cobrança, campo Pix no perfil
5. **Lançamento Fase 2 → aumento de preço (grandfathering automático)**
6. **Plano 6 — Fase 3 backend**: endpoints de analytics, cache, `updated_at`/triggers
7. **Plano 7 — Fase 3 Flutter**: tela Insights, cards de visão, sync conflitos
8. **Lançamento Fase 3 → aumento de preço (grandfathering automático)**

### 5.2 Pendências herdadas do Plano 1 (resolver antes da Fase 2)

1. Volume persistente para `apps/api/uploads/receipts/` no EasyPanel
2. Publicar Termos + Privacidade em `dublydesk.com/termos` e `dublydesk.com/privacidade`
3. Google Play Console: criar conta ($25), registrar app, criar produtos `pro_monthly` e `pro_annual`, criar service account
4. Trocar vars Stripe `sk_test_` → `sk_live_` no EasyPanel quando for live

### 5.3 Dependências externas que podem atrasar

- Aprovação do app na Play Store (1-7 dias)
- Verificação Stripe live mode (1-3 dias)
- DNS + SSL pra `app.dublydesk.com` (algumas horas)

---

## 6. Critérios de Sucesso

### Fase 2 (medir 60 dias após lançamento)
- Taxa de conversão Free → Pro sobe vs. baseline pós-Fase 1
- ≥30% dos assinantes Pro usam botão "Cobrar via WhatsApp" pelo menos 1x
- Tempo médio entre vencimento e pagamento cai (cobrança ativa funciona)

### Fase 3 (medir 90 dias após lançamento)
- ≥40% dos assinantes Pro acessam tela "Insights" pelo menos 1x/mês
- ≥15% dos assinantes Pro logam na versão web pelo menos 1x
- Churn mensal cai vs. pré-Fase 3 (sticky factor do analytics + multi-device)

### Por fase
- Stripe e Google Play webhook events processados sem perda
- Zero incidente de cobrança duplicada ou perda de entitlement
- Tempo de resposta dos endpoints de analytics < 500ms p95 (com cache)

---

## 7. O que está fora deste spec

- Implementação detalhada de cada endpoint (vai pro plano)
- Wireframes de UI (cabem em design separado ou no plano Flutter)
- Estratégia de marketing pós-lançamento
- iOS — fica pra Fase 4+ futura
- WhatsApp Business API oficial — fica pra Fase 4+ futura
- Realtime sync via WebSocket — fica pra Fase 4+ futura
- NF-e emissão — explicitamente fora por responsabilidade fiscal
