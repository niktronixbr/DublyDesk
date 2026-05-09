const { Pool } = require('pg');

let pool;

if (process.env.DATABASE_URL) {
  const ssl = process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: false };
  pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl,
  });
} else {
  pool = new Pool({
    user: 'postgres',
    host: 'db',
    database: 'dublagem',
    password: 'postgres',
    port: 5432,
  });
}

module.exports = pool;
