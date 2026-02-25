import { describe, it, expect, vi } from "vitest";
import { collectRaw, parseArgs } from "../scripts/collect-github.js";

describe("parseArgs", () => {
  it("parses --start, --end, --output, --no-reviews", () => {
    const orig = process.argv.slice(2);
    process.argv = ["node", "collect-github.js", "--start", "2025-01-01", "--end", "2025-12-31", "--output", "out.json", "--no-reviews"];
    const out = parseArgs();
    expect(out.start).toBe("2025-01-01");
    expect(out.end).toBe("2025-12-31");
    expect(out.output).toBe("out.json");
    expect(out.noReviews).toBe(true);
    process.argv = ["node", "collect-github.js", ...orig];
  });
});

describe("collectRaw", () => {
  it("returns timeframe, pull_requests, reviews with mocked fetch", async () => {
    const mockFetch = vi.fn()
      .mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ login: "testuser" }),
        text: () => Promise.resolve(""),
      })
      .mockResolvedValueOnce({
        ok: true,
        json: () =>
          Promise.resolve({
            items: [
              {
                pull_request: { url: "https://api.github.com/repos/org/repo/pulls/42" },
              },
            ],
          }),
        text: () => Promise.resolve(""),
      })
      .mockResolvedValueOnce({
        ok: true,
        json: () =>
          Promise.resolve({
            number: 42,
            title: "Fix bug",
            base: { repo: { full_name: "org/repo" } },
          }),
        text: () => Promise.resolve(""),
      })
      .mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve([]),
        text: () => Promise.resolve(""),
      });

    const result = await collectRaw({
      start: "2025-01-01",
      end: "2025-12-31",
      noReviews: false,
      token: "ghp_test",
      fetchFn: mockFetch,
    });

    expect(result.timeframe).toEqual({ start_date: "2025-01-01", end_date: "2025-12-31" });
    expect(result.pull_requests).toHaveLength(1);
    expect(result.pull_requests[0].title).toBe("Fix bug");
    expect(result.reviews).toHaveLength(0);
    expect(mockFetch).toHaveBeenCalledTimes(4);
  });

  it("with noReviews skips reviews fetch", async () => {
    const mockFetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ login: "u" }), text: () => Promise.resolve("") })
      .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ items: [] }), text: () => Promise.resolve("") });

    const result = await collectRaw({
      start: "2025-01-01",
      end: "2025-12-31",
      noReviews: true,
      token: "x",
      fetchFn: mockFetch,
    });
    expect(result.pull_requests).toHaveLength(0);
    expect(result.reviews).toHaveLength(0);
    expect(mockFetch).toHaveBeenCalledTimes(2);
  });
});
