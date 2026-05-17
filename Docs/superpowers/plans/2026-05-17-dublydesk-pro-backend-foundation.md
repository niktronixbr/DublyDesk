# DublyDesk Pro — Backend Foundation (Plano 1 de 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir toda a infraestrutura de billing (Stripe + Play) e geração de recibos no backend (`apps/api`), entregando uma API pronta pra qualquer cliente consumir. Ao final deste plano, é possível assinar/cancelar via Stripe, validar compras Play, gerar e enviar recibos PDF — tudo via HTTP, antes mesmo do app Flutter saber que isso existe.

**Architecture:** Backend Node.js/Express com PostgreSQL como única fonte de verdade pra entitlements. Stripe pra cobrança web, Google Play Developer API pra verificação Android. Recibo PDF gerado com `pdfkit` server-side e enviado via Nodemailer (SMTP já configurado). Schema com migrations forward-only (padrão existente do projeto).

**Tech Stack:**
- Node 18 + Express 4 (já existente)
- PostgreSQL via `pg.Pool` (já existente)
- `stripe` SDK (a adicionar)
- `googleapis` SDK (a adicionar) pra Play Developer API
- `pdfkit` (a adicionar) pra geração de PDF
- `jest` + `supertest` (a adicionar) pra testes
- `nodemailer` (já existente) pra email

**Spec relacionado:** [`Docs/superpowers/specs/2026-05-17-dublydesk-pro-recibos-monetizacao-design.md`](../specs/2026-05-17-dublydesk-pro-recibos-monetizacao-design.md)

**Próximos planos depois deste:**
- Plano 2: integração Flutter Android (consumir entitlements + Play Billing + UI Pro)
- Plano 3: PWA Web Flutter + instrumentação + go-live

---

## Pré-requisitos externos (bloqueia execução)

Antes da Task 1, providenciar:

1. **Conta Stripe** ativada em modo test (gratuito):
   - Criar produtos `pro_monthly` (R$ 9,90/mês) e `pro_annual` (R$ 99,90/ano) no painel
   - Anotar `STRIPE_SECRET_KEY` (test) e `STRIPE_WEBHOOK_SECRET`
   - Anotar os Price IDs gerados (ex.: `price_1Abc...`)

2. **Google Cloud project** com Play Developer API habilitada:
   - Criar service account, gerar chave JSON
   - Salvar o JSON localmente como `apps/api/.secrets/play-service-account.json` (adicionar `.secrets/` ao `.gitignore`)
   - No futuro, no Play Console: cadastrar app, criar subscriptions `pro_monthly` e `pro_annual`, vincular service account com permissão "View financial data"

3. **Variáveis adicionais no `apps/api/.env`** (não commitar):
   ```env
   STRIPE_SECRET_KEY=sk_test_...
   STRIPE_WEBHOOK_SECRET=whsec_...
   STRIPE_PRICE_MONTHLY=price_...
   STRIPE_PRICE_ANNUAL=price_...
   PLAY_PACKAGE_NAME=br.com.dublydesk.app
   PLAY_SERVICE_ACCOUNT_PATH=./.secrets/play-service-account.json
   ```

A execução das tasks NÃO depende do Play Console estar pronto — a integração Play é testável com mocks na fase backend. O Play Console real entra na Task 9 do Plano 2 (Flutter).

---

## File Structure

Arquivos a criar (todos sob `apps/api/`):

```
apps/api/
  routes/
    billing.js          ← NOVO — todas as rotas /billing/*
    receipts.js         ← NOVO — todas as rotas /receipts/*
  services/
    entitlement.js      ← NOVO — lógica de entitlement (consultada por billing + middleware)
    stripe.js           ← NOVO — wrapper sobre o SDK Stripe
    play_billing.js     ← NOVO — wrapper sobre googleapis Play Developer
    pdf_generator.js    ← NOVO — gera o PDF do recibo
    email_sender.js     ← NOVO — wrapper sobre nodemailer (já tem um inline em auth.js, extrair pra reuso)
  middleware/
    require_pro.js      ← NOVO — middleware que exige entitlement Pro
  __tests__/            ← NOVA pasta
    helpers/
      test_db.js        ← NOVO — setup/teardown de DB pra testes
      fixtures.js       ← NOVO — usuários fake, schedules fake
    entitlement.test.js
    billing_stripe.test.js
    billing_play.test.js
    receipts.test.js
    schedules_payment.test.js
  jest.config.js        ← NOVO
  .gitignore            ← MODIFICAR (adicionar .secrets/, uploads/receipts/)
  .env.example          ← MODIFICAR (adicionar novas vars)
  package.json          ← MODIFICAR (deps + scripts test)
  server.js             ← MODIFICAR (montar /billing, /receipts; criar tabelas novas)
  routes/schedules.js   ← MODIFICAR (adicionar PATCH /:id/payment + GET /pending)
```

Arquivos modificados são marcados explicitamente nas tasks. **Não modifique arquivos não listados** sem confirmar com o engenheiro responsável.

---

## Task 1: Infraestrutura de testes (jest + supertest)

O projeto não tem testes hoje. Antes de qualquer rota, precisamos de uma forma de validar que o que escrevemos funciona.

**Files:**
- Modify: `apps/api/package.json`
- Create: `apps/api/jest.config.js`
- Create: `apps/api/__tests__/helpers/test_db.js`
- Create: `apps/api/__tests__/helpers/fixtures.js`
- Create: `apps/api/__tests__/smoke.test.js`

- [ ] **Step 1: Adicionar dependências de teste**

Run:
```bash
cd apps/api
npm install --save-dev jest supertest @types/jest
```

Expected: `package.json` atualizado, `node_modules` populado, sem erro.

- [ ] **Step 2: Configurar scripts no package.json**

Modificar `apps/api/package.json` — adicionar dentro do bloco `"scripts"`:

```json
"scripts": {
  "start": "node server.js",
  "test": "jest --runInBand",
  "test:watch": "jest --watch --runInBand"
}
```

`--runInBand` força execução sequencial (não paralela), evitando colisão em DB compartilhado nos testes de integração.

- [ ] **Step 3: Criar jest.config.js**

Criar `apps/api/jest.config.js`:

```javascript
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.js'],
  testPathIgnorePatterns: ['/node_modules/', '/helpers/'],
  setupFilesAfterEnv: ['<rootDir>/__tests__/helpers/setup.js'],
  testTimeout: 15000,
};
```

- [ ] **Step 4: Criar helper de DB de teste**

Criar `apps/api/__tests__/helpers/test_db.js`:

```javascript
const pool = require('../../db');

async function cleanDatabase() {
  // Ordem importa por FKs. Truncar com RESTART IDENTITY zera os SERIAL.
  await pool.query(`
    TRUNCATE TABLE
      analytics_events,
      receipts,
      subscription_events,
      subscriptions,
      password_resets,
      schedules,
      projetos,
      diretores,
      produtoras,
      users
    RESTART IDENTITY CASCADE
  `).catch(() => {
    // Tabelas podem não existir ainda no primeiro teste; ignorar
  });
}

async function closeDatabase() {
  await pool.end();
}

module.exports = { cleanDatabase, closeDatabase };
```

- [ ] **Step 5: Criar helper de setup global**

Criar `apps/api/__tests__/helpers/setup.js`:

```javascript
// Carrega .env.test se existir, senão usa .env atual
require('dotenv').config({
  path: process.env.NODE_ENV === 'test' ? '.env.test' : '.env',
});

// Reduz logs durante testes
const originalLog = console.log;
console.log = (...args) => {
  if (process.env.VERBOSE_TESTS) originalLog(...args);
};
```

Adicionar dependência: `npm install --save dotenv` (se ainda não tiver).

Verificar com `grep dotenv apps/api/package.json`. Se já estiver lá, pular o install.

- [ ] **Step 6: Criar fixtures**

Criar `apps/api/__tests__/helpers/fixtures.js`:

```javascript
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../../db');

async function createTestUser(overrides = {}) {
  const name = overrides.name || 'Test User';
  const email = overrides.email || `test-${Date.now()}-${Math.random()}@example.com`;
  const password = overrides.password || 'senha123';
  const passwordHash = await bcrypt.hash(password, 10);

  const { rows } = await pool.query(
    `INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3) RETURNING id, name, email`,
    [name, email, passwordHash]
  );

  const user = rows[0];
  const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET || 'test-secret', { expiresIn: '1h' });
  return { user, token, password };
}

async function createTestSchedule(userId, overrides = {}) {
  const { rows } = await pool.query(
    `INSERT INTO schedules (user_id, projeto, produtora, diretor, data, hora_inicio, hora_fim, valor_total, realizado)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
    [
      userId,
      overrides.projeto || 'Projeto Teste',
      overrides.produtora || 'Produtora X',
      overrides.diretor || 'Diretor Y',
      overrides.data || new Date().toISOString(),
      overrides.hora_inicio || '14:00',
      overrides.hora_fim || '15:00',
      overrides.valor_total ?? 500,
      overrides.realizado ?? true,
    ]
  );
  return rows[0];
}

module.exports = { createTestUser, createTestSchedule };
```

- [ ] **Step 7: Criar smoke test**

Criar `apps/api/__tests__/smoke.test.js`:

```javascript
const request = require('supertest');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');

// Importar o app sem chamar listen() — refatoraremos server.js na Task 2 pra exportar app
let app;

beforeAll(async () => {
  await cleanDatabase();
  app = require('../server');
});

afterAll(async () => {
  await closeDatabase();
});

describe('GET /health', () => {
  it('retorna ok: true', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
  });
});
```

- [ ] **Step 8: Refatorar server.js pra exportar o app**

Modificar `apps/api/server.js` linha final. A função `startServer` chama `app.listen` na linha 192. Trocar:

De:
```javascript
async function startServer() {
  await createTables();
  app.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}`);
  });
}

startServer();
```

Para:
```javascript
async function startServer() {
  await createTables();
  app.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}`);
  });
}

// Só inicia o listener se executado diretamente (não em require para tests)
if (require.main === module) {
  startServer();
}

module.exports = app;
```

- [ ] **Step 9: Rodar smoke test e validar**

Run:
```bash
cd apps/api && npm test -- smoke
```

Expected: 1 teste passando (`GET /health retorna ok: true`). Output similar a:
```
PASS  __tests__/smoke.test.js
  GET /health
    ✓ retorna ok: true (XX ms)
```

Se falhar com "tabela não existe" no `cleanDatabase`, é esperado (a Task 2 cria as tabelas). O smoke test só usa `/health` que não toca tabelas, então o teste deve passar mesmo assim.

- [ ] **Step 10: Atualizar .gitignore**

Modificar `apps/api/.gitignore` (criar se não existir). Adicionar:

```
node_modules/
.env
.env.test
.secrets/
uploads/receipts/
coverage/
```

- [ ] **Step 11: Commit**

```bash
cd apps/api
git add package.json package-lock.json jest.config.js __tests__/ server.js .gitignore
git commit -m "test(api): adicionar infra de testes com jest+supertest

- jest configurado com runInBand pra evitar colisao em DB
- helpers de test_db (cleanDatabase, closeDatabase) e fixtures
  (createTestUser, createTestSchedule)
- server.js exporta app pra ser consumido por supertest
- smoke test em /health validando o setup
- .gitignore atualizado com .secrets/ e uploads/receipts/"
```

---

## Task 2: Schema — tabela subscriptions

**Files:**
- Modify: `apps/api/server.js` (função `createTables`)
- Test: `apps/api/__tests__/schema_subscriptions.test.js`

- [ ] **Step 1: Escrever teste do schema**

Criar `apps/api/__tests__/schema_subscriptions.test.js`:

```javascript
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');

beforeAll(async () => {
  require('../server'); // dispara createTables
  // Pequena espera pra garantir que createTables rodou (createTables é async no startup)
  await new Promise((resolve) => setTimeout(resolve, 500));
  await cleanDatabase();
});

afterAll(async () => {
  await closeDatabase();
});

describe('schema: subscriptions', () => {
  it('tabela subscriptions existe com as colunas esperadas', async () => {
    const { rows } = await pool.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'subscriptions'
      ORDER BY ordinal_position
    `);
    const cols = Object.fromEntries(rows.map((r) => [r.column_name, r]));

    expect(cols.id).toBeDefined();
    expect(cols.user_id).toBeDefined();
    expect(cols.source).toBeDefined();
    expect(cols.external_id).toBeDefined();
    expect(cols.product_id).toBeDefined();
    expect(cols.status).toBeDefined();
    expect(cols.current_period_end).toBeDefined();
    expect(cols.cancel_at_period_end).toBeDefined();
    expect(cols.trial_ends_at).toBeDefined();
    expect(cols.created_at).toBeDefined();
    expect(cols.updated_at).toBeDefined();
  });

  it('aceita insert válido', async () => {
    const userRes = await pool.query(
      `INSERT INTO users (name, email, password_hash) VALUES ('U', 'sub-test@example.com', 'x') RETURNING id`
    );
    const userId = userRes.rows[0].id;

    const { rows } = await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_test_123', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')
       RETURNING *`,
      [userId]
    );
    expect(rows[0].status).toBe('active');
    expect(rows[0].cancel_at_period_end).toBe(false);
  });

  it('rejeita status inválido', async () => {
    const userRes = await pool.query(
      `INSERT INTO users (name, email, password_hash) VALUES ('U2', 'sub-test2@example.com', 'x') RETURNING id`
    );
    const userId = userRes.rows[0].id;

    await expect(
      pool.query(
        `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
         VALUES ($1, 'stripe', 'sub_invalid', 'pro_monthly', 'banana', NOW())`,
        [userId]
      )
    ).rejects.toThrow();
  });

  it('UNIQUE em (source, external_id)', async () => {
    const userRes = await pool.query(
      `INSERT INTO users (name, email, password_hash) VALUES ('U3', 'sub-test3@example.com', 'x') RETURNING id`
    );
    const userId = userRes.rows[0].id;

    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_unique', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
      [userId]
    );

    await expect(
      pool.query(
        `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
         VALUES ($1, 'stripe', 'sub_unique', 'pro_annual', 'active', NOW() + INTERVAL '365 days')`,
        [userId]
      )
    ).rejects.toThrow();
  });
});
```

- [ ] **Step 2: Rodar teste e verificar que falha**

Run:
```bash
cd apps/api && npm test -- schema_subscriptions
```

Expected: FAIL com erro tipo `relation "subscriptions" does not exist`.

- [ ] **Step 3: Adicionar criação da tabela em server.js**

Modificar `apps/api/server.js`. Dentro da função `createTables`, **após** o bloco que cria `password_resets` (linha 119) e **antes** do bloco `console.log('✅ Tabelas...`), adicionar:

```javascript
    await pool.query(`
      CREATE TABLE IF NOT EXISTS subscriptions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        source TEXT NOT NULL CHECK (source IN ('play', 'stripe')),
        external_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('trialing','active','past_due','cancelled','expired')),
        current_period_end TIMESTAMPTZ NOT NULL,
        cancel_at_period_end BOOLEAN NOT NULL DEFAULT FALSE,
        trial_ends_at TIMESTAMPTZ NULL,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE (source, external_id)
      );
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_subscriptions_user
      ON subscriptions(user_id);
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_subscriptions_active
      ON subscriptions(user_id, status, current_period_end);
    `);
```

- [ ] **Step 4: Rodar teste e verificar que passa**

Run:
```bash
cd apps/api && npm test -- schema_subscriptions
```

Expected: 4 testes passando.

- [ ] **Step 5: Atualizar test_db.js**

O helper em `__tests__/helpers/test_db.js` (criado na Task 1) já tem `subscriptions` na lista de TRUNCATE. Confirme abrindo o arquivo — se não tiver, adicione na ordem correta (antes de `users`, depois de `subscription_events` e `receipts` que ainda não existem mas vão existir).

- [ ] **Step 6: Commit**

```bash
git add apps/api/server.js apps/api/__tests__/schema_subscriptions.test.js apps/api/__tests__/helpers/test_db.js
git commit -m "feat(billing): adicionar tabela subscriptions

- CHECK constraints em source e status pra evitar valores invalidos
- UNIQUE (source, external_id) evita duplicar mesma compra
- Indices em user_id e (user_id, status, current_period_end)
  pra suportar queries de entitlement com performance"
```

---

## Task 3: Schema — subscription_events, receipts, analytics_events

Três tabelas auxiliares que ficam juntas porque são pequenas e relacionadas a billing/observabilidade.

**Files:**
- Modify: `apps/api/server.js` (função `createTables`)
- Test: `apps/api/__tests__/schema_aux.test.js`

- [ ] **Step 1: Escrever teste**

Criar `apps/api/__tests__/schema_aux.test.js`:

```javascript
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');

beforeAll(async () => {
  require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
  await cleanDatabase();
});

afterAll(async () => {
  await closeDatabase();
});

describe('schema: subscription_events', () => {
  it('aceita insert com payload JSONB', async () => {
    const u = await pool.query(`INSERT INTO users (name, email, password_hash) VALUES ('U', 'e1@x.com', 'x') RETURNING id`);
    const s = await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_e1', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')
       RETURNING id`,
      [u.rows[0].id]
    );

    const { rows } = await pool.query(
      `INSERT INTO subscription_events (subscription_id, type, raw_payload)
       VALUES ($1, 'invoice.payment_succeeded', $2)
       RETURNING *`,
      [s.rows[0].id, JSON.stringify({ stripe_id: 'in_123' })]
    );
    expect(rows[0].type).toBe('invoice.payment_succeeded');
    expect(rows[0].raw_payload.stripe_id).toBe('in_123');
  });
});

describe('schema: receipts', () => {
  it('aceita insert e CASCADE de schedule', async () => {
    const u = await pool.query(`INSERT INTO users (name, email, password_hash) VALUES ('U', 'r1@x.com', 'x') RETURNING id`);
    const s = await pool.query(
      `INSERT INTO schedules (user_id, projeto, produtora, data, hora_inicio, hora_fim, valor_total)
       VALUES ($1, 'P', 'Pr', NOW(), '10:00', '11:00', 100) RETURNING id`,
      [u.rows[0].id]
    );

    const r = await pool.query(
      `INSERT INTO receipts (user_id, schedule_id, pdf_path)
       VALUES ($1, $2, 'uploads/receipts/abc.pdf')
       RETURNING *`,
      [u.rows[0].id, s.rows[0].id]
    );
    expect(r.rows[0].sent_email).toBeNull();
    expect(r.rows[0].sent_at).toBeNull();

    // CASCADE: deletar schedule remove o receipt
    await pool.query(`DELETE FROM schedules WHERE id = $1`, [s.rows[0].id]);
    const after = await pool.query(`SELECT * FROM receipts WHERE id = $1`, [r.rows[0].id]);
    expect(after.rows).toHaveLength(0);
  });
});

describe('schema: analytics_events', () => {
  it('aceita insert sem user_id (session_id apenas)', async () => {
    const { rows } = await pool.query(
      `INSERT INTO analytics_events (session_id, event_type, payload)
       VALUES ('anon-sess-123', 'paywall_viewed', $1)
       RETURNING *`,
      [JSON.stringify({ plan: 'annual' })]
    );
    expect(rows[0].user_id).toBeNull();
    expect(rows[0].session_id).toBe('anon-sess-123');
    expect(rows[0].payload.plan).toBe('annual');
  });

  it('aceita insert com user_id', async () => {
    const u = await pool.query(`INSERT INTO users (name, email, password_hash) VALUES ('U', 'ev1@x.com', 'x') RETURNING id`);
    const { rows } = await pool.query(
      `INSERT INTO analytics_events (user_id, event_type) VALUES ($1, 'trial_started') RETURNING *`,
      [u.rows[0].id]
    );
    expect(rows[0].user_id).toBe(u.rows[0].id);
  });
});
```

- [ ] **Step 2: Rodar teste e verificar que falha**

Run: `cd apps/api && npm test -- schema_aux`. Expected: FAIL (tabelas não existem).

- [ ] **Step 3: Adicionar tabelas em server.js**

Em `apps/api/server.js`, dentro da função `createTables`, **após** o bloco da `subscriptions` da Task 2:

```javascript
    await pool.query(`
      CREATE TABLE IF NOT EXISTS subscription_events (
        id SERIAL PRIMARY KEY,
        subscription_id INTEGER REFERENCES subscriptions(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        raw_payload JSONB NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS receipts (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        schedule_id INTEGER NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
        pdf_path TEXT NOT NULL,
        sent_email TEXT NULL,
        sent_at TIMESTAMPTZ NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_receipts_user
      ON receipts(user_id, created_at DESC);
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS analytics_events (
        id BIGSERIAL PRIMARY KEY,
        user_id INTEGER NULL REFERENCES users(id) ON DELETE SET NULL,
        session_id TEXT NULL,
        event_type TEXT NOT NULL,
        payload JSONB,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_events_user_type
      ON analytics_events(user_id, event_type, created_at DESC);
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_events_type_time
      ON analytics_events(event_type, created_at DESC);
    `);
```

- [ ] **Step 4: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- schema_aux`. Expected: 4 testes passando.

- [ ] **Step 5: Commit**

```bash
git add apps/api/server.js apps/api/__tests__/schema_aux.test.js
git commit -m "feat(billing): adicionar tabelas subscription_events, receipts e analytics_events

- subscription_events: audit trail JSONB de webhooks
- receipts: arquivos PDF gerados, com email de envio
- analytics_events: instrumentacao leve, suporta user_id null (anonimo)"
```

---

## Task 4: Schema — colunas de pagamento em schedules

**Files:**
- Modify: `apps/api/server.js` (bloco de migrations no final de `createTables`)
- Test: `apps/api/__tests__/schema_schedules_payment.test.js`

- [ ] **Step 1: Escrever teste**

Criar `apps/api/__tests__/schema_schedules_payment.test.js`:

```javascript
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');

beforeAll(async () => {
  require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
  await cleanDatabase();
});

afterAll(async () => {
  await closeDatabase();
});

describe('schedules: colunas de pagamento', () => {
  it('insert default tem status_pagamento=pendente, valor_pago=0, vencimento=null', async () => {
    const u = await pool.query(`INSERT INTO users (name, email, password_hash) VALUES ('U', 'sp1@x.com', 'x') RETURNING id`);
    const { rows } = await pool.query(
      `INSERT INTO schedules (user_id, projeto, produtora, data, hora_inicio, hora_fim, valor_total)
       VALUES ($1, 'P', 'Pr', NOW(), '10:00', '11:00', 200) RETURNING *`,
      [u.rows[0].id]
    );
    expect(rows[0].status_pagamento).toBe('pendente');
    expect(parseFloat(rows[0].valor_pago)).toBe(0);
    expect(rows[0].vencimento).toBeNull();
  });

  it('aceita status_pagamento válido', async () => {
    const u = await pool.query(`INSERT INTO users (name, email, password_hash) VALUES ('U', 'sp2@x.com', 'x') RETURNING id`);
    const { rows } = await pool.query(
      `INSERT INTO schedules (user_id, projeto, produtora, data, hora_inicio, hora_fim, valor_total, status_pagamento)
       VALUES ($1, 'P', 'Pr', NOW(), '10:00', '11:00', 200, 'pago') RETURNING *`,
      [u.rows[0].id]
    );
    expect(rows[0].status_pagamento).toBe('pago');
  });

  it('rejeita status_pagamento inválido', async () => {
    const u = await pool.query(`INSERT INTO users (name, email, password_hash) VALUES ('U', 'sp3@x.com', 'x') RETURNING id`);
    await expect(
      pool.query(
        `INSERT INTO schedules (user_id, projeto, produtora, data, hora_inicio, hora_fim, valor_total, status_pagamento)
         VALUES ($1, 'P', 'Pr', NOW(), '10:00', '11:00', 200, 'meio_pago')`,
        [u.rows[0].id]
      )
    ).rejects.toThrow();
  });
});
```

- [ ] **Step 2: Rodar teste e verificar que falha**

Run: `cd apps/api && npm test -- schema_schedules_payment`. Expected: FAIL (colunas não existem).

- [ ] **Step 3: Adicionar migrations no server.js**

Em `apps/api/server.js`, no fim da função `createTables` (após o último `try/catch` da linha 175), adicionar novo bloco:

```javascript
  try {
    await pool.query(`
      ALTER TABLE schedules ADD COLUMN IF NOT EXISTS status_pagamento TEXT
      DEFAULT 'pendente'
    `);
    // CHECK constraint adicionada via ALTER (idempotente — IF NOT EXISTS não funciona em CHECK, então faz via DO block)
    await pool.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'schedules_status_pagamento_check'
        ) THEN
          ALTER TABLE schedules
          ADD CONSTRAINT schedules_status_pagamento_check
          CHECK (status_pagamento IN ('pendente','pago','parcial','atrasado'));
        END IF;
      END $$;
    `);
    await pool.query(`ALTER TABLE schedules ADD COLUMN IF NOT EXISTS valor_pago NUMERIC(10,2) NOT NULL DEFAULT 0`);
    await pool.query(`ALTER TABLE schedules ADD COLUMN IF NOT EXISTS vencimento DATE NULL`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_schedules_status_pagamento ON schedules(user_id, status_pagamento)`);
  } catch (err) {
    console.error('❌ Erro na migration schedules.pagamento:', err);
  }
```

- [ ] **Step 4: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- schema_schedules_payment`. Expected: 3 testes passando.

- [ ] **Step 5: Commit**

```bash
git add apps/api/server.js apps/api/__tests__/schema_schedules_payment.test.js
git commit -m "feat(schedules): adicionar campos de status de pagamento

- status_pagamento (pendente/pago/parcial/atrasado) com default 'pendente'
- valor_pago NUMERIC default 0 pra suportar pagamento parcial
- vencimento DATE opcional pra lembretes de cobranca
- Indice em (user_id, status_pagamento) pra GET /receipts/pending"
```

---

## Task 5: Serviço de entitlement

A "fonte de verdade" do Pro. Esse serviço é consumido tanto pelo endpoint `/me/entitlements` quanto pelo middleware `require_pro`.

**Files:**
- Create: `apps/api/services/entitlement.js`
- Test: `apps/api/__tests__/entitlement.test.js`

- [ ] **Step 1: Escrever teste**

Criar `apps/api/__tests__/entitlement.test.js`:

```javascript
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const { getEntitlement } = require('../services/entitlement');

beforeAll(async () => {
  require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
});

beforeEach(async () => {
  await cleanDatabase();
});

afterAll(async () => {
  await closeDatabase();
});

describe('getEntitlement(userId)', () => {
  it('retorna { pro: false } pra usuário sem assinatura', async () => {
    const { user } = await createTestUser();
    const ent = await getEntitlement(user.id);
    expect(ent).toEqual({ pro: false, trial: false, until: null, source: null, cancelAtPeriodEnd: false });
  });

  it('retorna pro:true e trial:false pra assinatura active', async () => {
    const { user } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_a1', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );
    const ent = await getEntitlement(user.id);
    expect(ent.pro).toBe(true);
    expect(ent.trial).toBe(false);
    expect(ent.source).toBe('stripe');
    expect(ent.cancelAtPeriodEnd).toBe(false);
    expect(new Date(ent.until).getTime()).toBeGreaterThan(Date.now());
  });

  it('retorna trial:true pra status=trialing', async () => {
    const { user } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end, trial_ends_at)
       VALUES ($1, 'play', 'play_token_t1', 'pro_monthly', 'trialing', NOW() + INTERVAL '7 days', NOW() + INTERVAL '7 days')`,
      [user.id]
    );
    const ent = await getEntitlement(user.id);
    expect(ent.pro).toBe(true);
    expect(ent.trial).toBe(true);
    expect(ent.source).toBe('play');
  });

  it('retorna pro:false pra status=expired', async () => {
    const { user } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_exp', 'pro_monthly', 'expired', NOW() - INTERVAL '1 day')`,
      [user.id]
    );
    const ent = await getEntitlement(user.id);
    expect(ent.pro).toBe(false);
  });

  it('escolhe a assinatura com current_period_end mais distante quando há múltiplas', async () => {
    const { user } = await createTestUser();
    // play vence em 10 dias, stripe vence em 30 — deve retornar stripe
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'play', 'play_old', 'pro_monthly', 'active', NOW() + INTERVAL '10 days')`,
      [user.id]
    );
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'stripe_new', 'pro_annual', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );
    const ent = await getEntitlement(user.id);
    expect(ent.source).toBe('stripe');
  });
});
```

- [ ] **Step 2: Rodar teste e verificar que falha**

Run: `cd apps/api && npm test -- entitlement`. Expected: FAIL (módulo não existe).

- [ ] **Step 3: Implementar o serviço**

Criar `apps/api/services/entitlement.js`:

```javascript
const pool = require('../db');

// Status que conferem acesso Pro ao usuário
const PRO_STATUSES = ['trialing', 'active'];

async function getEntitlement(userId) {
  const { rows } = await pool.query(
    `SELECT source, status, current_period_end, cancel_at_period_end, trial_ends_at
       FROM subscriptions
      WHERE user_id = $1
        AND status = ANY($2)
        AND current_period_end > NOW()
      ORDER BY current_period_end DESC
      LIMIT 1`,
    [userId, PRO_STATUSES]
  );

  if (rows.length === 0) {
    return {
      pro: false,
      trial: false,
      until: null,
      source: null,
      cancelAtPeriodEnd: false,
    };
  }

  const row = rows[0];
  return {
    pro: true,
    trial: row.status === 'trialing',
    until: row.current_period_end,
    source: row.source,
    cancelAtPeriodEnd: row.cancel_at_period_end,
  };
}

module.exports = { getEntitlement, PRO_STATUSES };
```

- [ ] **Step 4: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- entitlement`. Expected: 5 testes passando.

- [ ] **Step 5: Commit**

```bash
git add apps/api/services/entitlement.js apps/api/__tests__/entitlement.test.js
git commit -m "feat(billing): adicionar service de entitlement

- getEntitlement(userId) consulta subscriptions e retorna estado Pro
- Considera apenas status 'trialing' ou 'active' com periodo ativo
- Em caso de multiplas assinaturas, retorna a com periodo mais distante
- Modulo unico, consumido por endpoint /me/entitlements e middleware require_pro"
```

---

## Task 6: Endpoint GET /me/entitlements

**Files:**
- Create: `apps/api/routes/billing.js`
- Modify: `apps/api/server.js` (montar rota)
- Test: `apps/api/__tests__/billing_entitlements.test.js`

- [ ] **Step 1: Escrever teste**

Criar `apps/api/__tests__/billing_entitlements.test.js`:

```javascript
const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');

let app;

beforeAll(async () => {
  app = require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
});

beforeEach(async () => {
  await cleanDatabase();
});

afterAll(async () => {
  await closeDatabase();
});

describe('GET /me/entitlements', () => {
  it('exige autenticação', async () => {
    const res = await request(app).get('/me/entitlements');
    expect(res.status).toBe(401);
  });

  it('retorna pro:false pra usuário Free', async () => {
    const { token } = await createTestUser();
    const res = await request(app)
      .get('/me/entitlements')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.pro).toBe(false);
  });

  it('retorna pro:true pra usuário com assinatura active', async () => {
    const { user, token } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_ok', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );
    const res = await request(app)
      .get('/me/entitlements')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.pro).toBe(true);
    expect(res.body.source).toBe('stripe');
    expect(res.body.trial).toBe(false);
  });
});
```

- [ ] **Step 2: Rodar teste e verificar que falha**

Run: `cd apps/api && npm test -- billing_entitlements`. Expected: 404 em todos (rota não existe).

- [ ] **Step 3: Criar a rota billing.js**

Criar `apps/api/routes/billing.js`:

```javascript
const router = require('express').Router();
const auth = require('../middleware/auth');
const { getEntitlement } = require('../services/entitlement');

// Express-rate-limit é overkill aqui pra MVP; a app já tem rate limit global se necessário
router.get('/me/entitlements', auth, async (req, res) => {
  try {
    const ent = await getEntitlement(req.user.id);
    res.json(ent);
  } catch (err) {
    console.error('❌ /me/entitlements:', err);
    res.status(500).json({ error: 'Erro ao consultar entitlement' });
  }
});

module.exports = router;
```

- [ ] **Step 4: Montar a rota em server.js**

Modificar `apps/api/server.js`. Após a linha que monta `diretoresRoutes` (linha 186):

```javascript
const billingRoutes = require('./routes/billing');
// ... outras linhas

app.use('/auth', authRoutes);
app.use('/schedules', schedulesRoutes);
app.use('/produtoras', produtorasRoutes);
app.use('/projetos', projetosRoutes);
app.use('/diretores', diretoresRoutes);
app.use('/', billingRoutes);  // ← billing usa paths absolutos como /me/entitlements
```

A linha de `require` deve ir junto com os outros requires no topo (linhas 11-15). E a montagem (`app.use('/', billingRoutes)`) vai junto com as outras (linha 182+).

- [ ] **Step 5: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- billing_entitlements`. Expected: 3 testes passando.

- [ ] **Step 6: Commit**

```bash
git add apps/api/routes/billing.js apps/api/server.js apps/api/__tests__/billing_entitlements.test.js
git commit -m "feat(billing): adicionar GET /me/entitlements

- Endpoint autenticado retorna estado Pro do usuario
- Consome service getEntitlement (DRY)
- Resposta: { pro, trial, until, source, cancelAtPeriodEnd }
- Cliente cacheia por ~15min, mas backend e fonte de verdade"
```

---

## Task 7: Middleware require_pro

Pra proteger endpoints que exigem assinatura Pro (recibos, etc).

**Files:**
- Create: `apps/api/middleware/require_pro.js`
- Test: `apps/api/__tests__/require_pro.test.js`

- [ ] **Step 1: Escrever teste**

Criar `apps/api/__tests__/require_pro.test.js`:

```javascript
const express = require('express');
const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const auth = require('../middleware/auth');
const requirePro = require('../middleware/require_pro');

beforeAll(async () => {
  require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
});

beforeEach(async () => {
  await cleanDatabase();
});

afterAll(async () => {
  await closeDatabase();
});

function makeApp() {
  const app = express();
  app.use(express.json());
  app.get('/protected', auth, requirePro, (req, res) => {
    res.json({ ok: true });
  });
  return app;
}

describe('middleware requirePro', () => {
  it('bloqueia usuário Free com 402 Payment Required', async () => {
    const { token } = await createTestUser();
    const res = await request(makeApp())
      .get('/protected')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(402);
    expect(res.body.error).toMatch(/pro/i);
  });

  it('libera usuário Pro', async () => {
    const { user, token } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_pro1', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );
    const res = await request(makeApp())
      .get('/protected')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
  });

  it('libera usuário em trial', async () => {
    const { user, token } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end, trial_ends_at)
       VALUES ($1, 'play', 'play_t1', 'pro_monthly', 'trialing', NOW() + INTERVAL '7 days', NOW() + INTERVAL '7 days')`,
      [user.id]
    );
    const res = await request(makeApp())
      .get('/protected')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
  });
});
```

- [ ] **Step 2: Rodar teste e verificar que falha**

Run: `cd apps/api && npm test -- require_pro`. Expected: FAIL (módulo não existe).

- [ ] **Step 3: Implementar o middleware**

Criar `apps/api/middleware/require_pro.js`:

```javascript
const { getEntitlement } = require('../services/entitlement');

async function requirePro(req, res, next) {
  try {
    const ent = await getEntitlement(req.user.id);
    if (!ent.pro) {
      return res.status(402).json({
        error: 'Esta funcionalidade exige uma assinatura Pro ativa.',
        code: 'PRO_REQUIRED',
      });
    }
    req.entitlement = ent;
    next();
  } catch (err) {
    console.error('❌ requirePro:', err);
    res.status(500).json({ error: 'Erro ao validar assinatura' });
  }
}

module.exports = requirePro;
```

- [ ] **Step 4: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- require_pro`. Expected: 3 testes passando.

- [ ] **Step 5: Commit**

```bash
git add apps/api/middleware/require_pro.js apps/api/__tests__/require_pro.test.js
git commit -m "feat(billing): middleware requirePro

- Retorna 402 Payment Required pra usuario Free
- Libera trialing e active
- Anexa req.entitlement pra reuso no handler
- Reusa service getEntitlement (DRY)"
```

---

## Task 8: Endpoint Stripe — POST /billing/stripe/checkout

Cria uma Stripe Checkout Session e retorna URL pra o cliente redirecionar.

**Files:**
- Modify: `apps/api/package.json` (adicionar `stripe`)
- Create: `apps/api/services/stripe.js`
- Modify: `apps/api/routes/billing.js` (adicionar handler)
- Test: `apps/api/__tests__/billing_stripe_checkout.test.js`

- [ ] **Step 1: Instalar SDK Stripe**

Run:
```bash
cd apps/api && npm install stripe
```

- [ ] **Step 2: Criar wrapper stripe.js**

Criar `apps/api/services/stripe.js`:

```javascript
const Stripe = require('stripe');

const stripeKey = process.env.STRIPE_SECRET_KEY;
if (!stripeKey && process.env.NODE_ENV !== 'test') {
  console.warn('⚠️  STRIPE_SECRET_KEY não configurado — endpoints Stripe falharão');
}

// Em testes não inicializamos o SDK real
const stripe = stripeKey ? new Stripe(stripeKey, { apiVersion: '2024-10-28.acacia' }) : null;

const PRICE_IDS = {
  pro_monthly: process.env.STRIPE_PRICE_MONTHLY,
  pro_annual: process.env.STRIPE_PRICE_ANNUAL,
};

async function createCheckoutSession({ userId, userEmail, plan, successUrl, cancelUrl }) {
  if (!stripe) throw new Error('Stripe não configurado');
  const priceId = PRICE_IDS[plan];
  if (!priceId) throw new Error(`Plano inválido: ${plan}`);

  return stripe.checkout.sessions.create({
    mode: 'subscription',
    line_items: [{ price: priceId, quantity: 1 }],
    subscription_data: {
      trial_period_days: 7,
      metadata: { user_id: String(userId) },
    },
    customer_email: userEmail,
    success_url: successUrl,
    cancel_url: cancelUrl,
    metadata: { user_id: String(userId) },
  });
}

async function createPortalSession({ customerId, returnUrl }) {
  if (!stripe) throw new Error('Stripe não configurado');
  return stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: returnUrl,
  });
}

module.exports = { stripe, createCheckoutSession, createPortalSession, PRICE_IDS };
```

- [ ] **Step 3: Escrever teste com mock**

Criar `apps/api/__tests__/billing_stripe_checkout.test.js`:

```javascript
jest.mock('../services/stripe', () => ({
  createCheckoutSession: jest.fn(),
  PRICE_IDS: { pro_monthly: 'price_test_m', pro_annual: 'price_test_a' },
}));

const request = require('supertest');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const { createCheckoutSession } = require('../services/stripe');

let app;

beforeAll(async () => {
  app = require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
});

beforeEach(async () => {
  await cleanDatabase();
  createCheckoutSession.mockReset();
});

afterAll(async () => {
  await closeDatabase();
});

describe('POST /billing/stripe/checkout', () => {
  it('exige autenticação', async () => {
    const res = await request(app).post('/billing/stripe/checkout').send({ plan: 'pro_monthly' });
    expect(res.status).toBe(401);
  });

  it('retorna 400 pra plan inválido', async () => {
    const { token } = await createTestUser();
    const res = await request(app)
      .post('/billing/stripe/checkout')
      .set('Authorization', `Bearer ${token}`)
      .send({ plan: 'pro_lifetime' });
    expect(res.status).toBe(400);
  });

  it('cria session e retorna url', async () => {
    createCheckoutSession.mockResolvedValueOnce({
      id: 'cs_test_123',
      url: 'https://checkout.stripe.com/c/pay/cs_test_123',
    });
    const { user, token } = await createTestUser();
    const res = await request(app)
      .post('/billing/stripe/checkout')
      .set('Authorization', `Bearer ${token}`)
      .send({ plan: 'pro_annual' });
    expect(res.status).toBe(200);
    expect(res.body.url).toMatch(/checkout\.stripe\.com/);
    expect(createCheckoutSession).toHaveBeenCalledWith(expect.objectContaining({
      userId: user.id,
      userEmail: user.email,
      plan: 'pro_annual',
    }));
  });
});
```

- [ ] **Step 4: Rodar teste e verificar que falha**

Run: `cd apps/api && npm test -- billing_stripe_checkout`. Expected: rotas retornam 404.

- [ ] **Step 5: Adicionar handler em routes/billing.js**

Modificar `apps/api/routes/billing.js` — adicionar imports e novo handler:

```javascript
const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const auth = require('../middleware/auth');
const { getEntitlement } = require('../services/entitlement');
const { createCheckoutSession, PRICE_IDS } = require('../services/stripe');

router.get('/me/entitlements', auth, async (req, res) => {
  try {
    const ent = await getEntitlement(req.user.id);
    res.json(ent);
  } catch (err) {
    console.error('❌ /me/entitlements:', err);
    res.status(500).json({ error: 'Erro ao consultar entitlement' });
  }
});

router.post(
  '/billing/stripe/checkout',
  auth,
  body('plan').isIn(Object.keys(PRICE_IDS)),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Plano inválido', details: errors.array() });
    }
    try {
      const baseUrl = process.env.FRONTEND_WEB_URL || 'https://app.dublydesk.com';
      const session = await createCheckoutSession({
        userId: req.user.id,
        userEmail: req.user.email,
        plan: req.body.plan,
        successUrl: `${baseUrl}/pro/success?session_id={CHECKOUT_SESSION_ID}`,
        cancelUrl: `${baseUrl}/pro`,
      });
      res.json({ id: session.id, url: session.url });
    } catch (err) {
      console.error('❌ stripe/checkout:', err);
      res.status(500).json({ error: 'Erro ao criar sessão de checkout' });
    }
  }
);

module.exports = router;
```

- [ ] **Step 6: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- billing_stripe_checkout`. Expected: 3 testes passando.

- [ ] **Step 7: Adicionar var em .env.example**

Modificar `apps/api/.env.example` (criar se não existir):

```env
PORT=3000
DATABASE_URL=postgresql://user:pass@host:5432/dublagem
JWT_SECRET=trocar_em_producao

# Email SMTP
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=email@gmail.com
SMTP_PASS=app_password_gmail

# CORS
FRONTEND_ORIGIN=*

# Stripe (billing web)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_MONTHLY=price_...
STRIPE_PRICE_ANNUAL=price_...

# URL do PWA (usada em redirect do Stripe Checkout)
FRONTEND_WEB_URL=https://app.dublydesk.com

# Google Play (billing Android)
PLAY_PACKAGE_NAME=br.com.dublydesk.app
PLAY_SERVICE_ACCOUNT_PATH=./.secrets/play-service-account.json
```

- [ ] **Step 8: Commit**

```bash
git add apps/api/package.json apps/api/package-lock.json apps/api/services/stripe.js apps/api/routes/billing.js apps/api/__tests__/billing_stripe_checkout.test.js apps/api/.env.example
git commit -m "feat(billing): adicionar POST /billing/stripe/checkout

- Wrapper services/stripe.js encapsula SDK
- Endpoint cria Checkout Session com trial 7d e metadata user_id
- Validacao de plan (pro_monthly | pro_annual)
- Retorna { id, url } pro cliente redirecionar
- .env.example atualizado com vars Stripe + FRONTEND_WEB_URL"
```

---

## Task 9: Endpoint Stripe — POST /billing/stripe/webhook

Recebe eventos do Stripe e atualiza `subscriptions`. Validação de assinatura HMAC obrigatória.

**Files:**
- Modify: `apps/api/routes/billing.js`
- Modify: `apps/api/server.js` (raw body pra webhook)
- Test: `apps/api/__tests__/billing_stripe_webhook.test.js`

- [ ] **Step 1: Configurar express pra aceitar raw body em webhook**

Modificar `apps/api/server.js`. **Antes** do `app.use(express.json())` (linha 27), adicionar:

```javascript
// Stripe webhook precisa do raw body pra validação de assinatura HMAC.
// Esse middleware roda ANTES do express.json() pra preservar o buffer original.
app.use('/billing/stripe/webhook', express.raw({ type: 'application/json' }));
```

- [ ] **Step 2: Escrever teste**

Criar `apps/api/__tests__/billing_stripe_webhook.test.js`:

```javascript
jest.mock('../services/stripe', () => {
  const real = jest.requireActual('../services/stripe');
  return {
    ...real,
    stripe: {
      webhooks: {
        constructEvent: jest.fn(),
      },
    },
  };
});

const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const { stripe } = require('../services/stripe');

let app;

beforeAll(async () => {
  app = require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
});

beforeEach(async () => {
  await cleanDatabase();
  stripe.webhooks.constructEvent.mockReset();
});

afterAll(async () => {
  await closeDatabase();
});

describe('POST /billing/stripe/webhook', () => {
  it('rejeita sem header Stripe-Signature', async () => {
    stripe.webhooks.constructEvent.mockImplementation(() => {
      throw new Error('No signature');
    });
    const res = await request(app)
      .post('/billing/stripe/webhook')
      .set('Content-Type', 'application/json')
      .send('{}');
    expect(res.status).toBe(400);
  });

  it('processa customer.subscription.created e insere em subscriptions', async () => {
    const { user } = await createTestUser();
    stripe.webhooks.constructEvent.mockReturnValue({
      type: 'customer.subscription.created',
      data: {
        object: {
          id: 'sub_stripe_evt1',
          status: 'trialing',
          current_period_end: Math.floor((Date.now() + 7 * 86400000) / 1000),
          cancel_at_period_end: false,
          trial_end: Math.floor((Date.now() + 7 * 86400000) / 1000),
          items: { data: [{ price: { id: 'price_monthly_test', metadata: { plan: 'pro_monthly' } } }] },
          metadata: { user_id: String(user.id) },
        },
      },
    });

    const res = await request(app)
      .post('/billing/stripe/webhook')
      .set('Stripe-Signature', 't=123,v1=abc')
      .set('Content-Type', 'application/json')
      .send('{}');
    expect(res.status).toBe(200);

    const { rows } = await pool.query(`SELECT * FROM subscriptions WHERE user_id = $1`, [user.id]);
    expect(rows).toHaveLength(1);
    expect(rows[0].source).toBe('stripe');
    expect(rows[0].external_id).toBe('sub_stripe_evt1');
    expect(rows[0].status).toBe('trialing');
  });

  it('processa customer.subscription.deleted e marca expired', async () => {
    const { user } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_to_delete', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );
    stripe.webhooks.constructEvent.mockReturnValue({
      type: 'customer.subscription.deleted',
      data: {
        object: {
          id: 'sub_to_delete',
          status: 'canceled',
          current_period_end: Math.floor(Date.now() / 1000),
          metadata: { user_id: String(user.id) },
        },
      },
    });
    const res = await request(app)
      .post('/billing/stripe/webhook')
      .set('Stripe-Signature', 't=123,v1=abc')
      .set('Content-Type', 'application/json')
      .send('{}');
    expect(res.status).toBe(200);

    const { rows } = await pool.query(`SELECT status FROM subscriptions WHERE external_id = 'sub_to_delete'`);
    expect(rows[0].status).toBe('expired');
  });
});
```

- [ ] **Step 3: Rodar teste e verificar que falha**

Run: `cd apps/api && npm test -- billing_stripe_webhook`. Expected: FAIL (rota não existe).

- [ ] **Step 4: Implementar o handler**

Adicionar em `apps/api/routes/billing.js`, após o handler de checkout:

```javascript
const pool = require('../db');
const { stripe } = require('../services/stripe');

router.post('/billing/stripe/webhook', async (req, res) => {
  const signature = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;
  try {
    event = stripe.webhooks.constructEvent(req.body, signature, webhookSecret);
  } catch (err) {
    console.error('❌ Stripe webhook signature invalid:', err.message);
    return res.status(400).json({ error: 'Invalid signature' });
  }

  try {
    await handleStripeEvent(event);
    res.status(200).json({ received: true });
  } catch (err) {
    console.error('❌ Stripe webhook handler:', err);
    res.status(500).json({ error: 'Handler error' });
  }
});

async function handleStripeEvent(event) {
  const sub = event.data.object;
  const userId = parseInt(sub.metadata?.user_id, 10);
  if (!userId) {
    console.warn('⚠️  Evento Stripe sem user_id em metadata:', event.id);
    return;
  }

  switch (event.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated': {
      const productId = sub.items?.data?.[0]?.price?.metadata?.plan
        || sub.items?.data?.[0]?.price?.id
        || 'unknown';
      const status = mapStripeStatus(sub.status);
      const currentPeriodEnd = new Date(sub.current_period_end * 1000);
      const trialEndsAt = sub.trial_end ? new Date(sub.trial_end * 1000) : null;

      await pool.query(
        `INSERT INTO subscriptions
           (user_id, source, external_id, product_id, status, current_period_end, cancel_at_period_end, trial_ends_at, updated_at)
         VALUES ($1, 'stripe', $2, $3, $4, $5, $6, $7, NOW())
         ON CONFLICT (source, external_id) DO UPDATE SET
           status = EXCLUDED.status,
           current_period_end = EXCLUDED.current_period_end,
           cancel_at_period_end = EXCLUDED.cancel_at_period_end,
           trial_ends_at = EXCLUDED.trial_ends_at,
           updated_at = NOW()`,
        [userId, sub.id, productId, status, currentPeriodEnd, sub.cancel_at_period_end || false, trialEndsAt]
      );
      break;
    }
    case 'customer.subscription.deleted': {
      await pool.query(
        `UPDATE subscriptions SET status = 'expired', updated_at = NOW()
         WHERE source = 'stripe' AND external_id = $1`,
        [sub.id]
      );
      break;
    }
    default:
      console.log(`ℹ️  Stripe event ignorado: ${event.type}`);
  }

  // Audit trail
  const { rows: subRows } = await pool.query(
    `SELECT id FROM subscriptions WHERE source = 'stripe' AND external_id = $1`,
    [sub.id]
  );
  if (subRows.length > 0) {
    await pool.query(
      `INSERT INTO subscription_events (subscription_id, type, raw_payload) VALUES ($1, $2, $3)`,
      [subRows[0].id, event.type, JSON.stringify(event)]
    );
  }
}

function mapStripeStatus(stripeStatus) {
  // Stripe usa: trialing, active, past_due, canceled, unpaid, incomplete, incomplete_expired
  const map = {
    trialing: 'trialing',
    active: 'active',
    past_due: 'past_due',
    canceled: 'cancelled',
    unpaid: 'past_due',
    incomplete: 'past_due',
    incomplete_expired: 'expired',
  };
  return map[stripeStatus] || 'expired';
}
```

- [ ] **Step 5: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- billing_stripe_webhook`. Expected: 3 testes passando.

- [ ] **Step 6: Commit**

```bash
git add apps/api/routes/billing.js apps/api/server.js apps/api/__tests__/billing_stripe_webhook.test.js
git commit -m "feat(billing): adicionar POST /billing/stripe/webhook

- Raw body parser ANTES de express.json pra preservar buffer
- Validacao HMAC obrigatoria via stripe.webhooks.constructEvent
- Handler idempotente (ON CONFLICT do UPSERT)
- Mapeamento de status Stripe -> nosso enum
- Audit trail em subscription_events"
```

---

## Task 10: Endpoint Play Billing — POST /billing/play/verify

Recebe purchaseToken do app Android e valida via Google Play Developer API.

**Files:**
- Modify: `apps/api/package.json` (adicionar `googleapis`)
- Create: `apps/api/services/play_billing.js`
- Modify: `apps/api/routes/billing.js`
- Test: `apps/api/__tests__/billing_play_verify.test.js`

- [ ] **Step 1: Instalar googleapis**

Run:
```bash
cd apps/api && npm install googleapis
```

- [ ] **Step 2: Criar wrapper play_billing.js**

Criar `apps/api/services/play_billing.js`:

```javascript
const { google } = require('googleapis');

let androidPublisher = null;

function getClient() {
  if (androidPublisher) return androidPublisher;

  const keyPath = process.env.PLAY_SERVICE_ACCOUNT_PATH;
  if (!keyPath) {
    throw new Error('PLAY_SERVICE_ACCOUNT_PATH não configurado');
  }

  const auth = new google.auth.GoogleAuth({
    keyFile: keyPath,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  androidPublisher = google.androidpublisher({ version: 'v3', auth });
  return androidPublisher;
}

async function verifySubscription({ packageName, subscriptionId, purchaseToken }) {
  const client = getClient();
  const res = await client.purchases.subscriptionsv2.get({
    packageName,
    token: purchaseToken,
  });
  return res.data;
}

function mapPlayState(state) {
  // SUBSCRIPTION_STATE_ACTIVE, _PAUSED, _IN_GRACE_PERIOD, _ON_HOLD, _CANCELED, _EXPIRED, _PENDING
  const map = {
    SUBSCRIPTION_STATE_ACTIVE: 'active',
    SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 'past_due',
    SUBSCRIPTION_STATE_ON_HOLD: 'past_due',
    SUBSCRIPTION_STATE_PAUSED: 'past_due',
    SUBSCRIPTION_STATE_CANCELED: 'cancelled',
    SUBSCRIPTION_STATE_EXPIRED: 'expired',
    SUBSCRIPTION_STATE_PENDING: 'trialing',
  };
  return map[state] || 'expired';
}

module.exports = { verifySubscription, mapPlayState };
```

- [ ] **Step 3: Escrever teste com mock**

Criar `apps/api/__tests__/billing_play_verify.test.js`:

```javascript
jest.mock('../services/play_billing', () => ({
  verifySubscription: jest.fn(),
  mapPlayState: jest.requireActual('../services/play_billing').mapPlayState,
}));

const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const { verifySubscription } = require('../services/play_billing');

let app;

beforeAll(async () => {
  app = require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
});

beforeEach(async () => {
  await cleanDatabase();
  verifySubscription.mockReset();
});

afterAll(async () => {
  await closeDatabase();
});

describe('POST /billing/play/verify', () => {
  it('exige autenticação', async () => {
    const res = await request(app).post('/billing/play/verify').send({});
    expect(res.status).toBe(401);
  });

  it('valida purchaseToken e cria subscription', async () => {
    const { user, token } = await createTestUser();
    verifySubscription.mockResolvedValueOnce({
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      lineItems: [
        {
          productId: 'pro_monthly',
          expiryTime: new Date(Date.now() + 30 * 86400000).toISOString(),
        },
      ],
    });

    const res = await request(app)
      .post('/billing/play/verify')
      .set('Authorization', `Bearer ${token}`)
      .send({ purchaseToken: 'tok_abc', productId: 'pro_monthly' });

    expect(res.status).toBe(200);
    expect(res.body.pro).toBe(true);

    const { rows } = await pool.query(`SELECT * FROM subscriptions WHERE user_id = $1`, [user.id]);
    expect(rows).toHaveLength(1);
    expect(rows[0].source).toBe('play');
    expect(rows[0].external_id).toBe('tok_abc');
    expect(rows[0].status).toBe('active');
  });

  it('retorna 400 sem purchaseToken', async () => {
    const { token } = await createTestUser();
    const res = await request(app)
      .post('/billing/play/verify')
      .set('Authorization', `Bearer ${token}`)
      .send({ productId: 'pro_monthly' });
    expect(res.status).toBe(400);
  });
});
```

- [ ] **Step 4: Rodar teste e verificar que falha**

Run: `cd apps/api && npm test -- billing_play_verify`. Expected: FAIL (rota não existe).

- [ ] **Step 5: Implementar handler**

Adicionar em `apps/api/routes/billing.js`, após webhook Stripe:

```javascript
const { verifySubscription, mapPlayState } = require('../services/play_billing');
const { getEntitlement } = require('../services/entitlement');

router.post(
  '/billing/play/verify',
  auth,
  body('purchaseToken').isString().notEmpty(),
  body('productId').isIn(['pro_monthly', 'pro_annual']),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Parâmetros inválidos', details: errors.array() });
    }

    const { purchaseToken, productId } = req.body;
    const packageName = process.env.PLAY_PACKAGE_NAME;

    try {
      const playData = await verifySubscription({ packageName, subscriptionId: productId, purchaseToken });
      const status = mapPlayState(playData.subscriptionState);
      const expiryRaw = playData.lineItems?.[0]?.expiryTime;
      const currentPeriodEnd = expiryRaw ? new Date(expiryRaw) : new Date();

      await pool.query(
        `INSERT INTO subscriptions
           (user_id, source, external_id, product_id, status, current_period_end, updated_at)
         VALUES ($1, 'play', $2, $3, $4, $5, NOW())
         ON CONFLICT (source, external_id) DO UPDATE SET
           status = EXCLUDED.status,
           current_period_end = EXCLUDED.current_period_end,
           updated_at = NOW()`,
        [req.user.id, purchaseToken, productId, status, currentPeriodEnd]
      );

      const ent = await getEntitlement(req.user.id);
      res.json(ent);
    } catch (err) {
      console.error('❌ play/verify:', err);
      res.status(500).json({ error: 'Erro ao validar compra Play' });
    }
  }
);
```

- [ ] **Step 6: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- billing_play_verify`. Expected: 3 testes passando.

- [ ] **Step 7: Commit**

```bash
git add apps/api/package.json apps/api/package-lock.json apps/api/services/play_billing.js apps/api/routes/billing.js apps/api/__tests__/billing_play_verify.test.js
git commit -m "feat(billing): adicionar POST /billing/play/verify

- Wrapper services/play_billing.js encapsula googleapis Play Publisher
- Endpoint valida purchaseToken via Google Play Developer API
- Mapeia SubscriptionState do Play -> nosso enum (active/expired/etc)
- Upsert idempotente em subscriptions
- Retorna entitlement atualizado pro cliente"
```

---

## Task 11: Endpoints auxiliares — restore, portal, listagem

Três endpoints menores ficam juntos pra economizar churn de commit.

**Files:**
- Modify: `apps/api/routes/billing.js`
- Test: `apps/api/__tests__/billing_aux.test.js`

- [ ] **Step 1: Escrever testes**

Criar `apps/api/__tests__/billing_aux.test.js`:

```javascript
jest.mock('../services/play_billing', () => ({
  verifySubscription: jest.fn(),
  mapPlayState: jest.requireActual('../services/play_billing').mapPlayState,
}));
jest.mock('../services/stripe', () => {
  const real = jest.requireActual('../services/stripe');
  return {
    ...real,
    createPortalSession: jest.fn(),
  };
});

const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const { verifySubscription } = require('../services/play_billing');
const { createPortalSession } = require('../services/stripe');

let app;

beforeAll(async () => {
  app = require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
});

beforeEach(async () => {
  await cleanDatabase();
  verifySubscription.mockReset();
  createPortalSession.mockReset();
});

afterAll(async () => {
  await closeDatabase();
});

describe('POST /billing/restore (Android)', () => {
  it('re-valida purchase tokens existentes e atualiza status', async () => {
    const { user, token } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'play', 'tok_restore', 'pro_monthly', 'expired', NOW() - INTERVAL '1 day')`,
      [user.id]
    );
    verifySubscription.mockResolvedValueOnce({
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      lineItems: [{ expiryTime: new Date(Date.now() + 30 * 86400000).toISOString() }],
    });

    const res = await request(app)
      .post('/billing/restore')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.pro).toBe(true);

    const { rows } = await pool.query(`SELECT status FROM subscriptions WHERE external_id = 'tok_restore'`);
    expect(rows[0].status).toBe('active');
  });

  it('retorna entitlement vazio se usuário não tem subscriptions Play', async () => {
    const { token } = await createTestUser();
    const res = await request(app)
      .post('/billing/restore')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.pro).toBe(false);
  });
});

describe('POST /billing/stripe/portal', () => {
  it('retorna URL do Customer Portal', async () => {
    const { user, token } = await createTestUser();
    // Simulando que o usuário já tem um subscription Stripe (e portanto um customer ID em metadata)
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_portal_test', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );
    // Endpoint precisaria buscar o customer_id; por simplicidade no MVP, exigimos
    // que o cliente envie no body (vem da Checkout Session salva no Step 8)
    createPortalSession.mockResolvedValueOnce({ url: 'https://billing.stripe.com/portal/abc' });

    const res = await request(app)
      .post('/billing/stripe/portal')
      .set('Authorization', `Bearer ${token}`)
      .send({ customerId: 'cus_test_123' });
    expect(res.status).toBe(200);
    expect(res.body.url).toMatch(/stripe\.com\/portal/);
  });
});
```

- [ ] **Step 2: Rodar e verificar falha**

Run: `cd apps/api && npm test -- billing_aux`. Expected: 404 em todos.

- [ ] **Step 3: Implementar handlers**

Adicionar em `apps/api/routes/billing.js`:

```javascript
const { createPortalSession } = require('../services/stripe');

router.post('/billing/restore', auth, async (req, res) => {
  const packageName = process.env.PLAY_PACKAGE_NAME;

  try {
    const { rows: subs } = await pool.query(
      `SELECT id, external_id, product_id FROM subscriptions
        WHERE user_id = $1 AND source = 'play'`,
      [req.user.id]
    );

    for (const sub of subs) {
      try {
        const playData = await verifySubscription({
          packageName,
          subscriptionId: sub.product_id,
          purchaseToken: sub.external_id,
        });
        const status = mapPlayState(playData.subscriptionState);
        const expiryRaw = playData.lineItems?.[0]?.expiryTime;
        const currentPeriodEnd = expiryRaw ? new Date(expiryRaw) : new Date();
        await pool.query(
          `UPDATE subscriptions SET status = $1, current_period_end = $2, updated_at = NOW() WHERE id = $3`,
          [status, currentPeriodEnd, sub.id]
        );
      } catch (err) {
        console.warn(`⚠️  Não consegui re-validar sub ${sub.id}:`, err.message);
      }
    }

    const ent = await getEntitlement(req.user.id);
    res.json(ent);
  } catch (err) {
    console.error('❌ /billing/restore:', err);
    res.status(500).json({ error: 'Erro ao restaurar compras' });
  }
});

router.post(
  '/billing/stripe/portal',
  auth,
  body('customerId').isString().notEmpty(),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'customerId obrigatório' });
    }
    try {
      const session = await createPortalSession({
        customerId: req.body.customerId,
        returnUrl: process.env.FRONTEND_WEB_URL || 'https://app.dublydesk.com',
      });
      res.json({ url: session.url });
    } catch (err) {
      console.error('❌ stripe/portal:', err);
      res.status(500).json({ error: 'Erro ao abrir portal' });
    }
  }
);
```

- [ ] **Step 4: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- billing_aux`. Expected: 3 testes passando.

- [ ] **Step 5: Commit**

```bash
git add apps/api/routes/billing.js apps/api/__tests__/billing_aux.test.js
git commit -m "feat(billing): adicionar /restore (Android) e /stripe/portal

- POST /billing/restore: re-valida todos os purchase tokens Play
  do usuario via Play Developer API e atualiza status
- POST /billing/stripe/portal: gera Customer Portal URL pra
  autoatendimento (cancelar, trocar cartao, etc)
- Ambos sao reutilizados pelo cliente via UI 'Restaurar compras'
  e 'Gerenciar assinatura'"
```

---

## Task 12: Geração de PDF de recibo

**Files:**
- Modify: `apps/api/package.json` (adicionar `pdfkit`)
- Create: `apps/api/services/pdf_generator.js`
- Test: `apps/api/__tests__/pdf_generator.test.js`

- [ ] **Step 1: Instalar pdfkit**

Run:
```bash
cd apps/api && npm install pdfkit
```

- [ ] **Step 2: Escrever teste**

Criar `apps/api/__tests__/pdf_generator.test.js`:

```javascript
const fs = require('fs');
const path = require('path');
const { generateReceiptPdf } = require('../services/pdf_generator');

describe('generateReceiptPdf', () => {
  const outDir = path.join(__dirname, '.tmp');
  beforeAll(() => fs.mkdirSync(outDir, { recursive: true }));

  it('gera um arquivo PDF válido', async () => {
    const outPath = path.join(outDir, 'test-receipt.pdf');
    await generateReceiptPdf({
      outPath,
      dublador: { nome: 'João Silva', email: 'joao@example.com', cpf: '123.456.789-00' },
      produtora: 'Estúdio ABC',
      projeto: 'Filme XYZ',
      diretor: 'Maria Dir',
      data: new Date('2026-05-10'),
      valor: 1500.5,
      observacao: 'Pagamento referente a sessão de gravação.',
    });

    expect(fs.existsSync(outPath)).toBe(true);
    const buf = fs.readFileSync(outPath);
    // Header de PDF v1.x começa com %PDF-
    expect(buf.slice(0, 5).toString()).toBe('%PDF-');
    expect(buf.length).toBeGreaterThan(1000); // Sanity: PDF não-trivial
  });

  it('lida com acentos no nome (Helvetica + WinAnsi não dá conta de tudo, usar fonte fallback)', async () => {
    const outPath = path.join(outDir, 'test-receipt-accents.pdf');
    await expect(
      generateReceiptPdf({
        outPath,
        dublador: { nome: 'João Pessôa de Sá', email: 'joao@x.com' },
        produtora: 'Produção Áudio LTDA',
        projeto: 'Animação Brasileiríssima',
        data: new Date(),
        valor: 999.99,
      })
    ).resolves.not.toThrow();
    expect(fs.existsSync(outPath)).toBe(true);
  });

  afterAll(() => {
    fs.rmSync(outDir, { recursive: true, force: true });
  });
});
```

- [ ] **Step 3: Rodar e verificar falha**

Run: `cd apps/api && npm test -- pdf_generator`. Expected: FAIL (módulo não existe).

- [ ] **Step 4: Implementar generator**

Criar `apps/api/services/pdf_generator.js`:

```javascript
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

const BRL = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
const DATE_FMT = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' });

async function generateReceiptPdf({ outPath, dublador, produtora, projeto, diretor, data, valor, observacao }) {
  return new Promise((resolve, reject) => {
    const dir = path.dirname(outPath);
    fs.mkdirSync(dir, { recursive: true });

    const doc = new PDFDocument({ size: 'A4', margin: 50 });
    const stream = fs.createWriteStream(outPath);
    doc.pipe(stream);

    // PDFKit já vem com Helvetica que suporta latin-extended razoavelmente bem.
    // Pra produção robusta, embed Roboto ou similar — fora do escopo do MVP.
    doc.font('Helvetica');

    // Título
    doc.fontSize(20).text('RECIBO', { align: 'center' });
    doc.moveDown(2);

    // Bloco "Recebi de" / valor
    doc.fontSize(11);
    doc.text(`Recebi de ${produtora} a quantia de ${BRL.format(valor)},`);
    doc.moveDown(0.5);
    doc.text('referente a:');
    doc.moveDown(0.5);

    // Detalhes
    doc.text(`• Projeto: ${projeto}`);
    if (diretor) doc.text(`• Direção: ${diretor}`);
    doc.text(`• Data do serviço: ${DATE_FMT.format(data)}`);
    if (observacao) {
      doc.moveDown(0.5);
      doc.text(`Obs.: ${observacao}`);
    }

    doc.moveDown(2);
    doc.text(`Para clareza firmo o presente recibo.`, { align: 'left' });
    doc.moveDown(2);
    doc.text(DATE_FMT.format(new Date()), { align: 'right' });
    doc.moveDown(3);

    // Assinatura
    doc.text('_'.repeat(50), { align: 'center' });
    doc.fontSize(10);
    doc.text(dublador.nome, { align: 'center' });
    if (dublador.cpf) doc.text(`CPF: ${dublador.cpf}`, { align: 'center' });
    if (dublador.email) doc.text(dublador.email, { align: 'center' });

    // Rodapé discreto
    doc.fontSize(8).fillColor('#999');
    doc.text('Gerado pelo DublyDesk · dublydesk.com', 50, doc.page.height - 60, {
      width: doc.page.width - 100,
      align: 'center',
    });

    doc.end();
    stream.on('finish', () => resolve(outPath));
    stream.on('error', reject);
  });
}

module.exports = { generateReceiptPdf };
```

- [ ] **Step 5: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- pdf_generator`. Expected: 2 testes passando.

- [ ] **Step 6: Commit**

```bash
git add apps/api/package.json apps/api/package-lock.json apps/api/services/pdf_generator.js apps/api/__tests__/pdf_generator.test.js
git commit -m "feat(receipts): adicionar gerador de PDF com pdfkit

- services/pdf_generator.js cria recibo em A4 com layout simples
- Helvetica + WinAnsi cobre acentos PT-BR no MVP
- Formato BRL via Intl.NumberFormat
- Footer discreto com brand dublydesk.com
- Testes cobrem geracao valida e nomes com acentos"
```

---

## Task 13: Email sender (extrair de auth.js)

Hoje `routes/auth.js` tem nodemailer inline. Vamos extrair pra um service compartilhável.

**Files:**
- Create: `apps/api/services/email_sender.js`
- Modify: `apps/api/routes/auth.js` (consumir o service)
- Test: `apps/api/__tests__/email_sender.test.js`

- [ ] **Step 1: Escrever teste**

Criar `apps/api/__tests__/email_sender.test.js`:

```javascript
jest.mock('nodemailer', () => ({
  createTransport: jest.fn(() => ({
    sendMail: jest.fn().mockResolvedValue({ messageId: 'mock-msg-1' }),
  })),
}));

const nodemailer = require('nodemailer');
const { sendEmail } = require('../services/email_sender');

describe('sendEmail', () => {
  beforeEach(() => jest.clearAllMocks());

  it('chama sendMail com from, to, subject, html', async () => {
    await sendEmail({
      to: 'destinatario@example.com',
      subject: 'Teste',
      html: '<p>Olá</p>',
    });

    const transport = nodemailer.createTransport.mock.results[0].value;
    expect(transport.sendMail).toHaveBeenCalledWith(expect.objectContaining({
      to: 'destinatario@example.com',
      subject: 'Teste',
      html: '<p>Olá</p>',
    }));
  });

  it('aceita anexos', async () => {
    await sendEmail({
      to: 'd@x.com',
      subject: 'Recibo',
      html: '<p>Anexo</p>',
      attachments: [{ filename: 'recibo.pdf', path: '/tmp/r.pdf' }],
    });
    const transport = nodemailer.createTransport.mock.results[0].value;
    expect(transport.sendMail).toHaveBeenCalledWith(
      expect.objectContaining({ attachments: [{ filename: 'recibo.pdf', path: '/tmp/r.pdf' }] })
    );
  });
});
```

- [ ] **Step 2: Rodar e verificar falha**

Run: `cd apps/api && npm test -- email_sender`. Expected: FAIL.

- [ ] **Step 3: Implementar service**

Criar `apps/api/services/email_sender.js`:

```javascript
const nodemailer = require('nodemailer');

let transport = null;

function getTransport() {
  if (transport) return transport;

  const smtpUser = process.env.SMTP_USER ?? process.env.EMAIL_USER ?? null;
  const smtpPass = process.env.SMTP_PASS ?? process.env.EMAIL_PASS ?? null;
  const smtpHost = process.env.SMTP_HOST ?? (smtpUser ? 'smtp.gmail.com' : null);
  const smtpPort = parseInt(process.env.SMTP_PORT ?? '587');

  if (!smtpHost || !smtpUser || !smtpPass) {
    console.warn('⚠️  SMTP não configurado — emails não serão enviados');
    return null;
  }

  transport = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    auth: { user: smtpUser, pass: smtpPass },
  });
  return transport;
}

async function sendEmail({ to, subject, html, text, attachments }) {
  const t = getTransport();
  if (!t) throw new Error('SMTP não configurado');

  const fromUser = process.env.SMTP_USER ?? process.env.EMAIL_USER;
  return t.sendMail({
    from: `"DublyDesk" <${fromUser}>`,
    to,
    subject,
    text,
    html,
    attachments,
  });
}

module.exports = { sendEmail };
```

- [ ] **Step 4: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- email_sender`. Expected: 2 testes passando.

- [ ] **Step 5: Refatorar auth.js pra usar o service**

Em `apps/api/routes/auth.js`, localizar o bloco que cria o transporter e chama `transporter.sendMail` (linhas ~184-210 segundo o spec). Trocar pelo uso do service:

Antes (linhas a remover):
```javascript
const smtpHost = process.env.SMTP_HOST ?? ...;
// ... criação inline do transporter ...
await transporter.sendMail({ from, to, subject, text, html });
```

Depois:
```javascript
const { sendEmail } = require('../services/email_sender');
// ...
await sendEmail({
  to: email,
  subject: 'Redefinição de senha — DublyDesk',
  text: `Seu código de redefinição de senha é: ${token}\n\nEsse código é válido por 1 hora.`,
  html: `
    <div style="font-family:sans-serif;max-width:400px;margin:auto">
      <h2>DublyDesk — Redefinição de senha</h2>
      <p>Use o código abaixo no app para criar uma nova senha:</p>
      <h1 style="letter-spacing:8px;color:#6C63FF">${token}</h1>
      <p style="color:#888">Válido por 1 hora. Se não foi você, ignore este email.</p>
    </div>`,
});
```

- [ ] **Step 6: Rodar suite completa de auth e validar que não quebrou nada**

Run: `cd apps/api && npm test`. Expected: todos os testes passando (incluindo testes existentes de auth, se houver).

- [ ] **Step 7: Commit**

```bash
git add apps/api/services/email_sender.js apps/api/routes/auth.js apps/api/__tests__/email_sender.test.js
git commit -m "refactor(email): extrair envio de email pra service compartilhavel

- Cria services/email_sender.js com transport lazy + sendEmail
- Suporta anexos (pra recibos PDF na proxima task)
- routes/auth.js refatorado pra consumir o service (DRY)
- Comportamento de reset de senha inalterado"
```

---

## Task 14: Endpoints de recibo — POST /receipts/generate e /:id/send-email

**Files:**
- Create: `apps/api/routes/receipts.js`
- Modify: `apps/api/server.js` (montar rota)
- Test: `apps/api/__tests__/receipts.test.js`

- [ ] **Step 1: Escrever teste**

Criar `apps/api/__tests__/receipts.test.js`:

```javascript
jest.mock('../services/email_sender', () => ({
  sendEmail: jest.fn().mockResolvedValue({ messageId: 'mock' }),
}));

const fs = require('fs');
const path = require('path');
const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser, createTestSchedule } = require('./helpers/fixtures');
const { sendEmail } = require('../services/email_sender');

let app;

beforeAll(async () => {
  app = require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
});

beforeEach(async () => {
  await cleanDatabase();
  sendEmail.mockClear();
});

afterAll(async () => {
  await closeDatabase();
  // Cleanup PDFs gerados durante testes
  const uploadDir = path.join(__dirname, '..', 'uploads', 'receipts');
  if (fs.existsSync(uploadDir)) fs.rmSync(uploadDir, { recursive: true, force: true });
});

async function makeProUser() {
  const { user, token } = await createTestUser();
  await pool.query(
    `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
     VALUES ($1, 'stripe', 'sub_pro_recipe', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
    [user.id]
  );
  return { user, token };
}

describe('POST /receipts/generate', () => {
  it('bloqueia usuário Free com 402', async () => {
    const { user, token } = await createTestUser();
    const schedule = await createTestSchedule(user.id);
    const res = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduleId: schedule.id });
    expect(res.status).toBe(402);
  });

  it('gera PDF pra usuário Pro', async () => {
    const { user, token } = await makeProUser();
    const schedule = await createTestSchedule(user.id, { valor_total: 750 });
    const res = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduleId: schedule.id });
    expect(res.status).toBe(201);
    expect(res.body.id).toBeDefined();
    expect(res.body.pdfPath).toMatch(/uploads\/receipts/);

    // Confirma que registro existe no DB
    const { rows } = await pool.query(`SELECT * FROM receipts WHERE id = $1`, [res.body.id]);
    expect(rows).toHaveLength(1);

    // Confirma que arquivo existe no disco
    expect(fs.existsSync(path.join(__dirname, '..', rows[0].pdf_path))).toBe(true);
  });

  it('rejeita scheduleId que não pertence ao usuário', async () => {
    const { token: tokenA } = await makeProUser();
    const { user: userB } = await createTestUser();
    const scheduleB = await createTestSchedule(userB.id);

    const res = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ scheduleId: scheduleB.id });
    expect(res.status).toBe(404);
  });
});

describe('POST /receipts/:id/send-email', () => {
  it('envia email com PDF anexado', async () => {
    const { user, token } = await makeProUser();
    const schedule = await createTestSchedule(user.id);

    // Primeiro gera o recibo
    const gen = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduleId: schedule.id });

    const sendRes = await request(app)
      .post(`/receipts/${gen.body.id}/send-email`)
      .set('Authorization', `Bearer ${token}`)
      .send({ destinatario: 'produtora@example.com', mensagem: 'Segue recibo.' });

    expect(sendRes.status).toBe(200);
    expect(sendEmail).toHaveBeenCalledWith(expect.objectContaining({
      to: 'produtora@example.com',
      attachments: expect.arrayContaining([
        expect.objectContaining({ filename: expect.stringMatching(/\.pdf$/) }),
      ]),
    }));

    // sent_at e sent_email registrados
    const { rows } = await pool.query(`SELECT sent_email, sent_at FROM receipts WHERE id = $1`, [gen.body.id]);
    expect(rows[0].sent_email).toBe('produtora@example.com');
    expect(rows[0].sent_at).not.toBeNull();
  });
});
```

- [ ] **Step 2: Rodar e verificar falha**

Run: `cd apps/api && npm test -- receipts`. Expected: 404 em todos.

- [ ] **Step 3: Implementar a rota**

Criar `apps/api/routes/receipts.js`:

```javascript
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const auth = require('../middleware/auth');
const requirePro = require('../middleware/require_pro');
const pool = require('../db');
const { generateReceiptPdf } = require('../services/pdf_generator');
const { sendEmail } = require('../services/email_sender');

const RECEIPTS_DIR = path.join(__dirname, '..', 'uploads', 'receipts');

router.post(
  '/receipts/generate',
  auth,
  requirePro,
  body('scheduleId').isInt({ min: 1 }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'scheduleId inválido' });
    }

    try {
      const scheduleRes = await pool.query(
        `SELECT s.*, u.name AS user_name, u.email AS user_email
           FROM schedules s
           JOIN users u ON u.id = s.user_id
          WHERE s.id = $1 AND s.user_id = $2`,
        [req.body.scheduleId, req.user.id]
      );
      if (scheduleRes.rows.length === 0) {
        return res.status(404).json({ error: 'Escala não encontrada' });
      }
      const schedule = scheduleRes.rows[0];

      // Path único e não-listável
      const uniqueName = `${schedule.id}-${crypto.randomBytes(8).toString('hex')}.pdf`;
      const userDir = path.join(RECEIPTS_DIR, String(req.user.id));
      const fullPath = path.join(userDir, uniqueName);
      const relativePath = path.relative(path.join(__dirname, '..'), fullPath).replace(/\\/g, '/');

      await generateReceiptPdf({
        outPath: fullPath,
        dublador: {
          nome: schedule.user_name,
          email: schedule.user_email,
          cpf: req.body.cpf, // opcional, enviado pelo cliente
        },
        produtora: schedule.produtora,
        projeto: schedule.projeto,
        diretor: schedule.diretor,
        data: schedule.data,
        valor: parseFloat(schedule.valor_total),
        observacao: schedule.observacao,
      });

      const { rows } = await pool.query(
        `INSERT INTO receipts (user_id, schedule_id, pdf_path)
         VALUES ($1, $2, $3)
         RETURNING id, pdf_path, created_at`,
        [req.user.id, schedule.id, relativePath]
      );

      res.status(201).json({
        id: rows[0].id,
        pdfPath: rows[0].pdf_path,
        createdAt: rows[0].created_at,
      });
    } catch (err) {
      console.error('❌ /receipts/generate:', err);
      res.status(500).json({ error: 'Erro ao gerar recibo' });
    }
  }
);

router.post(
  '/receipts/:id/send-email',
  auth,
  requirePro,
  body('destinatario').isEmail(),
  body('mensagem').optional().isString(),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'destinatário inválido' });
    }

    try {
      const { rows } = await pool.query(
        `SELECT r.*, s.projeto, s.produtora, s.data
           FROM receipts r
           JOIN schedules s ON s.id = r.schedule_id
          WHERE r.id = $1 AND r.user_id = $2`,
        [req.params.id, req.user.id]
      );
      if (rows.length === 0) return res.status(404).json({ error: 'Recibo não encontrado' });
      const receipt = rows[0];

      const fullPath = path.join(__dirname, '..', receipt.pdf_path);
      if (!fs.existsSync(fullPath)) {
        return res.status(410).json({ error: 'Arquivo do recibo não está mais disponível' });
      }

      const html = `
        <div style="font-family:sans-serif;max-width:520px;margin:auto;color:#333">
          <h2>Recibo — DublyDesk</h2>
          <p>Olá,</p>
          <p>Segue em anexo o recibo referente ao projeto <strong>${receipt.projeto}</strong>.</p>
          ${req.body.mensagem ? `<p>${req.body.mensagem}</p>` : ''}
          <p style="color:#888;font-size:12px;margin-top:30px">
            Enviado automaticamente pelo DublyDesk.
          </p>
        </div>
      `;

      await sendEmail({
        to: req.body.destinatario,
        subject: `Recibo — ${receipt.projeto}`,
        html,
        attachments: [
          { filename: `recibo-${receipt.id}.pdf`, path: fullPath },
        ],
      });

      await pool.query(
        `UPDATE receipts SET sent_email = $1, sent_at = NOW() WHERE id = $2`,
        [req.body.destinatario, receipt.id]
      );

      res.json({ ok: true });
    } catch (err) {
      console.error('❌ /receipts/:id/send-email:', err);
      res.status(500).json({ error: 'Erro ao enviar email' });
    }
  }
);

module.exports = router;
```

- [ ] **Step 4: Montar a rota em server.js**

Modificar `apps/api/server.js`. Adicionar junto com os outros requires:

```javascript
const receiptsRoutes = require('./routes/receipts');
```

E após `app.use('/', billingRoutes);`:

```javascript
app.use('/', receiptsRoutes);
```

- [ ] **Step 5: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- receipts`. Expected: 4 testes passando.

- [ ] **Step 6: Commit**

```bash
git add apps/api/routes/receipts.js apps/api/server.js apps/api/__tests__/receipts.test.js
git commit -m "feat(receipts): adicionar POST /receipts/generate e /:id/send-email

- /generate cria PDF do recibo a partir de scheduleId
- Path com UUID hex (nao-listavel) + scoped por user_id
- /send-email envia email com PDF anexado via service nodemailer
- Ambos protegidos por requirePro middleware
- Audit no DB: sent_email e sent_at registrados"
```

---

## Task 15: Endpoints de cobrança — PATCH /schedules/:id/payment e GET /receipts/pending

**Files:**
- Modify: `apps/api/routes/schedules.js`
- Modify: `apps/api/routes/receipts.js`
- Test: `apps/api/__tests__/schedules_payment.test.js`

- [ ] **Step 1: Escrever testes**

Criar `apps/api/__tests__/schedules_payment.test.js`:

```javascript
const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser, createTestSchedule } = require('./helpers/fixtures');

let app;

beforeAll(async () => {
  app = require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
});

beforeEach(async () => {
  await cleanDatabase();
});

afterAll(async () => {
  await closeDatabase();
});

describe('PATCH /schedules/:id/payment', () => {
  it('atualiza status_pagamento, valor_pago e vencimento', async () => {
    const { user, token } = await createTestUser();
    const schedule = await createTestSchedule(user.id);

    const res = await request(app)
      .patch(`/schedules/${schedule.id}/payment`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'parcial', valorPago: 250, vencimento: '2026-06-30' });
    expect(res.status).toBe(200);

    const { rows } = await pool.query(`SELECT status_pagamento, valor_pago, vencimento FROM schedules WHERE id = $1`, [schedule.id]);
    expect(rows[0].status_pagamento).toBe('parcial');
    expect(parseFloat(rows[0].valor_pago)).toBe(250);
    expect(rows[0].vencimento.toISOString().slice(0, 10)).toBe('2026-06-30');
  });

  it('rejeita status inválido', async () => {
    const { user, token } = await createTestUser();
    const schedule = await createTestSchedule(user.id);
    const res = await request(app)
      .patch(`/schedules/${schedule.id}/payment`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'invalido' });
    expect(res.status).toBe(400);
  });

  it('rejeita schedule de outro usuário', async () => {
    const { token: tokenA } = await createTestUser();
    const { user: userB } = await createTestUser();
    const scheduleB = await createTestSchedule(userB.id);
    const res = await request(app)
      .patch(`/schedules/${scheduleB.id}/payment`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ status: 'pago' });
    expect(res.status).toBe(404);
  });
});

describe('GET /receipts/pending', () => {
  it('lista escalas com status_pagamento != pago, agregando total', async () => {
    const { user, token } = await createTestUser();
    await createTestSchedule(user.id, { valor_total: 500 });
    await createTestSchedule(user.id, { valor_total: 300 });
    const paid = await createTestSchedule(user.id, { valor_total: 100 });
    await pool.query(`UPDATE schedules SET status_pagamento = 'pago' WHERE id = $1`, [paid.id]);

    const res = await request(app)
      .get('/receipts/pending')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(2);
    expect(res.body.totalPendente).toBe(800);
  });
});
```

- [ ] **Step 2: Rodar e verificar falha**

Run: `cd apps/api && npm test -- schedules_payment`. Expected: FAIL.

- [ ] **Step 3: Implementar PATCH /schedules/:id/payment**

Modificar `apps/api/routes/schedules.js`. Adicionar (após os handlers existentes, antes do `module.exports`):

```javascript
router.patch(
  '/:id/payment',
  auth,
  body('status').isIn(['pendente', 'pago', 'parcial', 'atrasado']),
  body('valorPago').optional().isFloat({ min: 0 }),
  body('vencimento').optional().isISO8601(),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Parâmetros inválidos', details: errors.array() });
    }

    try {
      const { rows } = await pool.query(
        `UPDATE schedules
            SET status_pagamento = $1,
                valor_pago = COALESCE($2, valor_pago),
                vencimento = COALESCE($3::date, vencimento)
          WHERE id = $4 AND user_id = $5
          RETURNING id, status_pagamento, valor_pago, vencimento`,
        [req.body.status, req.body.valorPago ?? null, req.body.vencimento ?? null, req.params.id, req.user.id]
      );
      if (rows.length === 0) return res.status(404).json({ error: 'Escala não encontrada' });
      res.json(rows[0]);
    } catch (err) {
      console.error('❌ PATCH /schedules/:id/payment:', err);
      res.status(500).json({ error: 'Erro ao atualizar pagamento' });
    }
  }
);
```

Verificar que `auth`, `body`, `validationResult` e `pool` já estão importados no topo do arquivo. Se faltar algum, adicionar.

- [ ] **Step 4: Implementar GET /receipts/pending**

Adicionar em `apps/api/routes/receipts.js`, antes de `module.exports`:

```javascript
router.get('/receipts/pending', auth, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, projeto, produtora, diretor, data, valor_total, status_pagamento, valor_pago, vencimento
         FROM schedules
        WHERE user_id = $1
          AND status_pagamento != 'pago'
          AND realizado = TRUE
        ORDER BY data DESC`,
      [req.user.id]
    );

    const totalPendente = rows.reduce(
      (sum, r) => sum + parseFloat(r.valor_total) - parseFloat(r.valor_pago),
      0
    );

    res.json({ items: rows, totalPendente: Math.round(totalPendente * 100) / 100 });
  } catch (err) {
    console.error('❌ /receipts/pending:', err);
    res.status(500).json({ error: 'Erro ao listar pendentes' });
  }
});
```

Nota: `/receipts/pending` é deliberadamente **acessível pra Free** (sem `requirePro`). Saber quanto está a receber é informação básica; só **gerar/enviar** recibo é Pro. Isso melhora descoberta do paywall (Free vê o total pendente, banner sugere upgrade).

- [ ] **Step 5: Rodar teste e verificar que passa**

Run: `cd apps/api && npm test -- schedules_payment`. Expected: 4 testes passando.

- [ ] **Step 6: Commit**

```bash
git add apps/api/routes/schedules.js apps/api/routes/receipts.js apps/api/__tests__/schedules_payment.test.js
git commit -m "feat(receipts): adicionar PATCH /schedules/:id/payment e GET /receipts/pending

- PATCH atualiza status_pagamento, valor_pago e vencimento
- COALESCE preserva valores antigos quando campos opcionais nao vem
- GET /receipts/pending lista nao-pagos + soma total
- Pending e acessivel pra Free deliberadamente (descoberta do paywall);
  apenas gerar/enviar recibo exige Pro"
```

---

## Task 16: Validação end-to-end + documentação

Última task: garantir que tudo funciona junto, atualizar docs.

**Files:**
- Create: `apps/api/__tests__/e2e_pro_journey.test.js`
- Modify: `CLAUDE.md`
- Modify: `~/.claude/skills/dublydesk-architecture/SKILL.md` (apenas se a estrutura mudou significativamente)

- [ ] **Step 1: Escrever teste e2e**

Criar `apps/api/__tests__/e2e_pro_journey.test.js`:

```javascript
jest.mock('../services/email_sender', () => ({
  sendEmail: jest.fn().mockResolvedValue({ messageId: 'mock' }),
}));

const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser, createTestSchedule } = require('./helpers/fixtures');

let app;

beforeAll(async () => {
  app = require('../server');
  await new Promise((resolve) => setTimeout(resolve, 500));
});

beforeEach(async () => {
  await cleanDatabase();
});

afterAll(async () => {
  await closeDatabase();
});

describe('Jornada Pro completa', () => {
  it('Free vê entitlement vazio → vira Pro via subscription manual → gera recibo → envia → marca pago', async () => {
    // 1. Usuário Free
    const { user, token } = await createTestUser();
    const ent1 = await request(app).get('/me/entitlements').set('Authorization', `Bearer ${token}`);
    expect(ent1.body.pro).toBe(false);

    // 2. Tentar gerar recibo → 402
    const schedule = await createTestSchedule(user.id, { valor_total: 1200 });
    const blocked = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduleId: schedule.id });
    expect(blocked.status).toBe(402);

    // 3. Simular Stripe webhook criando subscription (atalho do fluxo real)
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_e2e', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );

    // 4. Entitlement agora retorna Pro
    const ent2 = await request(app).get('/me/entitlements').set('Authorization', `Bearer ${token}`);
    expect(ent2.body.pro).toBe(true);

    // 5. Gerar recibo
    const gen = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduleId: schedule.id });
    expect(gen.status).toBe(201);

    // 6. Enviar por email
    const send = await request(app)
      .post(`/receipts/${gen.body.id}/send-email`)
      .set('Authorization', `Bearer ${token}`)
      .send({ destinatario: 'cobranca@produtora.com' });
    expect(send.status).toBe(200);

    // 7. Marcar como pago
    const pay = await request(app)
      .patch(`/schedules/${schedule.id}/payment`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'pago', valorPago: 1200 });
    expect(pay.status).toBe(200);

    // 8. /receipts/pending não inclui mais essa escala
    const pending = await request(app).get('/receipts/pending').set('Authorization', `Bearer ${token}`);
    expect(pending.body.items).toHaveLength(0);
    expect(pending.body.totalPendente).toBe(0);
  });
});
```

- [ ] **Step 2: Rodar e validar**

Run: `cd apps/api && npm test`. Expected: TODOS os testes passando (smoke + schemas + entitlement + middleware + billing + receipts + e2e). Output total deve ser algo como "Tests: 30+ passed".

- [ ] **Step 3: Atualizar CLAUDE.md com rotas novas**

Modificar `CLAUDE.md` no projeto raiz. Encontrar a tabela `## Rotas da API` e adicionar as linhas novas:

```markdown
| GET | `/me/entitlements` | Estado da assinatura Pro |
| POST | `/billing/stripe/checkout` | Cria Stripe Checkout Session (web) |
| POST | `/billing/stripe/webhook` | Recebe eventos Stripe (HMAC) |
| POST | `/billing/stripe/portal` | Cria Stripe Customer Portal Session |
| POST | `/billing/play/verify` | Valida purchaseToken Android |
| POST | `/billing/restore` | Re-valida compras Play do usuário |
| POST | `/receipts/generate` | Gera PDF de recibo (Pro) |
| POST | `/receipts/:id/send-email` | Envia recibo por email (Pro) |
| GET | `/receipts/pending` | Lista escalas a receber + total |
| PATCH | `/schedules/:id/payment` | Atualiza status de pagamento |
```

Adicionar também na seção de variáveis de ambiente:

```env
# Stripe
STRIPE_SECRET_KEY=...
STRIPE_WEBHOOK_SECRET=...
STRIPE_PRICE_MONTHLY=...
STRIPE_PRICE_ANNUAL=...
FRONTEND_WEB_URL=https://app.dublydesk.com

# Google Play
PLAY_PACKAGE_NAME=br.com.dublydesk.app
PLAY_SERVICE_ACCOUNT_PATH=./.secrets/play-service-account.json
```

- [ ] **Step 4: Validar manualmente com curl + Stripe CLI**

Esta validação acontece **fora do test runner** (precisa de Stripe sandbox real):

1. Iniciar API local: `cd apps/api && node server.js`
2. Em outro terminal, instalar Stripe CLI (`https://stripe.com/docs/stripe-cli`):
   ```bash
   stripe login
   stripe listen --forward-to localhost:3000/billing/stripe/webhook
   ```
   Anotar o `whsec_` que o CLI imprime — colocar como `STRIPE_WEBHOOK_SECRET` no `.env` e reiniciar API.
3. Disparar evento de teste:
   ```bash
   stripe trigger customer.subscription.created
   ```
4. Conferir no log da API que o evento foi recebido e salvo em `subscriptions`.

Esse passo é manual e NÃO é executado em CI. Se algo der errado, revisar `STRIPE_WEBHOOK_SECRET` e raw body parser.

- [ ] **Step 5: Commit final + push**

```bash
git add apps/api/__tests__/e2e_pro_journey.test.js CLAUDE.md
git commit -m "test(api): teste e2e da jornada Pro completa + atualizar CLAUDE.md

E2E cobre: free -> tenta gerar recibo (402) -> assinatura criada
manualmente -> entitlement Pro -> gera PDF -> envia email -> marca
pago -> /pending vazio.

CLAUDE.md atualizado com:
- 10 rotas novas (/me/entitlements, /billing/*, /receipts/*, payment)
- vars de ambiente Stripe e Play"

git push origin main
```

---

## Verification Section

Após executar todas as 16 tasks, validar a entrega:

### Smoke tests automatizados

```bash
cd apps/api && npm test
```

Esperado: ~30+ testes passando, incluindo:
- `__tests__/smoke.test.js` (1)
- `__tests__/schema_*.test.js` (8-10)
- `__tests__/entitlement.test.js` (5)
- `__tests__/require_pro.test.js` (3)
- `__tests__/billing_*.test.js` (~10)
- `__tests__/pdf_generator.test.js` (2)
- `__tests__/email_sender.test.js` (2)
- `__tests__/receipts.test.js` (4)
- `__tests__/schedules_payment.test.js` (4)
- `__tests__/e2e_pro_journey.test.js` (1)

### Inspeção do schema em produção

Após deploy no EasyPanel:

```sql
\dt   -- lista tabelas; deve conter: subscriptions, subscription_events, receipts, analytics_events

\d subscriptions   -- conferir colunas e constraints
\d schedules       -- conferir colunas novas: status_pagamento, valor_pago, vencimento
```

### Teste manual com Stripe CLI

Conforme Task 16 Step 4.

### Teste manual com curl da rota crítica

```bash
# 1. Login (já existente)
TOKEN=$(curl -s -X POST https://api.dublydesk.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"seu@email.com","password":"sua_senha"}' | jq -r .token)

# 2. Entitlement vazio
curl -s https://api.dublydesk.com/me/entitlements \
  -H "Authorization: Bearer $TOKEN" | jq

# Esperado: { "pro": false, "trial": false, "until": null, ... }
```

### Volume persistente pra PDFs

No EasyPanel, no serviço `dublydesk-api`, garantir que existe volume montado em `/app/uploads/` (ou onde o `apps/api/uploads/` for resolvido dentro do container). Sem isso, os PDFs gerados somem em cada redeploy.

---

## Next Steps

Depois da execução deste plano:

1. **Plano 2 (Flutter Android):** consumir todos esses endpoints no app. Inclui Play Billing SDK, `EntitlementService`, `BillingService`, `pro_page.dart`, botão "Gerar recibo" no `schedule_card`, `payments_dashboard_page`. Estimativa: 5-7 dias úteis.

2. **Plano 3 (PWA Web + Instrumentação + Go-live):** build Flutter Web, deploy em `app.dublydesk.com`, integração Stripe Checkout flow, manifest PWA, push notifications de trial expirando, internal testing, go-live. Estimativa: 5-7 dias úteis.

3. **Antes de iniciar Plano 2,** providenciar:
   - Conta Stripe ativada (modo live)
   - Google Play Console com app publicado e produtos `pro_monthly`/`pro_annual` criados
   - Política de privacidade e termos de uso publicados em `dublydesk.com/privacidade` e `/termos`
   - Volume persistente configurado no EasyPanel pra `uploads/`
