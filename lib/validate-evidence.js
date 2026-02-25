import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import Ajv from "ajv";

const __dirname = dirname(fileURLToPath(import.meta.url));
const schemaPath = join(__dirname, "..", "schemas", "evidence.json");
const schema = JSON.parse(readFileSync(schemaPath, "utf8"));
const ajv = new Ajv({ strict: false });
const validate = ajv.compile(schema);

/**
 * @param {unknown} data
 * @returns {{ valid: true } | { valid: false; errors: import('ajv').ErrorObject[] }}
 */
export function validateEvidence(data) {
  const valid = validate(data);
  if (valid) return { valid: true };
  return { valid: false, errors: validate.errors ?? [] };
}
