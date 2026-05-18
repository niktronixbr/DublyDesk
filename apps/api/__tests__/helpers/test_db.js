const pool = require('../../db');

// Lista de tabelas a truncar entre testes. Ordem por FK (filhos antes de pais).
// Tabelas que ainda não existem (planejadas para tasks futuras) são ignoradas
// individualmente em vez de fazer o TRUNCATE inteiro falhar (postgres faz tudo
// em uma transacao implicita, entao incluir uma tabela inexistente aborta todas).
const TABLES = [
  'analytics_events',
  'receipts',
  'subscription_events',
  'subscriptions',
  'password_resets',
  'schedules',
  'projetos',
  'diretores',
  'produtoras',
  'users',
];

async function cleanDatabase() {
  // Filtra apenas tabelas que existem para evitar abortar o TRUNCATE inteiro.
  const { rows } = await pool.query(
    `SELECT table_name FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name = ANY($1)`,
    [TABLES]
  );
  const existing = new Set(rows.map((r) => r.table_name));
  const toTruncate = TABLES.filter((t) => existing.has(t));
  if (toTruncate.length === 0) return;
  await pool.query(
    `TRUNCATE TABLE ${toTruncate.join(', ')} RESTART IDENTITY CASCADE`
  );
}

async function closeDatabase() {
  await pool.end();
}

module.exports = { cleanDatabase, closeDatabase };
