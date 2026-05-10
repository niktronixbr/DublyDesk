const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const rateLimit = require('express-rate-limit');
const multer = require('multer');
const pool = require('../db');
const auth = require('../middleware/auth');

const router = express.Router();

const AVATAR_DIR = path.join(__dirname, '..', 'uploads', 'avatars');

const avatarStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, AVATAR_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `${req.user.id}-${Date.now()}${ext}`);
  },
});

const avatarUpload = multer({
  storage: avatarStorage,
  limits: { fileSize: 2 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (!['image/jpeg', 'image/jpg', 'image/png', 'image/webp'].includes(file.mimetype)) {
      return cb(new Error('Formato inválido. Use JPG, PNG ou WebP.'));
    }
    cb(null, true);
  },
});

const JWT_SECRET = process.env.JWT_SECRET || 'segredo_super_seguro';

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Muitas tentativas. Tente novamente em 15 minutos.' },
});

router.post('/register', authLimiter, async (req, res) => {
  const { name, email, password } = req.body;

  try {
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Preencha nome, email e senha' });
    }

    const existing = await pool.query(
      'SELECT id FROM users WHERE email = $1',
      [email]
    );

    if (existing.rowCount > 0) {
      return res.status(400).json({ error: 'Email já cadastrado' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `INSERT INTO users (name, email, password_hash)
       VALUES ($1, $2, $3)
       RETURNING id, name, email, avatar_url`,
      [name, email, passwordHash]
    );

    const user = result.rows[0];

    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        avatarUrl: user.avatar_url,
      },
    });
  } catch (err) {
    console.error('POST /auth/register error:', err);
    res.status(500).json({ error: 'Erro ao cadastrar usuário' });
  }
});

router.post('/login', authLimiter, async (req, res) => {
  const { email, password } = req.body;

  try {
    if (!email || !password) {
      return res.status(400).json({ error: 'Informe email e senha' });
    }

    const result = await pool.query(
      'SELECT * FROM users WHERE email = $1',
      [email]
    );

    if (result.rowCount === 0) {
      return res.status(400).json({ error: 'Usuário não encontrado' });
    }

    const user = result.rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);

    if (!ok) {
      return res.status(400).json({ error: 'Senha incorreta' });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        avatarUrl: user.avatar_url,
      },
    });
  } catch (err) {
    console.error('POST /auth/login error:', err);
    res.status(500).json({ error: 'Erro ao fazer login' });
  }
});

const forgotLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Muitas tentativas. Tente novamente em 15 minutos.' },
});

// POST /auth/forgot-password
router.post('/forgot-password', forgotLimiter, async (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Informe o email' });
  }

  try {
    const result = await pool.query(
      'SELECT id FROM users WHERE email = $1',
      [email.trim().toLowerCase()]
    );

    // Resposta genérica para não revelar se o email existe
    if (result.rowCount === 0) {
      return res.json({
        message: 'Se o email estiver cadastrado, você receberá o código.',
      });
    }

    const userId = result.rows[0].id;

    // Código de 6 dígitos, válido por 1 hora
    const token = crypto.randomInt(100000, 999999).toString();
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);

    // Invalida tokens anteriores do usuário
    await pool.query('DELETE FROM password_resets WHERE user_id = $1', [userId]);

    await pool.query(
      'INSERT INTO password_resets (user_id, token, expires_at) VALUES ($1, $2, $3)',
      [userId, token, expiresAt]
    );

    if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
      const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT || '587'),
        secure: false,
        auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
      });

      await transporter.sendMail({
        from: `"DublyDesk" <${process.env.SMTP_USER}>`,
        to: email,
        subject: 'Redefinição de senha — DublyDesk',
        text: `Seu código de redefinição de senha é: ${token}\n\nEsse código é válido por 1 hora.\nSe você não solicitou isso, ignore este email.`,
        html: `
          <div style="font-family:sans-serif;max-width:400px;margin:auto">
            <h2>DublyDesk — Redefinição de senha</h2>
            <p>Use o código abaixo no app para criar uma nova senha:</p>
            <h1 style="letter-spacing:8px;color:#6C63FF">${token}</h1>
            <p style="color:#888">Válido por 1 hora. Se não foi você, ignore este email.</p>
          </div>`,
      });
    } else {
      // Sem SMTP configurado: exibe o código no log do servidor
      console.log(`[DEV] Código de recuperação para ${email}: ${token}`);
    }

    res.json({ message: 'Se o email estiver cadastrado, você receberá o código.' });
  } catch (err) {
    console.error('POST /auth/forgot-password error:', err);
    res.status(500).json({ error: 'Erro ao processar solicitação' });
  }
});

// POST /auth/reset-password
router.post('/reset-password', async (req, res) => {
  const { email, token, newPassword } = req.body;

  if (!email || !token || !newPassword) {
    return res.status(400).json({ error: 'Email, código e nova senha são obrigatórios' });
  }

  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'A senha deve ter pelo menos 6 caracteres' });
  }

  try {
    const result = await pool.query(
      `SELECT pr.id, pr.user_id
       FROM password_resets pr
       JOIN users u ON u.id = pr.user_id
       WHERE u.email = $1
         AND pr.token = $2
         AND pr.used = false
         AND pr.expires_at > NOW()`,
      [email.trim().toLowerCase(), token.trim()]
    );

    if (result.rowCount === 0) {
      return res.status(400).json({ error: 'Código inválido ou expirado' });
    }

    const { id: resetId, user_id } = result.rows[0];
    const passwordHash = await bcrypt.hash(newPassword, 10);

    await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [
      passwordHash,
      user_id,
    ]);

    await pool.query('UPDATE password_resets SET used = true WHERE id = $1', [resetId]);

    res.json({ message: 'Senha redefinida com sucesso' });
  } catch (err) {
    console.error('POST /auth/reset-password error:', err);
    res.status(500).json({ error: 'Erro ao redefinir senha' });
  }
});

// GET /auth/me — dados do usuário logado (incluindo avatar_url)
router.get('/me', auth, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, email, avatar_url FROM users WHERE id = $1',
      [req.user.id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }

    const user = result.rows[0];
    res.json({
      id: user.id,
      name: user.name,
      email: user.email,
      avatarUrl: user.avatar_url,
    });
  } catch (err) {
    console.error('GET /auth/me error:', err);
    res.status(500).json({ error: 'Erro ao buscar usuário' });
  }
});

// POST /auth/avatar — upload de foto de perfil (campo "avatar")
router.post('/avatar', auth, (req, res) => {
  avatarUpload.single('avatar')(req, res, async (err) => {
    if (err) {
      const message = err instanceof multer.MulterError
        ? (err.code === 'LIMIT_FILE_SIZE' ? 'Imagem muito grande (máx 2MB)' : err.message)
        : err.message;
      return res.status(400).json({ error: message });
    }

    if (!req.file) {
      return res.status(400).json({ error: 'Arquivo "avatar" não enviado' });
    }

    try {
      const previous = await pool.query(
        'SELECT avatar_url FROM users WHERE id = $1',
        [req.user.id]
      );

      const url = `/uploads/avatars/${req.file.filename}`;
      await pool.query(
        'UPDATE users SET avatar_url = $1 WHERE id = $2',
        [url, req.user.id]
      );

      // Remove a foto anterior do disco (se houver e for arquivo local).
      const oldUrl = previous.rows[0]?.avatar_url;
      if (oldUrl && oldUrl.startsWith('/uploads/avatars/')) {
        const oldPath = path.join(__dirname, '..', oldUrl);
        fs.unlink(oldPath, () => {});
      }

      res.json({ avatarUrl: url });
    } catch (dbErr) {
      console.error('POST /auth/avatar error:', dbErr);
      res.status(500).json({ error: 'Erro ao salvar foto de perfil' });
    }
  });
});

// DELETE /auth/avatar — remove a foto de perfil
router.delete('/avatar', auth, async (req, res) => {
  try {
    const previous = await pool.query(
      'SELECT avatar_url FROM users WHERE id = $1',
      [req.user.id]
    );

    await pool.query(
      'UPDATE users SET avatar_url = NULL WHERE id = $1',
      [req.user.id]
    );

    const oldUrl = previous.rows[0]?.avatar_url;
    if (oldUrl && oldUrl.startsWith('/uploads/avatars/')) {
      const oldPath = path.join(__dirname, '..', oldUrl);
      fs.unlink(oldPath, () => {});
    }

    res.json({ ok: true });
  } catch (err) {
    console.error('DELETE /auth/avatar error:', err);
    res.status(500).json({ error: 'Erro ao remover foto de perfil' });
  }
});

module.exports = router;
