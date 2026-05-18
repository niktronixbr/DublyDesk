const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');

beforeAll(async () => {
  const app = require('../server');
  await app.tablesReady;
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
