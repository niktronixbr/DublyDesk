const express = require('express');
const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const auth = require('../middleware/auth');
const requirePro = require('../middleware/require_pro');

beforeAll(async () => {
  const app = require('../server');
  await app.tablesReady;
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
