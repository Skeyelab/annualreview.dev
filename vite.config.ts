import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const railsOrigin = process.env.RAILS_ORIGIN || "http://localhost:3000";

export default defineConfig({
  plugins: [react()],
  envPrefix: ["VITE_", "POSTHOG"],
  server: {
    port: 5173,
    strictPort: true,
    proxy: {
      "/api": { target: railsOrigin, changeOrigin: true },
      "/auth": { target: railsOrigin, changeOrigin: true },
    },
  },
});
