jest.mock('../services/play_billing', () => ({
  verifySubscription: jest.fn(),
  mapPlayState: jest.requireActual('../services/play_billing').mapPlayState,
}));
jest.mock('../services/stripe', () => {
  const real = jest.requireActual('../services/stripe');
  return {
    ...real,
    createPortalSession: jest.fn(),
  };
});

const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const { verifySubscription } = require('../services/play_billing');
const { createPortalSession } = require('../services/stripe');

let app;

beforeAll(async () => {
  app = require('../server');
  await app.tablesReady;
});

beforeEach(async () => {
  await cleanDatabase();
  verifySubscription.mockReset();
  createPortalSession.mockReset();
});

afterAll(async () => {
  await closeDatabase();
});

describe('POST /billing/restore (Android)', () => {
  it('re-valida purchase tokens existentes e atualiza status', async () => {
    const { user, token } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'play', 'tok_restore', 'pro_monthly', 'expired', NOW() - INTERVAL '1 day')`,
      [user.id]
    );
    verifySubscription.mockResolvedValueOnce({
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      lineItems: [{ expiryTime: new Date(Date.now() + 30 * 86400000).toISOString() }],
    });

    const res = await request(app)
      .post('/billing/restore')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.pro).toBe(true);

    const { rows } = await pool.query(`SELECT status FROM subscriptions WHERE external_id = 'tok_restore'`);
    expect(rows[0].status).toBe('active');
  });

  it('retorna entitlement vazio se usuário não tem subscriptions Play', async () => {
    const { token } = await createTestUser();
    const res = await request(app)
      .post('/billing/restore')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.pro).toBe(false);
  });
});

describe('POST /billing/stripe/portal', () => {
  it('retorna URL do Customer Portal', async () => {
    const { user, token } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_portal_test', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );
    createPortalSession.mockResolvedValueOnce({ url: 'https://billing.stripe.com/portal/abc' });

    const res = await request(app)
      .post('/billing/stripe/portal')
      .set('Authorization', `Bearer ${token}`)
      .send({ customerId: 'cus_test_123' });
    expect(res.status).toBe(200);
    expect(res.body.url).toMatch(/stripe\.com\/portal/);
  });
});
