jest.mock('../services/play_billing', () => ({
  verifySubscription: jest.fn(),
  mapPlayState: jest.requireActual('../services/play_billing').mapPlayState,
}));

const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const { verifySubscription } = require('../services/play_billing');

let app;

beforeAll(async () => {
  app = require('../server');
  await app.tablesReady;
});

beforeEach(async () => {
  await cleanDatabase();
  verifySubscription.mockReset();
});

afterAll(async () => {
  await closeDatabase();
});

describe('POST /billing/play/verify', () => {
  it('exige autenticação', async () => {
    const res = await request(app).post('/billing/play/verify').send({});
    expect(res.status).toBe(401);
  });

  it('valida purchaseToken e cria subscription', async () => {
    const { user, token } = await createTestUser();
    verifySubscription.mockResolvedValueOnce({
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      lineItems: [
        {
          productId: 'pro_monthly',
          expiryTime: new Date(Date.now() + 30 * 86400000).toISOString(),
        },
      ],
    });

    const res = await request(app)
      .post('/billing/play/verify')
      .set('Authorization', `Bearer ${token}`)
      .send({ purchaseToken: 'tok_abc', productId: 'pro_monthly' });

    expect(res.status).toBe(200);
    expect(res.body.pro).toBe(true);

    const { rows } = await pool.query(`SELECT * FROM subscriptions WHERE user_id = $1`, [user.id]);
    expect(rows).toHaveLength(1);
    expect(rows[0].source).toBe('play');
    expect(rows[0].external_id).toBe('tok_abc');
    expect(rows[0].status).toBe('active');
  });

  it('retorna 400 sem purchaseToken', async () => {
    const { token } = await createTestUser();
    const res = await request(app)
      .post('/billing/play/verify')
      .set('Authorization', `Bearer ${token}`)
      .send({ productId: 'pro_monthly' });
    expect(res.status).toBe(400);
  });
});
