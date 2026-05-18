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

describe('PATCH /schedules/:id/payment', () => {
  it('atualiza status_pagamento, valor_pago e vencimento', async () => {
    const { user, token } = await createTestUser();
    const schedule = await createTestSchedule(user.id);

    const res = await request(app)
      .patch(`/schedules/${schedule.id}/payment`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'parcial', valorPago: 250, vencimento: '2026-06-30' });
    expect(res.status).toBe(200);

    const { rows } = await pool.query(`SELECT status_pagamento, valor_pago, vencimento FROM schedules WHERE id = $1`, [schedule.id]);
    expect(rows[0].status_pagamento).toBe('parcial');
    expect(parseFloat(rows[0].valor_pago)).toBe(250);
    expect(rows[0].vencimento.toISOString().slice(0, 10)).toBe('2026-06-30');
  });

  it('rejeita status inválido', async () => {
    const { user, token } = await createTestUser();
    const schedule = await createTestSchedule(user.id);
    const res = await request(app)
      .patch(`/schedules/${schedule.id}/payment`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'invalido' });
    expect(res.status).toBe(400);
  });

  it('rejeita schedule de outro usuário', async () => {
    const { token: tokenA } = await createTestUser();
    const { user: userB } = await createTestUser();
    const scheduleB = await createTestSchedule(userB.id);
    const res = await request(app)
      .patch(`/schedules/${scheduleB.id}/payment`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ status: 'pago' });
    expect(res.status).toBe(404);
  });
});

describe('GET /receipts/pending', () => {
  it('lista escalas com status_pagamento != pago, agregando total', async () => {
    const { user, token } = await createTestUser();
    await createTestSchedule(user.id, { valor_total: 500 });
    await createTestSchedule(user.id, { valor_total: 300 });
    const paid = await createTestSchedule(user.id, { valor_total: 100 });
    await pool.query(`UPDATE schedules SET status_pagamento = 'pago' WHERE id = $1`, [paid.id]);

    const res = await request(app)
      .get('/receipts/pending')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(2);
    expect(res.body.totalPendente).toBe(800);
  });
});
