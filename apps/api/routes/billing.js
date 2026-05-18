const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const auth = require('../middleware/auth');
const { getEntitlement } = require('../services/entitlement');
const { createCheckoutSession, PRICE_IDS } = require('../services/stripe');

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

module.exports = router;
