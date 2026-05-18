const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');

let app;

beforeAll(async () => {
  app = require('../server');
  await app.tablesReady;
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
