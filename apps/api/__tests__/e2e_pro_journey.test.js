jest.mock('../services/email_sender', () => ({
  sendEmail: jest.fn().mockResolvedValue({ messageId: 'mock' }),
}));

const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser, createTestSchedule } = require('./helpers/fixtures');

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

describe('Jornada Pro completa', () => {
  it('Free vê entitlement vazio → vira Pro via subscription manual → gera recibo → envia → marca pago', async () => {
    const { user, token } = await createTestUser();
    const ent1 = await request(app).get('/me/entitlements').set('Authorization', `Bearer ${token}`);
    expect(ent1.body.pro).toBe(false);

    const schedule = await createTestSchedule(user.id, { valor_total: 1200 });
    const blocked = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduleId: schedule.id });
    expect(blocked.status).toBe(402);

    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_e2e', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );

    const ent2 = await request(app).get('/me/entitlements').set('Authorization', `Bearer ${token}`);
    expect(ent2.body.pro).toBe(true);

    const gen = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduleId: schedule.id });
    expect(gen.status).toBe(201);

    const send = await request(app)
      .post(`/receipts/${gen.body.id}/send-email`)
      .set('Authorization', `Bearer ${token}`)
      .send({ destinatario: 'cobranca@produtora.com' });
    expect(send.status).toBe(200);

    const pay = await request(app)
      .patch(`/schedules/${schedule.id}/payment`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'pago', valorPago: 1200 });
    expect(pay.status).toBe(200);

    const pending = await request(app).get('/receipts/pending').set('Authorization', `Bearer ${token}`);
    expect(pending.body.items).toHaveLength(0);
    expect(pending.body.totalPendente).toBe(0);
  });
});
