import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    setupFiles: ["./test/setup.js"],
    include: ["test/**/*.test.js"],
    pool: "forks",
    coverage: {
      provider: "v8",
      exclude: ["**/*.css", "**/node_modules/**", "**/dist/**", "**/*.config.*", "test/**"],
      reporter: ["text", "text-summary"],
    },
  },
});
