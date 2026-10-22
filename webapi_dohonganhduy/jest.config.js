// Cấu hình Jest cho ES modules. Test chạy trên MongoDB in-memory nên không đụng database thật.
export default {
  testEnvironment: 'node',
  transform: {},
  testMatch: ['**/tests/**/*.test.js'],
  setupFiles: ['<rootDir>/tests/env.setup.js'],
  testTimeout: 60000,
};
