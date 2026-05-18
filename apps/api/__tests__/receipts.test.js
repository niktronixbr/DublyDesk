jest.mock('../services/email_sender', () => ({
  sendEmail: jest.fn().mockResolvedValue({ messageId: 'mock' }),
}));

const fs = require('fs');
const path = require('path');
const request = require('supertest');
const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser, createTestSchedule } = require('./helpers/fixtures');
const { sendEmail } = require('../services/email_sender');

let app;

beforeAll(async () => {
  app = require('../server');
  await app.tablesReady;
});

beforeEach(async () => {
  await cleanDatabase();
  sendEmail.mockClear();
});

afterAll(async () => {
  await closeDatabase();
  const uploadDir = path.join(__dirname, '..', 'uploads', 'receipts');
  if (fs.existsSync(uploadDir)) fs.rmSync(uploadDir, { recursive: true, force: true });
});

async function makeProUser() {
  const { user, token } = await createTestUser();
  await pool.query(
    `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
     VALUES ($1, 'stripe', $2, 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
    [user.id, `sub_pro_recipe_${user.id}`]
  );
  return { user, token };
}

describe('POST /receipts/generate', () => {
  it('bloqueia usuário Free com 402', async () => {
    const { user, token } = await createTestUser();
    const schedule = await createTestSchedule(user.id);
    const res = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduleId: schedule.id });
    expect(res.status).toBe(402);
  });

  it('gera PDF pra usuário Pro', async () => {
    const { user, token } = await makeProUser();
    const schedule = await createTestSchedule(user.id, { valor_total: 750 });
    const res = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduleId: schedule.id });
    expect(res.status).toBe(201);
    expect(res.body.id).toBeDefined();
    expect(res.body.pdfPath).toMatch(/uploads\/receipts/);

    const { rows } = await pool.query(`SELECT * FROM receipts WHERE id = $1`, [res.body.id]);
    expect(rows).toHaveLength(1);
    expect(fs.existsSync(path.join(__dirname, '..', rows[0].pdf_path))).toBe(true);
  });

  it('rejeita scheduleId que não pertence ao usuário', async () => {
    const { token: tokenA } = await makeProUser();
    const { user: userB } = await createTestUser();
    const scheduleB = await createTestSchedule(userB.id);

    const res = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ scheduleId: scheduleB.id });
    expect(res.status).toBe(404);
  });
});

describe('POST /receipts/:id/send-email', () => {
  it('envia email com PDF anexado', async () => {
    const { user, token } = await makeProUser();
    const schedule = await createTestSchedule(user.id);

    const gen = await request(app)
      .post('/receipts/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ scheduleId: schedule.id });

    const sendRes = await request(app)
      .post(`/receipts/${gen.body.id}/send-email`)
      .set('Authorization', `Bearer ${token}`)
      .send({ destinatario: 'produtora@example.com', mensagem: 'Segue recibo.' });

    expect(sendRes.status).toBe(200);
    expect(sendEmail).toHaveBeenCalledWith(expect.objectContaining({
      to: 'produtora@example.com',
      attachments: expect.arrayContaining([
        expect.objectContaining({ filename: expect.stringMatching(/\.pdf$/) }),
      ]),
    }));

    const { rows } = await pool.query(`SELECT sent_email, sent_at FROM receipts WHERE id = $1`, [gen.body.id]);
    expect(rows[0].sent_email).toBe('produtora@example.com');
    expect(rows[0].sent_at).not.toBeNull();
  });
});
