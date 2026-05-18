const router = require('express').Router();
const auth = require('../middleware/auth');
const { getEntitlement } = require('../services/entitlement');

router.get('/me/entitlements', auth, async (req, res) => {
  try {
    const ent = await getEntitlement(req.user.id);
    res.json(ent);
  } catch (err) {
    console.error('❌ /me/entitlements:', err);
    res.status(500).json({ error: 'Erro ao consultar entitlement' });
  }
});

module.exports = router;
