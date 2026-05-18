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
// Disparado fire-and-forget; testes aguardam um pequeno delay no beforeAll.
createTables();

// Só inicia o listener se executado diretamente (não em require para tests)
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}`);
  });
}

module.exports = app;
