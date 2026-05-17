module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.js'],
  testPathIgnorePatterns: ['/node_modules/', '/helpers/'],
  setupFiles: ['<rootDir>/__tests__/helpers/setup.js'],
  testTimeout: 15000,
};
