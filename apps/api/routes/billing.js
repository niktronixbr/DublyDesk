const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const auth = require('../middleware/auth');
const { getEntitlement } = require('../services/entitlement');
const { createCheckoutSession, createPortalSession, PRICE_IDS } = require('../services/stripe');
const pool = require('../db');
const { stripe } = require('../services/stripe');
const { verifySubscription, mapPlayState } = require('../services/play_billing');

router.get('/me/entitlements', auth, async (req, res) => {
  try {
    const ent = await getEntitlement(req.user.id);
    res.json(ent);
  } catch (err) {
    console.error('❌ /me/entitlements:', err);
    res.status(500).json({ error: 'Erro ao consultar entitlement' });
  }
});

router.post(
  '/billing/stripe/checkout',
  auth,
  body('plan').isIn(Object.keys(PRICE_IDS)),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Plano inválido', details: errors.array() });
    }
    try {
      const baseUrl = process.env.FRONTEND_WEB_URL || 'https://app.dublydesk.com';
      const session = await createCheckoutSession({
        userId: req.user.id,
        userEmail: req.user.email,
        plan: req.body.plan,
        successUrl: `${baseUrl}/pro/success?session_id={CHECKOUT_SESSION_ID}`,
        cancelUrl: `${baseUrl}/pro`,
      });
      res.json({ id: session.id, url: session.url });
    } catch (err) {
      console.error('❌ stripe/checkout:', err);
      res.status(500).json({ error: 'Erro ao criar sessão de checkout' });
    }
  }
);

router.post(
  '/billing/play/verify',
  auth,
  body('purchaseToken').isString().notEmpty(),
  body('productId').isIn(['pro_monthly', 'pro_annual']),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Parâmetros inválidos', details: errors.array() });
    }

    const { purchaseToken, productId } = req.body;
    const packageName = process.env.PLAY_PACKAGE_NAME;

    try {
      const playData = await verifySubscription({ packageName, subscriptionId: productId, purchaseToken });
      const status = mapPlayState(playData.subscriptionState);
      const expiryRaw = playData.lineItems?.[0]?.expiryTime;
      const currentPeriodEnd = expiryRaw ? new Date(expiryRaw) : new Date();

      await pool.query(
        `INSERT INTO subscriptions
           (user_id, source, external_id, product_id, status, current_period_end, updated_at)
         VALUES ($1, 'play', $2, $3, $4, $5, NOW())
         ON CONFLICT (source, external_id) DO UPDATE SET
           status = EXCLUDED.status,
           current_period_end = EXCLUDED.current_period_end,
           updated_at = NOW()`,
        [req.user.id, purchaseToken, productId, status, currentPeriodEnd]
      );

      const ent = await getEntitlement(req.user.id);
      res.json(ent);
    } catch (err) {
      console.error('❌ play/verify:', err);
      res.status(500).json({ error: 'Erro ao validar compra Play' });
    }
  }
);

router.post('/billing/restore', auth, async (req, res) => {
  const packageName = process.env.PLAY_PACKAGE_NAME;

  try {
    const { rows: subs } = await pool.query(
      `SELECT id, external_id, product_id FROM subscriptions
        WHERE user_id = $1 AND source = 'play'`,
      [req.user.id]
    );

    for (const sub of subs) {
      try {
        const playData = await verifySubscription({
          packageName,
          subscriptionId: sub.product_id,
          purchaseToken: sub.external_id,
        });
        const status = mapPlayState(playData.subscriptionState);
        const expiryRaw = playData.lineItems?.[0]?.expiryTime;
        const currentPeriodEnd = expiryRaw ? new Date(expiryRaw) : new Date();
        await pool.query(
          `UPDATE subscriptions SET status = $1, current_period_end = $2, updated_at = NOW() WHERE id = $3`,
          [status, currentPeriodEnd, sub.id]
        );
      } catch (err) {
        console.warn(`⚠️  Não consegui re-validar sub ${sub.id}:`, err.message);
      }
    }

    const ent = await getEntitlement(req.user.id);
    res.json(ent);
  } catch (err) {
    console.error('❌ /billing/restore:', err);
    res.status(500).json({ error: 'Erro ao restaurar compras' });
  }
});

router.post(
  '/billing/stripe/portal',
  auth,
  body('customerId').isString().notEmpty(),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'customerId obrigatório' });
    }
    try {
      const session = await createPortalSession({
        customerId: req.body.customerId,
        returnUrl: process.env.FRONTEND_WEB_URL || 'https://app.dublydesk.com',
      });
      res.json({ url: session.url });
    } catch (err) {
      console.error('❌ stripe/portal:', err);
      res.status(500).json({ error: 'Erro ao abrir portal' });
    }
  }
);

router.post('/billing/stripe/webhook', async (req, res) => {
  const signature = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;
  try {
    event = stripe.webhooks.constructEvent(req.body, signature, webhookSecret);
  } catch (err) {
    console.error('❌ Stripe webhook signature invalid:', err.message);
    return res.status(400).json({ error: 'Invalid signature' });
  }

  try {
    await handleStripeEvent(event);
    res.status(200).json({ received: true });
  } catch (err) {
    console.error('❌ Stripe webhook handler:', err);
    res.status(500).json({ error: 'Handler error' });
  }
});

async function handleStripeEvent(event) {
  const sub = event.data.object;
  const userId = parseInt(sub.metadata?.user_id, 10);
  if (!userId) {
    console.warn('⚠️  Evento Stripe sem user_id em metadata:', event.id);
    return;
  }

  switch (event.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated': {
      const productId = sub.items?.data?.[0]?.price?.metadata?.plan
        || sub.items?.data?.[0]?.price?.id
        || 'unknown';
      const status = mapStripeStatus(sub.status);
      const currentPeriodEnd = new Date(sub.current_period_end * 1000);
      const trialEndsAt = sub.trial_end ? new Date(sub.trial_end * 1000) : null;

      await pool.query(
        `INSERT INTO subscriptions
           (user_id, source, external_id, product_id, status, current_period_end, cancel_at_period_end, trial_ends_at, updated_at)
         VALUES ($1, 'stripe', $2, $3, $4, $5, $6, $7, NOW())
         ON CONFLICT (source, external_id) DO UPDATE SET
           status = EXCLUDED.status,
           current_period_end = EXCLUDED.current_period_end,
           cancel_at_period_end = EXCLUDED.cancel_at_period_end,
           trial_ends_at = EXCLUDED.trial_ends_at,
           updated_at = NOW()`,
        [userId, sub.id, productId, status, currentPeriodEnd, sub.cancel_at_period_end || false, trialEndsAt]
      );
      break;
    }
    case 'customer.subscription.deleted': {
      await pool.query(
        `UPDATE subscriptions SET status = 'expired', updated_at = NOW()
         WHERE source = 'stripe' AND external_id = $1`,
        [sub.id]
      );
      break;
    }
    default:
      console.log(`ℹ️  Stripe event ignorado: ${event.type}`);
  }

  // Audit trail
  const { rows: subRows } = await pool.query(
    `SELECT id FROM subscriptions WHERE source = 'stripe' AND external_id = $1`,
    [sub.id]
  );
  if (subRows.length > 0) {
    await pool.query(
      `INSERT INTO subscription_events (subscription_id, type, raw_payload) VALUES ($1, $2, $3)`,
      [subRows[0].id, event.type, JSON.stringify(event)]
    );
  }
}

function mapStripeStatus(stripeStatus) {
  const map = {
    trialing: 'trialing',
    active: 'active',
    past_due: 'past_due',
    canceled: 'cancelled',
    unpaid: 'past_due',
    incomplete: 'past_due',
    incomplete_expired: 'expired',
  };
  return map[stripeStatus] || 'expired';
}

module.exports = router;
