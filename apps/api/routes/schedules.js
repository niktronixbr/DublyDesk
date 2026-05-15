const express = require('express');
const { body, validationResult } = require('express-validator');
const pool = require('../db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

async function verificarConflito(userId, dateStr, horaInicio, horaFim, excludeId = null) {
  try {
    const result = await pool.query(
      `SELECT id FROM schedules
       WHERE user_id = $1
         AND data::date = $2::date
         AND ($3::int IS NULL OR id != $3::int)
         AND hora_inicio::time < $4::time
         AND hora_fim::time   > $5::time
       LIMIT 1`,
      [userId, dateStr, excludeId, horaFim, horaInicio]
    );
    return result.rowCount > 0;
  } catch (err) {
    console.error('verificarConflito error:', err);
    throw err;
  }
}

router.use(authMiddleware);

// --- Validação ---

const scheduleValidation = [
  body('tipo').optional().isIn(['trabalho', 'compromisso']).withMessage('Tipo inválido'),
  body('projeto').optional().trim(),
  body('produtora')
    .if((value, { req }) => (req.body.tipo ?? 'trabalho') === 'trabalho')
    .trim().notEmpty().withMessage('Produtora é obrigatória'),
  body('data').isISO8601().withMessage('Data inválida'),
  body('hora_inicio')
    .matches(/^\d{2}:\d{2}$/)
    .withMessage('Hora início inválida (formato HH:mm)'),
  body('hora_fim')
    .matches(/^\d{2}:\d{2}$/)
    .withMessage('Hora fim inválida (formato HH:mm)'),
  body('remunerado').optional().isBoolean(),
  body('valor_hora').optional().isFloat({ min: 0 }).withMessage('Valor/hora inválido'),
  body('valor_total')
    .if((value, { req }) => {
      const tipo = req.body.tipo ?? 'trabalho';
      const remunerado = req.body.remunerado !== false && req.body.remunerado !== 'false';
      return tipo === 'trabalho' && remunerado;
    })
    .isFloat({ min: 0.01 })
    .withMessage('Valor total deve ser maior que zero'),
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
    .isFloat({ min: 0 })
    .withMessage('Valor/hora inválido'),
  body('tipo').optional().isIn(['trabalho', 'compromisso']).withMessage('Tipo inválido'),
  body('remunerado').optional().isBoolean(),
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
    const limit = Math.min(1000, Math.max(1, parseInt(req.query.limit) || 20));
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
    tipo_trabalho, contato_nome, contato_telefone,
    tipo, remunerado,
  } = req.body;

  const tipoFinal = tipo === 'compromisso' ? 'compromisso' : 'trabalho';
  const remuneradoFinal = tipoFinal === 'compromisso' ? false : (remunerado !== false);
  const valorHoraFinal = remuneradoFinal ? (parseFloat(valor_hora) || 0) : 0;
  const valorTotalFinal = remuneradoFinal ? (parseFloat(valor_total) || 0) : 0;
  const produtoraFinal = tipoFinal === 'compromisso' ? '' : produtora;

  try {
    const conflito = await verificarConflito(
      req.user.id,
      data.substring(0, 10),
      hora_inicio,
      hora_fim
    );
    if (conflito) {
      return res.status(409).json({
        error: 'Horário indisponível — já existe um agendamento nesse período.',
      });
    }

    const result = await pool.query(
      `INSERT INTO schedules
       (user_id, projeto, produtora, diretor, data, hora_inicio, hora_fim,
        valor_hora, valor_total, realizado, observacao, lembretes,
        tipo_trabalho, contato_nome, contato_telefone, tipo, remunerado)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
       RETURNING *`,
      [
        req.user.id, projeto ?? '', produtoraFinal, diretor ?? null,
        data, hora_inicio, hora_fim,
        valorHoraFinal, valorTotalFinal, realizado ?? false,
        observacao ?? null,
        lembretes ?? { '60min': false, '30min': true, '5min': true, exato: true },
        tipo_trabalho ?? null,
        contato_nome ?? null,
        contato_telefone ?? null,
        tipoFinal,
        remuneradoFinal,
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
    const numId = parseInt(id, 10);
    if (isNaN(numId)) {
      return res.status(400).json({ error: 'ID inválido' });
    }

    const temCampoTemporal = ['data', 'hora_inicio', 'hora_fim']
      .some((k) => req.body[k] !== undefined);

    if (temCampoTemporal) {
      let d  = req.body.data;
      let hi = req.body.hora_inicio;
      let hf = req.body.hora_fim;

      if (d === undefined || hi === undefined || hf === undefined) {
        const cur = await pool.query(
          'SELECT data, hora_inicio, hora_fim FROM schedules WHERE id = $1 AND user_id = $2',
          [id, req.user.id]
        );
        if (cur.rowCount === 0) {
          return res.status(404).json({ error: 'Escala não encontrada' });
        }
        const row = cur.rows[0];
        d  = d  ?? row.data.toISOString().substring(0, 10);
        hi = hi ?? row.hora_inicio;
        hf = hf ?? row.hora_fim;
      }

      const conflito = await verificarConflito(
        req.user.id,
        d.substring(0, 10),
        hi,
        hf,
        numId
      );
      if (conflito) {
        return res.status(409).json({
          error: 'Horário indisponível — já existe um agendamento nesse período.',
        });
      }
    }

    const camposPermitidos = [
      'projeto', 'produtora', 'diretor', 'data',
      'hora_inicio', 'hora_fim', 'valor_hora', 'valor_total',
      'realizado', 'observacao', 'lembretes',
      'tipo_trabalho', 'contato_nome', 'contato_telefone',
      'tipo', 'remunerado',
    ];

    const entradas = Object.entries(req.body).filter(([chave]) =>
      camposPermitidos.includes(chave)
    );

    if (entradas.length === 0) {
      return res.status(400).json({ error: 'Nenhum campo válido para atualizar' });
    }

    // Coerce: force zero values when not remunerated or for compromisso
    const tipoEntry = entradas.find(([k]) => k === 'tipo');
    const remuneradoEntry = entradas.find(([k]) => k === 'remunerado');
    const tipoVal = tipoEntry ? tipoEntry[1] : null;
    const remuneradoRaw = remuneradoEntry ? remuneradoEntry[1] : null;
    const remuneradoVal = remuneradoRaw === false || remuneradoRaw === 'false' ? false : remuneradoRaw;
    if (tipoVal === 'compromisso' || remuneradoVal === false) {
      const override = (k, v) => {
        const idx = entradas.findIndex(([key]) => key === k);
        if (idx >= 0) entradas[idx] = [k, v];
        else entradas.push([k, v]);
      };
      override('valor_hora', 0);
      override('valor_total', 0);
      if (tipoVal === 'compromisso') override('remunerado', false);
    }

    const sets = entradas.map(([chave], i) => `${chave} = $${i + 1}`);
    const valores = entradas.map(([, valor]) => valor);

    valores.push(numId);
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
