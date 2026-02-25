import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    ui: true,
    globals: true,
    setupFiles: ["./test/setup.js"],
  },
});
