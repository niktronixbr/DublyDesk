const request = require('supertest');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');

let app;

beforeAll(async () => {
  app = require('../server');
  await app.tablesReady;
  await cleanDatabase();
});

afterAll(async () => {
  await closeDatabase();
});

describe('GET /health', () => {
  it('retorna ok: true', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
  });
});
