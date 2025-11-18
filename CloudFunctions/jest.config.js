module.exports = {
  testEnvironment: 'node',
  coveragePathIgnorePatterns: ['/node_modules/'],
  testMatch: ['**/__tests__/**/*.test.js'],
  collectCoverageFrom: [
    '**/*.js',
    '!**/node_modules/**',
    '!**/coverage/**',
    '!jest.config.js',
  ],
  // Coverage thresholds for critical payment and security modules
  coverageThreshold: {
    './modules/receiptValidation.js': {
      branches: 70,
      functions: 70,
      lines: 90,
      statements: 90,
    },
    './modules/fraudDetection.js': {
      branches: 75,
      functions: 90,
      lines: 80,
      statements: 80,
    },
    './modules/adminSecurity.js': {
      branches: 85,
      functions: 100,
      lines: 100,
      statements: 100,
    },
  },
  // Clear mocks between tests
  clearMocks: true,
  // Reset mocks between tests
  resetMocks: true,
  // Restore mocks between tests
  restoreMocks: true,
};
