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
