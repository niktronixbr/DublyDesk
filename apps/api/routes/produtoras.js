const express = require('express');
const pool = require('../db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// GET /produtoras
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, nome, contato_nome, contato_telefone
       FROM produtoras
       WHERE user_id = $1
       ORDER BY nome`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('GET /produtoras error:', err);
    res.status(500).json({ error: 'Erro ao buscar produtoras' });
  }
});

// POST /produtoras — upsert por (user_id, nome)
router.post('/', async (req, res) => {
  const { nome, contato_nome, contato_telefone } = req.body;
  if (!nome || !nome.trim()) {
    return res.status(400).json({ error: 'Nome é obrigatório' });
  }
  try {
    const result = await pool.query(
      `INSERT INTO produtoras (user_id, nome, contato_nome, contato_telefone)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id, nome) DO UPDATE SET
         contato_nome     = COALESCE(EXCLUDED.contato_nome, produtoras.contato_nome),
         contato_telefone = COALESCE(EXCLUDED.contato_telefone, produtoras.contato_telefone)
       RETURNING id, nome, contato_nome, contato_telefone`,
      [
        req.user.id,
        nome.trim(),
        contato_nome?.trim() || null,
        contato_telefone?.trim() || null,
      ]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error('POST /produtoras error:', err);
    res.status(500).json({ error: 'Erro ao salvar produtora' });
  }
});

// PUT /produtoras/:id — atualiza contato de produtora existente
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const { nome, contato_nome, contato_telefone } = req.body;

  try {
    const fields = [];
    const values = [];

    if (nome !== undefined) {
      values.push(nome.trim());
      fields.push(`nome = $${values.length}`);
    }
    if (contato_nome !== undefined) {
      values.push(contato_nome?.trim() || null);
      fields.push(`contato_nome = $${values.length}`);
    }
    if (contato_telefone !== undefined) {
      values.push(contato_telefone?.trim() || null);
      fields.push(`contato_telefone = $${values.length}`);
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'Nenhum campo para atualizar' });
    }

    values.push(id);
    values.push(req.user.id);

    const result = await pool.query(
      `UPDATE produtoras
       SET ${fields.join(', ')}
       WHERE id = $${values.length - 1} AND user_id = $${values.length}
       RETURNING id, nome, contato_nome, contato_telefone`,
      values
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Produtora não encontrada' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('PUT /produtoras/:id error:', err);
    res.status(500).json({ error: 'Erro ao atualizar produtora' });
  }
});

module.exports = router;
