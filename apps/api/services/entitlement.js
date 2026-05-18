const pool = require('../db');

const PRO_STATUSES = ['trialing', 'active'];

async function getEntitlement(userId) {
  const { rows } = await pool.query(
    `SELECT source, status, current_period_end, cancel_at_period_end, trial_ends_at
       FROM subscriptions
      WHERE user_id = $1
        AND status = ANY($2)
        AND current_period_end > NOW()
      ORDER BY current_period_end DESC
      LIMIT 1`,
    [userId, PRO_STATUSES]
  );

  if (rows.length === 0) {
    return {
      pro: false,
      trial: false,
      until: null,
      source: null,
      cancelAtPeriodEnd: false,
    };
  }

  const row = rows[0];
  return {
    pro: true,
    trial: row.status === 'trialing',
    until: row.current_period_end,
    source: row.source,
    cancelAtPeriodEnd: row.cancel_at_period_end,
  };
}

module.exports = { getEntitlement, PRO_STATUSES };
