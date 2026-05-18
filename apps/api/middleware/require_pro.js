const { getEntitlement } = require('../services/entitlement');

async function requirePro(req, res, next) {
  try {
    const ent = await getEntitlement(req.user.id);
    if (!ent.pro) {
      return res.status(402).json({
        error: 'Esta funcionalidade exige uma assinatura Pro ativa.',
        code: 'PRO_REQUIRED',
      });
    }
    req.entitlement = ent;
    next();
  } catch (err) {
    console.error('❌ requirePro:', err);
    res.status(500).json({ error: 'Erro ao validar assinatura' });
  }
}

module.exports = requirePro;
