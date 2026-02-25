// Validate a JSON file against schemas/evidence.json. Usage: node scripts/validate-evidence.js [path]

import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";
import { validateEvidence } from "../lib/validate-evidence.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));
const evidencePath = process.argv[2] || join(process.cwd(), "evidence.json");
const data = JSON.parse(readFileSync(evidencePath, "utf8"));
const result = validateEvidence(data);

if (result.valid) {
  console.log("Valid:", evidencePath);
} else {
  console.error("Invalid:", evidencePath);
  console.error(result.errors);
  process.exit(1);
}
