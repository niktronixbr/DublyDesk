const pool = require('../db');
const { cleanDatabase, closeDatabase } = require('./helpers/test_db');
const { createTestUser } = require('./helpers/fixtures');
const { getEntitlement } = require('../services/entitlement');

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

describe('getEntitlement(userId)', () => {
  it('retorna { pro: false } pra usuário sem assinatura', async () => {
    const { user } = await createTestUser();
    const ent = await getEntitlement(user.id);
    expect(ent).toEqual({ pro: false, trial: false, until: null, source: null, cancelAtPeriodEnd: false });
  });

  it('retorna pro:true e trial:false pra assinatura active', async () => {
    const { user } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_a1', 'pro_monthly', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );
    const ent = await getEntitlement(user.id);
    expect(ent.pro).toBe(true);
    expect(ent.trial).toBe(false);
    expect(ent.source).toBe('stripe');
    expect(ent.cancelAtPeriodEnd).toBe(false);
    expect(new Date(ent.until).getTime()).toBeGreaterThan(Date.now());
  });

  it('retorna trial:true pra status=trialing', async () => {
    const { user } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end, trial_ends_at)
       VALUES ($1, 'play', 'play_token_t1', 'pro_monthly', 'trialing', NOW() + INTERVAL '7 days', NOW() + INTERVAL '7 days')`,
      [user.id]
    );
    const ent = await getEntitlement(user.id);
    expect(ent.pro).toBe(true);
    expect(ent.trial).toBe(true);
    expect(ent.source).toBe('play');
  });

  it('retorna pro:false pra status=expired', async () => {
    const { user } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'sub_exp', 'pro_monthly', 'expired', NOW() - INTERVAL '1 day')`,
      [user.id]
    );
    const ent = await getEntitlement(user.id);
    expect(ent.pro).toBe(false);
  });

  it('escolhe a assinatura com current_period_end mais distante quando há múltiplas', async () => {
    const { user } = await createTestUser();
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'play', 'play_old', 'pro_monthly', 'active', NOW() + INTERVAL '10 days')`,
      [user.id]
    );
    await pool.query(
      `INSERT INTO subscriptions (user_id, source, external_id, product_id, status, current_period_end)
       VALUES ($1, 'stripe', 'stripe_new', 'pro_annual', 'active', NOW() + INTERVAL '30 days')`,
      [user.id]
    );
    const ent = await getEntitlement(user.id);
    expect(ent.source).toBe('stripe');
  });
});
