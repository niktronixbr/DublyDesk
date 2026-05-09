const express = require('express');
const pool = require('../db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// GET /diretores
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, nome FROM diretores WHERE user_id = $1 ORDER BY nome',
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('GET /diretores error:', err);
    res.status(500).json({ error: 'Erro ao buscar diretores' });
  }
});

// POST /diretores
router.post('/', async (req, res) => {
  const { nome } = req.body;
  if (!nome || !nome.trim()) {
    return res.status(400).json({ error: 'Nome é obrigatório' });
  }
  try {
    const result = await pool.query(
      `INSERT INTO diretores (user_id, nome)
       VALUES ($1, $2)
       ON CONFLICT (user_id, nome) DO UPDATE SET nome = EXCLUDED.nome
       RETURNING id, nome`,
      [req.user.id, nome.trim()]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error('POST /diretores error:', err);
    res.status(500).json({ error: 'Erro ao salvar produtora' });
  }
});

module.exports = router;
