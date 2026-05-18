jest.mock('../services/stripe', () => {
  const real = jest.requireActual('../services/stripe');
  return {
    ...real,
    stripe: {
      webhooks: {
        constructEvent: jest.fn(),
      },
    },
  };
});

const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const { stripe } = require('../services/stripe');

let app;

beforeAll(async () => {
  app = require('../server');
  await app.tablesReady;
});

beforeEach(async () => {
  await cleanDatabase();
  stripe.webhooks.constructEvent.mockReset();
});

afterAll(async () => {
  await closeDatabase();
});

describe('POST /billing/stripe/webhook', () => {
  it('rejeita sem header Stripe-Signature', async () => {
    stripe.webhooks.constructEvent.mockImplementation(() => {
      throw new Error('No signature');
    });
    const res = await request(app)
      .post('/billing/stripe/webhook')
      .set('Content-Type', 'application/json')
      .send('{}');
    expect(res.status).toBe(400);
  });

  it('processa customer.subscription.created e insere em subscriptions', async () => {
    const { user } = await createTestUser();
    stripe.webhooks.constructEvent.mockReturnValue({
      type: 'customer.subscription.created',
      data: {
        object: {
          id: 'sub_stripe_evt1',
          status: 'trialing',
          current_period_end: Math.floor((Date.now() + 7 * 86400000) / 1000),
          cancel_at_period_end: false,
          trial_end: Math.floor((Date.now() + 7 * 86400000) / 1000),
          items: { data: [{ price: { id: 'price_monthly_test', metadata: { plan: 'pro_monthly' } } }] },
          metadata: { user_id: String(user.id) },
        },
      },
    });

    const res = await request(app)
      .post('/billing/stripe/webhook')
      .set('Stripe-Signature', 't=123,v1=abc')
      .set('Content-Type', 'application/json')
      .send('{}');
    expect(res.status).toBe(200);

    const { rows } = await pool.query(`SELECT * FROM subscriptions WHERE user_id = $1`, [user.id]);
    expect(rows).toHaveLength(1);
    expect(rows[0].source).toBe('stripe');
    expect(rows[0].external_id).toBe('sub_stripe_evt1');
    expect(rows[0].status).toBe('trialing');
  });

  it('processa customer.subscription.deleted e marca expired', async () => {
    const { user } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_to_delete', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );
    stripe.webhooks.constructEvent.mockReturnValue({
      type: 'customer.subscription.deleted',
      data: {
        object: {
          id: 'sub_to_delete',
          status: 'canceled',
          current_period_end: Math.floor(Date.now() / 1000),
          metadata: { user_id: String(user.id) },
        },
      },
    });
    const res = await request(app)
      .post('/billing/stripe/webhook')
      .set('Stripe-Signature', 't=123,v1=abc')
      .set('Content-Type', 'application/json')
      .send('{}');
    expect(res.status).toBe(200);

    const { rows } = await pool.query(`SELECT status FROM subscriptions WHERE external_id = 'sub_to_delete'`);
    expect(rows[0].status).toBe('expired');
  });
});
