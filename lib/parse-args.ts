export interface FlagSpec {
  name: string;
  option: string;
  type: "string" | "boolean";
}

export interface PositionalSpec {
  name: string;
}

export interface ParseArgsSchema {
  flags?: FlagSpec[];
  positionals?: PositionalSpec[];
  defaults?: Record<string, unknown | (() => unknown)>;
}

/**
 * Schema-driven CLI argument parser. Use from scripts to avoid duplicated parseArgs logic.
 */
export function parseArgs(
  schema: ParseArgsSchema,
  argv: string[] = process.argv.slice(2)
): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  const positionals: string[] = [];

  for (const f of schema.flags ?? []) {
    result[f.name] = f.type === "boolean" ? false : null;
  }

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const flag = schema.flags?.find((f) => f.option === arg);
    if (flag) {
      if (flag.type === "boolean") {
        result[flag.name] = true;
      } else if (argv[i + 1] != null) {
        result[flag.name] = argv[++i];
      }
      continue;
    }
    if (!arg.startsWith("--")) {
      positionals.push(arg);
    }
  }

  for (let j = 0; j < (schema.positionals ?? []).length; j++) {
    const p = schema.positionals![j];
    result[p.name] = positionals[j] ?? null;
  }

  for (const [key, val] of Object.entries(schema.defaults ?? {})) {
    if (result[key] == null) {
      result[key] = typeof val === "function" ? (val as () => unknown)() : val;
    }
  }

  return result;
}
