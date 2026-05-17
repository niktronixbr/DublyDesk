const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../../db');

async function createTestUser(overrides = {}) {
  const name = overrides.name || 'Test User';
  const email = overrides.email || `test-${Date.now()}-${Math.random()}@example.com`;
  const password = overrides.password || 'senha123';
  const passwordHash = await bcrypt.hash(password, 10);

  const { rows } = await pool.query(
    `INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3) RETURNING id, name, email`,
    [name, email, passwordHash]
  );

  const user = rows[0];
  const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET || 'test-secret', { expiresIn: '1h' });
  return { user, token, password };
}

async function createTestSchedule(userId, overrides = {}) {
  const { rows } = await pool.query(
    `INSERT INTO schedules (user_id, projeto, produtora, diretor, data, hora_inicio, hora_fim, valor_total, realizado)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
    [
      userId,
      overrides.projeto || 'Projeto Teste',
      overrides.produtora || 'Produtora X',
      overrides.diretor || 'Diretor Y',
      overrides.data || new Date().toISOString(),
      overrides.hora_inicio || '14:00',
      overrides.hora_fim || '15:00',
      overrides.valor_total ?? 500,
      overrides.realizado ?? true,
    ]
  );
  return rows[0];
}

module.exports = { createTestUser, createTestSchedule };
