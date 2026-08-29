import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

// https://vitejs.dev/config/
export default defineConfig({
  // The Rust backend serves the production app at root. Keep an override for
  // deployments that deliberately mount the app below another path.
  base: process.env.VITE_BASE || '/',
  server: {
    // Proxy API calls to the Rust backend during development.
    proxy: {
      '/api': 'http://localhost:8080',
    },
  },
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: [
        'favicon.ico',
        'favicon-16.png',
        'favicon-32.png',
        'apple-touch-icon.png',
        'icon-192.png',
        'icon-512.png',
        'icon-192-maskable.png',
        'icon-512-maskable.png',
      ],
      manifest: {
        name: 'Train Together',
        short_name: 'Train Together',
        description: 'Strength workout logger for two people on one phone',
        display: 'standalone',
        orientation: 'portrait',
        background_color: '#F1E6D0',
        theme_color: '#181816',
        start_url: '.',
        scope: '.',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
          { src: 'icon-192-maskable.png', sizes: '192x192', type: 'image/png', purpose: 'maskable' },
          { src: 'icon-512-maskable.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,svg,png,ico,woff2}'],
        // Every device uses exactly one launch image, matched by media query, so
        // precaching all of them would cost each install ~60 KB for nothing.
        globIgnores: ['**/splash/**'],
        runtimeCaching: [
          {
            // Google Fonts stylesheet + font files — keep the app's typography offline.
            urlPattern: /^https:\/\/fonts\.(googleapis|gstatic)\.com\/.*/i,
            handler: 'StaleWhileRevalidate',
            options: {
              cacheName: 'google-fonts',
              expiration: { maxEntries: 20, maxAgeSeconds: 60 * 60 * 24 * 365 },
              cacheableResponse: { statuses: [0, 200] },
            },
          },
        ],
      },
    }),
  ],
})
