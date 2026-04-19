const express = require('express');
const cors = require('cors');
const pool = require('./db');

const authRoutes = require('./routes/auth');
const schedulesRoutes = require('./routes/schedules');

const app = express();

const allowedOrigin = process.env.FRONTEND_ORIGIN || '*';

app.use(cors({
  origin: allowedOrigin === '*' ? true : allowedOrigin,
}));

app.use(express.json());

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

    console.log('✅ Tabelas e índices garantidos');
  } catch (err) {
    console.error('❌ Erro ao criar tabelas:', err);
  }
}

app.get('/health', (req, res) => {
  res.status(200).json({ ok: true });
});

app.use('/auth', authRoutes);
app.use('/schedules', schedulesRoutes);

const PORT = process.env.PORT || 3000;

async function startServer() {
  await createTables();
  app.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}`);
  });
}

startServer();
