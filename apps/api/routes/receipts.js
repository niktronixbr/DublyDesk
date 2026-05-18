const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const auth = require('../middleware/auth');
const requirePro = require('../middleware/require_pro');
const pool = require('../db');
const { generateReceiptPdf } = require('../services/pdf_generator');
const { sendEmail } = require('../services/email_sender');

const RECEIPTS_DIR = path.join(__dirname, '..', 'uploads', 'receipts');

router.post(
  '/receipts/generate',
  auth,
  requirePro,
  body('scheduleId').isInt({ min: 1 }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'scheduleId inválido' });
    }

    try {
      const scheduleRes = await pool.query(
        `SELECT s.*, u.name AS user_name, u.email AS user_email
           FROM schedules s
           JOIN users u ON u.id = s.user_id
          WHERE s.id = $1 AND s.user_id = $2`,
        [req.body.scheduleId, req.user.id]
      );
      if (scheduleRes.rows.length === 0) {
        return res.status(404).json({ error: 'Escala não encontrada' });
      }
      const schedule = scheduleRes.rows[0];

      const uniqueName = `${schedule.id}-${crypto.randomBytes(8).toString('hex')}.pdf`;
      const userDir = path.join(RECEIPTS_DIR, String(req.user.id));
      const fullPath = path.join(userDir, uniqueName);
      const relativePath = path.relative(path.join(__dirname, '..'), fullPath).replace(/\\/g, '/');

      await generateReceiptPdf({
        outPath: fullPath,
        dublador: {
          nome: schedule.user_name,
          email: schedule.user_email,
          cpf: req.body.cpf,
        },
        produtora: schedule.produtora,
        projeto: schedule.projeto,
        diretor: schedule.diretor,
        data: schedule.data,
        valor: parseFloat(schedule.valor_total),
        observacao: schedule.observacao,
      });

      const { rows } = await pool.query(
        `INSERT INTO receipts (user_id, schedule_id, pdf_path)
         VALUES ($1, $2, $3)
         RETURNING id, pdf_path, created_at`,
        [req.user.id, schedule.id, relativePath]
      );

      res.status(201).json({
        id: rows[0].id,
        pdfPath: rows[0].pdf_path,
        createdAt: rows[0].created_at,
      });
    } catch (err) {
      console.error('❌ /receipts/generate:', err);
      res.status(500).json({ error: 'Erro ao gerar recibo' });
    }
  }
);

router.post(
  '/receipts/:id/send-email',
  auth,
  requirePro,
  body('destinatario').isEmail(),
  body('mensagem').optional().isString(),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'destinatário inválido' });
    }

    try {
      const { rows } = await pool.query(
        `SELECT r.*, s.projeto, s.produtora, s.data
           FROM receipts r
           JOIN schedules s ON s.id = r.schedule_id
          WHERE r.id = $1 AND r.user_id = $2`,
        [req.params.id, req.user.id]
      );
      if (rows.length === 0) return res.status(404).json({ error: 'Recibo não encontrado' });
      const receipt = rows[0];

      const fullPath = path.join(__dirname, '..', receipt.pdf_path);
      if (!fs.existsSync(fullPath)) {
        return res.status(410).json({ error: 'Arquivo do recibo não está mais disponível' });
      }

      const html = `
        <div style="font-family:sans-serif;max-width:520px;margin:auto;color:#333">
          <h2>Recibo — DublyDesk</h2>
          <p>Olá,</p>
          <p>Segue em anexo o recibo referente ao projeto <strong>${receipt.projeto}</strong>.</p>
          ${req.body.mensagem ? `<p>${req.body.mensagem}</p>` : ''}
          <p style="color:#888;font-size:12px;margin-top:30px">
            Enviado automaticamente pelo DublyDesk.
          </p>
        </div>
      `;

      await sendEmail({
        to: req.body.destinatario,
        subject: `Recibo — ${receipt.projeto}`,
        html,
        attachments: [
          { filename: `recibo-${receipt.id}.pdf`, path: fullPath },
        ],
      });

      await pool.query(
        `UPDATE receipts SET sent_email = $1, sent_at = NOW() WHERE id = $2`,
        [req.body.destinatario, receipt.id]
      );

      res.json({ ok: true });
    } catch (err) {
      console.error('❌ /receipts/:id/send-email:', err);
      res.status(500).json({ error: 'Erro ao enviar email' });
    }
  }
);

router.get('/receipts/pending', auth, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, projeto, produtora, diretor, data, valor_total, status_pagamento, valor_pago, vencimento
         FROM schedules
        WHERE user_id = $1
          AND status_pagamento != 'pago'
          AND realizado = TRUE
        ORDER BY data DESC`,
      [req.user.id]
    );

    const totalPendente = rows.reduce(
      (sum, r) => sum + parseFloat(r.valor_total) - parseFloat(r.valor_pago),
      0
    );

    res.json({ items: rows, totalPendente: Math.round(totalPendente * 100) / 100 });
  } catch (err) {
    console.error('❌ /receipts/pending:', err);
    res.status(500).json({ error: 'Erro ao listar pendentes' });
  }
});

module.exports = router;
