import { describe, it, expect } from "vitest";
import { validateEvidence } from "../lib/validate-evidence.js";

describe("validateEvidence", () => {
  it("accepts valid evidence with timeframe and contributions", () => {
    const result = validateEvidence({
      timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" },
      contributions: [
        { id: "r#1", type: "pull_request", title: "Fix", url: "https://github.com/a/b/pull/1", repo: "a/b" },
      ],
    });
    expect(result.valid).toBe(true);
  });

  it("accepts evidence with optional role_context_optional", () => {
    const result = validateEvidence({
      timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" },
      role_context_optional: { level: "Senior", focus_areas: ["Backend"] },
      contributions: [],
    });
    expect(result.valid).toBe(true);
  });

  it("rejects missing timeframe", () => {
    const result = validateEvidence({ contributions: [] });
    expect(result.valid).toBe(false);
    expect("errors" in result && result.errors.length).toBeGreaterThan(0);
  });

  it("rejects missing contributions", () => {
    const result = validateEvidence({ timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" } });
    expect(result.valid).toBe(false);
  });

  it("rejects contribution with invalid type", () => {
    const result = validateEvidence({
      timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" },
      contributions: [
        { id: "r#1", type: "invalid", title: "x", url: "https://x", repo: "a/b" },
      ],
    });
    expect(result.valid).toBe(false);
  });
});
