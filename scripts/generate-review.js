#!/usr/bin/env node
/**
 * Generate review from evidence.json.
 * Usage: node scripts/generate-review.js [path/to/evidence.json] [--out dir]
 * Writes themes.json, bullets.json, stories.json, self_eval.json to --out (default: current dir).
 */

import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { runPipeline } from "../lib/run-pipeline.js";

const __dirname = dirname(fileURLToPath(import.meta.url));

function parseArgs() {
  const args = process.argv.slice(2);
  let input = null;
  let outDir = process.cwd();
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--out" && args[i + 1]) {
      outDir = args[++i];
    } else if (!args[i].startsWith("--")) {
      input = args[i];
    }
  }
  return { input: input || join(process.cwd(), "evidence.json"), outDir };
}

export { parseArgs };

export async function runGenerateReview(inputPath, outDir, pipelineFn = runPipeline) {
  const evidence = JSON.parse(readFileSync(inputPath, "utf8"));
  const { themes, bullets, stories, self_eval } = await pipelineFn(evidence);
  mkdirSync(outDir, { recursive: true });
  writeFileSync(join(outDir, "themes.json"), JSON.stringify(themes, null, 2));
  writeFileSync(join(outDir, "bullets.json"), JSON.stringify(bullets, null, 2));
  writeFileSync(join(outDir, "stories.json"), JSON.stringify(stories, null, 2));
  writeFileSync(join(outDir, "self_eval.json"), JSON.stringify(self_eval, null, 2));
  return { themes, bullets, stories, self_eval };
}

async function main() {
  const { input, outDir } = parseArgs();
  console.log("Running pipeline...");
  await runGenerateReview(input, outDir);
  console.log("Wrote themes.json, bullets.json, stories.json, self_eval.json to", outDir);
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMain) main().catch((e) => { console.error(e); process.exit(1); });
