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
