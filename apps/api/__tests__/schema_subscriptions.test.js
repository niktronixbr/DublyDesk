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
