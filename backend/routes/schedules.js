const express = require('express');
const { body, validationResult } = require('express-validator');
const pool = require('../db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// --- Validação ---

const scheduleValidation = [
  body('projeto').trim().notEmpty().withMessage('Projeto é obrigatório'),
  body('produtora').trim().notEmpty().withMessage('Produtora é obrigatória'),
  body('data').isISO8601().withMessage('Data inválida'),
  body('hora_inicio')
    .matches(/^\d{2}:\d{2}$/)
    .withMessage('Hora início inválida (formato HH:mm)'),
  body('hora_fim')
    .matches(/^\d{2}:\d{2}$/)
    .withMessage('Hora fim inválida (formato HH:mm)'),
  body('valor_hora')
    .isFloat({ min: 0.01 })
    .withMessage('Valor/hora deve ser maior que zero'),
  body('hora_fim').custom((horaFim, { req }) => {
    const inicio = req.body.hora_inicio;
    if (!inicio || !horaFim) return true;
    const [hI, mI] = inicio.split(':').map(Number);
    const [hF, mF] = horaFim.split(':').map(Number);
    if (hF * 60 + mF <= hI * 60 + mI) {
      throw new Error('Hora fim deve ser maior que hora início');
    }
    return true;
  }),
];

const scheduleUpdateValidation = [
  body('projeto').optional().trim().notEmpty().withMessage('Projeto não pode ser vazio'),
  body('produtora').optional().trim().notEmpty().withMessage('Produtora não pode ser vazia'),
  body('data').optional().isISO8601().withMessage('Data inválida'),
  body('hora_inicio')
    .optional()
    .matches(/^\d{2}:\d{2}$/)
    .withMessage('Hora início inválida (formato HH:mm)'),
  body('hora_fim')
    .optional()
    .matches(/^\d{2}:\d{2}$/)
    .withMessage('Hora fim inválida (formato HH:mm)'),
  body('valor_hora')
    .optional()
    .isFloat({ min: 0.01 })
    .withMessage('Valor/hora deve ser maior que zero'),
];

function validateRequest(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: errors.array()[0].msg,
      errors: errors.array(),
    });
  }
  next();
}

// --- Endpoints ---

// GET /schedules/summary — deve vir antes de /:id
router.get('/summary', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        COUNT(*) FILTER (WHERE realizado = true)  AS count_realizado,
        COUNT(*) FILTER (WHERE realizado = false) AS count_pendente,
        COALESCE(SUM(valor_total) FILTER (WHERE realizado = true),  0) AS total_realizado,
        COALESCE(SUM(valor_total) FILTER (WHERE realizado = false), 0) AS total_pendente
       FROM schedules
       WHERE user_id = $1`,
      [req.user.id]
    );

    const row = result.rows[0];
    res.json({
      count_realizado: parseInt(row.count_realizado),
      count_pendente: parseInt(row.count_pendente),
      total_realizado: parseFloat(row.total_realizado),
      total_pendente: parseFloat(row.total_pendente),
    });
  } catch (err) {
    console.error('GET /schedules/summary error:', err);
    res.status(500).json({ error: 'Erro ao buscar resumo financeiro' });
  }
});

// GET /schedules?page=1&limit=20&produtora=X&realizado=true
router.get('/', async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
    const offset = (page - 1) * limit;

    const conditions = ['user_id = $1'];
    const values = [req.user.id];

    if (req.query.produtora) {
      values.push(req.query.produtora);
      conditions.push(`produtora = $${values.length}`);
    }

    if (req.query.realizado !== undefined) {
      values.push(req.query.realizado === 'true');
      conditions.push(`realizado = $${values.length}`);
    }

    const where = conditions.join(' AND ');

    const countResult = await pool.query(
      `SELECT COUNT(*) FROM schedules WHERE ${where}`,
      values
    );
    const total = parseInt(countResult.rows[0].count);

    values.push(limit);
    values.push(offset);

    const dataResult = await pool.query(
      `SELECT * FROM schedules
       WHERE ${where}
       ORDER BY data DESC
       LIMIT $${values.length - 1} OFFSET $${values.length}`,
      values
    );

    res.json({
      data: dataResult.rows,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error('GET /schedules error:', err);
    res.status(500).json({ error: 'Erro ao buscar escalas' });
  }
});

// POST /schedules
router.post('/', scheduleValidation, validateRequest, async (req, res) => {
  const {
    projeto, produtora, diretor,
    data, hora_inicio, hora_fim,
    valor_hora, valor_total, realizado, observacao, lembretes,
  } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO schedules
       (user_id, projeto, produtora, diretor, data, hora_inicio, hora_fim,
        valor_hora, valor_total, realizado, observacao, lembretes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
       RETURNING *`,
      [
        req.user.id, projeto, produtora, diretor,
        data, hora_inicio, hora_fim,
        valor_hora, valor_total, realizado ?? false,
        observacao ?? null,
        lembretes ?? { '60min': false, '30min': true, '5min': true, exato: true },
      ]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error('POST /schedules error:', err);
    res.status(500).json({ error: 'Erro ao salvar escala' });
  }
});

// PUT /schedules/:id
router.put('/:id', scheduleUpdateValidation, validateRequest, async (req, res) => {
  const { id } = req.params;

  try {
    const camposPermitidos = [
      'projeto', 'produtora', 'diretor', 'data',
      'hora_inicio', 'hora_fim', 'valor_hora', 'valor_total',
      'realizado', 'observacao', 'lembretes',
    ];

    const entradas = Object.entries(req.body).filter(([chave]) =>
      camposPermitidos.includes(chave)
    );

    if (entradas.length === 0) {
      return res.status(400).json({ error: 'Nenhum campo válido para atualizar' });
    }

    const sets = entradas.map(([chave], i) => `${chave} = $${i + 1}`);
    const valores = entradas.map(([, valor]) => valor);

    valores.push(id);
    valores.push(req.user.id);

    const query = `
      UPDATE schedules
      SET ${sets.join(', ')}
      WHERE id = $${valores.length - 1} AND user_id = $${valores.length}
      RETURNING *
    `;

    const result = await pool.query(query, valores);

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Escala não encontrada' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('PUT /schedules/:id error:', err);
    res.status(500).json({ error: 'Erro ao atualizar escala' });
  }
});

// DELETE /schedules/:id
router.delete('/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'DELETE FROM schedules WHERE id = $1 AND user_id = $2 RETURNING *',
      [id, req.user.id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Escala não encontrada' });
    }

    res.json({ message: 'Escala apagada com sucesso' });
  } catch (err) {
    console.error('DELETE /schedules/:id error:', err);
    res.status(500).json({ error: 'Erro ao apagar escala' });
  }
});

module.exports = router;
