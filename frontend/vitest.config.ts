import { defineConfig } from "vitest/config";
import viteConfig from "./vite.config";

export default defineConfig({
  ...viteConfig,
  test: {
    globals: true,
    setupFiles: ["./test/setup.js"],
    environment: "jsdom",
    include: ["test/**/*.test.{js,jsx,ts,tsx}"],
    coverage: {
      provider: "v8",
      exclude: ["**/*.css", "**/node_modules/**", "**/dist/**", "**/*.config.*", "test/**"],
      reporter: ["text", "text-summary"],
    },
  },
});
