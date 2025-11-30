import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Security headers plugin for development server
const securityHeadersPlugin = () => ({
  name: 'security-headers',
  configureServer(server) {
    server.middlewares.use((req, res, next) => {
      // Content Security Policy
      res.setHeader(
        'Content-Security-Policy',
        "default-src 'self'; " +
        "script-src 'self' 'unsafe-inline' 'unsafe-eval'; " + // unsafe-eval needed for dev mode
        "style-src 'self' 'unsafe-inline'; " +
        "img-src 'self' data: https: blob:; " +
        "font-src 'self' data:; " +
        "connect-src 'self' http://127.0.0.1:* http://localhost:* https://*.firebaseio.com https://*.googleapis.com https://identitytoolkit.googleapis.com wss://*.firebaseio.com; " +
        "frame-src 'none'; " +
        "object-src 'none'; " +
        "base-uri 'self';"
      );

      // Additional security headers
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('X-Frame-Options', 'DENY');
      res.setHeader('X-XSS-Protection', '1; mode=block');
      res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
      res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');

      next();
    });
  }
});

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    react(),
    securityHeadersPlugin()
  ],
  server: {
    port: 5173,
    open: true
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
    // Manual chunk splitting for better caching and smaller initial bundle
    rollupOptions: {
      output: {
        manualChunks: {
          // React core (changes rarely, cache well)
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],

          // Material-UI (large library, separate chunk)
          'mui-vendor': ['@mui/material', '@mui/icons-material'],

          // Firebase (separate chunk for authentication and firestore)
          'firebase-vendor': ['firebase/app', 'firebase/auth', 'firebase/firestore']
        }
      }
    },
    // Increase chunk size warning limit slightly (we're splitting now)
    chunkSizeWarningLimit: 600
  }
});
