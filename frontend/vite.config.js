import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Note: When deploying behind Godproxy, we would disable Vite's 
    // internal config or bind it so the proxy picks it up locally
  }
})
