import { defineConfig } from 'vitest/config';

export default defineConfig({
  // Relative base so the same build works from a web server and inside Capacitor.
  base: './',
  server: { host: true },
  preview: { host: true },
  build: {
    target: 'es2020',
    assetsInlineLimit: 0,
    chunkSizeWarningLimit: 1200,
  },
  test: {
    include: ['tests/**/*.test.ts'],
    environment: 'node',
  },
});
