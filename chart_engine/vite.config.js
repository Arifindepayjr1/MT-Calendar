import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  build: {
    outDir: '../web/trade_chart',
    emptyOutDir: true,
    target: 'es2020',
    rollupOptions: {
      output: {
        entryFileNames: 'chart.js',
        chunkFileNames: 'chunks/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash][extname]',
      },
    },
  },
});
