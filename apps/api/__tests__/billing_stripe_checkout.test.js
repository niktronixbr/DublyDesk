jest.mock('../services/stripe', () => ({
  createCheckoutSession: jest.fn(),
  PRICE_IDS: { pro_monthly: 'price_test_m', pro_annual: 'price_test_a' },
}));

const request = require('supertest');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const { createCheckoutSession } = require('../services/stripe');

let app;

beforeAll(async () => {
  app = require('../server');
  await app.tablesReady;
});

beforeEach(async () => {
  await cleanDatabase();
  createCheckoutSession.mockReset();
});

afterAll(async () => {
  await closeDatabase();
});

describe('POST /billing/stripe/checkout', () => {
  it('exige autenticação', async () => {
    const res = await request(app).post('/billing/stripe/checkout').send({ plan: 'pro_monthly' });
    expect(res.status).toBe(401);
  });

  it('retorna 400 pra plan inválido', async () => {
    const { token } = await createTestUser();
    const res = await request(app)
      .post('/billing/stripe/checkout')
      .set('Authorization', `Bearer ${token}`)
      .send({ plan: 'pro_lifetime' });
    expect(res.status).toBe(400);
  });

  it('cria session e retorna url', async () => {
    createCheckoutSession.mockResolvedValueOnce({
      id: 'cs_test_123',
      url: 'https://checkout.stripe.com/c/pay/cs_test_123',
    });
    const { user, token } = await createTestUser();
    const res = await request(app)
      .post('/billing/stripe/checkout')
      .set('Authorization', `Bearer ${token}`)
      .send({ plan: 'pro_annual' });
    expect(res.status).toBe(200);
    expect(res.body.url).toMatch(/checkout\.stripe\.com/);
    expect(createCheckoutSession).toHaveBeenCalledWith(expect.objectContaining({
      userId: user.id,
      userEmail: user.email,
      plan: 'pro_annual',
    }));
  });
});
