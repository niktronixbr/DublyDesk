// Carrega .env se existir
require('dotenv').config({
  path: process.env.NODE_ENV === 'test' ? '.env.test' : '.env',
});

// Reduz logs durante testes
const originalLog = console.log;
console.log = (...args) => {
  if (process.env.VERBOSE_TESTS) originalLog(...args);
};
