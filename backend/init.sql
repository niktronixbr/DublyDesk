DROP TABLE IF EXISTS schedules;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE schedules (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  projeto TEXT NOT NULL,
  produtora TEXT NOT NULL,
  diretor TEXT,

  data TIMESTAMP NOT NULL,
  hora_inicio VARCHAR(5) NOT NULL,
  hora_fim VARCHAR(5) NOT NULL,

  valor_hora NUMERIC(10,2) NOT NULL DEFAULT 0,
  valor_total NUMERIC(10,2) NOT NULL DEFAULT 0,

  realizado BOOLEAN NOT NULL DEFAULT false,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_schedules_user_id ON schedules(user_id);
CREATE INDEX idx_schedules_data ON schedules(data DESC);
CREATE INDEX idx_schedules_user_realizado ON schedules(user_id, realizado);
CREATE INDEX idx_schedules_produtora ON schedules(user_id, produtora);
