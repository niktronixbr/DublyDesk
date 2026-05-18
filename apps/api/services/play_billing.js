const { google } = require('googleapis');

let androidPublisher = null;

function getClient() {
  if (androidPublisher) return androidPublisher;

  const keyPath = process.env.PLAY_SERVICE_ACCOUNT_PATH;
  if (!keyPath) {
    throw new Error('PLAY_SERVICE_ACCOUNT_PATH não configurado');
  }

  const auth = new google.auth.GoogleAuth({
    keyFile: keyPath,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  androidPublisher = google.androidpublisher({ version: 'v3', auth });
  return androidPublisher;
}

async function verifySubscription({ packageName, subscriptionId, purchaseToken }) {
  const client = getClient();
  const res = await client.purchases.subscriptionsv2.get({
    packageName,
    token: purchaseToken,
  });
  return res.data;
}

function mapPlayState(state) {
  const map = {
    SUBSCRIPTION_STATE_ACTIVE: 'active',
    SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 'past_due',
    SUBSCRIPTION_STATE_ON_HOLD: 'past_due',
    SUBSCRIPTION_STATE_PAUSED: 'past_due',
    SUBSCRIPTION_STATE_CANCELED: 'cancelled',
    SUBSCRIPTION_STATE_EXPIRED: 'expired',
    SUBSCRIPTION_STATE_PENDING: 'trialing',
  };
  return map[state] || 'expired';
}

module.exports = { verifySubscription, mapPlayState };
