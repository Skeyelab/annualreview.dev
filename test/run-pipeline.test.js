import { describe, it, expect, vi } from "vitest";
import { extractJson, runPipeline } from "../lib/run-pipeline.js";

const mockThemes = { themes: [{ theme_id: "t1", theme_name: "Reliability" }] };
const mockBullets = { bullets_by_theme: [], top_10_bullets_overall: [] };
const mockStories = { stories: [] };
const mockSelfEval = { sections: { summary: { text: "Done" } } };

vi.mock("openai", () => ({
  default: function MockOpenAI() {
    const create = (content) => Promise.resolve({ choices: [{ message: { content } }] });
    const contents = [
      JSON.stringify(mockThemes),
      JSON.stringify(mockBullets),
      JSON.stringify(mockStories),
      JSON.stringify(mockSelfEval),
    ];
    let i = 0;
    this.chat = {
      completions: {
        create: () => Promise.resolve({ choices: [{ message: { content: contents[i++ % 4] } }] }),
      },
    };
  },
}));

describe("extractJson", () => {
  it("extracts a single JSON object", () => {
    expect(extractJson('{"a":1}')).toEqual({ a: 1 });
  });

  it("strips leading and trailing text", () => {
    expect(extractJson("Here is the result:\n{\"themes\":[]}\nDone.")).toEqual({ themes: [] });
  });

  it("uses first { and last } for nested object", () => {
    expect(extractJson("x{\"nested\":{\"b\":2}}y")).toEqual({ nested: { b: 2 } });
  });

  it("throws when no object found", () => {
    expect(() => extractJson("no json here")).toThrow("No JSON object");
  });
});

describe("runPipeline", () => {
  it("throws when OPENAI_API_KEY is missing", async () => {
    const orig = process.env.OPENAI_API_KEY;
    delete process.env.OPENAI_API_KEY;
    try {
      await expect(runPipeline({ timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" }, contributions: [] })).rejects.toThrow("OPENAI_API_KEY");
    } finally {
      if (orig !== undefined) process.env.OPENAI_API_KEY = orig;
    }
  });

  it("returns themes, bullets, stories, self_eval with mocked OpenAI", async () => {
    const evidence = {
      timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" },
      contributions: [],
    };
    const result = await runPipeline(evidence, { apiKey: "sk-test" });
    expect(result).toEqual({ themes: mockThemes, bullets: mockBullets, stories: mockStories, self_eval: mockSelfEval });
  });
});
