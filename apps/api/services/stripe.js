const Stripe = require('stripe');

const stripeKey = process.env.STRIPE_SECRET_KEY;
if (!stripeKey && process.env.NODE_ENV !== 'test') {
  console.warn('⚠️  STRIPE_SECRET_KEY não configurado — endpoints Stripe falharão');
}

const stripe = stripeKey ? new Stripe(stripeKey, { apiVersion: '2024-10-28.acacia' }) : null;

const PRICE_IDS = {
  pro_monthly: process.env.STRIPE_PRICE_MONTHLY,
  pro_annual: process.env.STRIPE_PRICE_ANNUAL,
};

async function createCheckoutSession({ userId, userEmail, plan, successUrl, cancelUrl }) {
  if (!stripe) throw new Error('Stripe não configurado');
  const priceId = PRICE_IDS[plan];
  if (!priceId) throw new Error(`Plano inválido: ${plan}`);

  return stripe.checkout.sessions.create({
    mode: 'subscription',
    line_items: [{ price: priceId, quantity: 1 }],
    subscription_data: {
      trial_period_days: 7,
      metadata: { user_id: String(userId) },
    },
    customer_email: userEmail,
    success_url: successUrl,
    cancel_url: cancelUrl,
    metadata: { user_id: String(userId) },
  });
}

async function createPortalSession({ customerId, returnUrl }) {
  if (!stripe) throw new Error('Stripe não configurado');
  return stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: returnUrl,
  });
}

module.exports = { stripe, createCheckoutSession, createPortalSession, PRICE_IDS };
