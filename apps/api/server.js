const fs = require('fs');
const path = require('path');
const express = require('express');
const cors = require('cors');
const pool = require('./db');

// Garante que a pasta de avatares existe (se um volume foi montado em /app/uploads
// pelo EasyPanel, ele vem vazio e o multer falharia sem essa pasta).
fs.mkdirSync(path.join(__dirname, 'uploads', 'avatars'), { recursive: true });

const authRoutes = require('./routes/auth');
const schedulesRoutes = require('./routes/schedules');
const produtorasRoutes = require('./routes/produtoras');
const projetosRoutes = require('./routes/projetos');
const diretoresRoutes = require('./routes/diretores');

const app = express();

const allowedOrigin = process.env.FRONTEND_ORIGIN || '*';

app.set('trust proxy', 1);

app.use(cors({
  origin: allowedOrigin === '*' ? true : allowedOrigin,
}));

app.use(express.json());

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

async function createTables() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS schedules (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        projeto TEXT NOT NULL,
        produtora TEXT NOT NULL,
        diretor TEXT,
        data TIMESTAMP NOT NULL,
        hora_inicio VARCHAR(5) NOT NULL,
        hora_fim VARCHAR(5) NOT NULL,
        valor_hora NUMERIC(10,2) NOT NULL DEFAULT 0,
        valor_total NUMERIC(10,2) NOT NULL DEFAULT 0,
        realizado BOOLEAN NOT NULL DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_schedules_user_id
      ON schedules(user_id);
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_schedules_data
      ON schedules(data DESC);
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_schedules_user_realizado
      ON schedules(user_id, realizado);
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_schedules_produtora
      ON schedules(user_id, produtora);
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS projetos (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        nome TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, nome)
      );
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS diretores (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        nome TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, nome)
      );
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS produtoras (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        nome TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, nome)
      );
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS password_resets (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token TEXT NOT NULL UNIQUE,
        expires_at TIMESTAMP NOT NULL,
        used BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

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

    console.log('✅ Tabelas e índices garantidos');
  } catch (err) {
    console.error('❌ Erro ao criar tabelas:', err);
  }

  try {
    await pool.query(`ALTER TABLE schedules ADD COLUMN IF NOT EXISTS observacao TEXT`);
  } catch (err) {
    console.error('❌ Erro na migration observacao:', err);
  }

  try {
    await pool.query(`
      ALTER TABLE schedules
        ADD COLUMN IF NOT EXISTS lembretes JSONB
        DEFAULT '{"60min":false,"30min":true,"5min":true,"exato":true}'
    `);
  } catch (err) {
    console.error('❌ Erro na migration lembretes:', err);
  }

  try {
    await pool.query(`ALTER TABLE produtoras ADD COLUMN IF NOT EXISTS contato_nome TEXT`);
    await pool.query(`ALTER TABLE produtoras ADD COLUMN IF NOT EXISTS contato_telefone TEXT`);
  } catch (err) {
    console.error('❌ Erro na migration produtoras.contato:', err);
  }

  try {
    await pool.query(`ALTER TABLE schedules ADD COLUMN IF NOT EXISTS tipo_trabalho TEXT`);
    await pool.query(`ALTER TABLE schedules ADD COLUMN IF NOT EXISTS contato_nome TEXT`);
    await pool.query(`ALTER TABLE schedules ADD COLUMN IF NOT EXISTS contato_telefone TEXT`);
  } catch (err) {
    console.error('❌ Erro na migration schedules.tipo_trabalho/contato:', err);
  }

  try {
    await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT`);
  } catch (err) {
    console.error('❌ Erro na migration users.avatar_url:', err);
  }

  try {
    await pool.query(`ALTER TABLE schedules ADD COLUMN IF NOT EXISTS remunerado BOOLEAN NOT NULL DEFAULT true`);
  } catch (err) {
    console.error('❌ Erro na migration schedules.remunerado:', err);
  }

  try {
    await pool.query(`ALTER TABLE schedules ADD COLUMN IF NOT EXISTS tipo TEXT NOT NULL DEFAULT 'trabalho'`);
    await pool.query(`UPDATE schedules SET tipo = 'trabalho' WHERE tipo NOT IN ('trabalho','compromisso')`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_schedules_user_tipo ON schedules(user_id, tipo)`);
  } catch (err) {
    console.error('❌ Erro na migration schedules.tipo:', err);
  }
}

app.get('/health', (req, res) => {
  res.status(200).json({ ok: true });
});

app.use('/auth', authRoutes);
app.use('/schedules', schedulesRoutes);
app.use('/produtoras', produtorasRoutes);
app.use('/projetos', projetosRoutes);
app.use('/diretores', diretoresRoutes);

const PORT = process.env.PORT || 3000;

// Sempre garante schema (idempotente via CREATE TABLE IF NOT EXISTS).
// A Promise é exposta como app.tablesReady para testes aguardarem deterministicamente
// (em vez de setTimeout) e para o listener em produção só subir após o schema estar pronto.
const tablesReady = createTables();
app.tablesReady = tablesReady;

// Só inicia o listener se executado diretamente (não em require para tests).
// Aguarda tablesReady para evitar race em deploy: server não aceita requests
// antes do schema estar garantido.
if (require.main === module) {
  tablesReady.then(() => {
    app.listen(PORT, () => {
      console.log(`Servidor rodando na porta ${PORT}`);
    });
  }).catch((err) => {
    console.error('❌ Falha ao garantir schema; servidor não iniciado:', err);
    process.exit(1);
  });
}

module.exports = app;
