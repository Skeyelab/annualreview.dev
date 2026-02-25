import type { Evidence } from "../types/evidence.js";

export interface CollectOptions {
  token: string;
  start_date: string;
  end_date: string;
}

/**
 * Fetch GitHub data for the authenticated user and return evidence JSON.
 * Uses GraphQL collector (batched) + normalize (evidence contract).
 * Token is used in-memory only; never stored or logged.
 */
export async function collectAndNormalize({ token, start_date, end_date }: CollectOptions): Promise<Evidence> {
  const { collectRawGraphQL } = await import("../scripts/collect-github.ts");
  const { normalize } = await import("../scripts/normalize.ts");

  const raw = await collectRawGraphQL({
    start: start_date,
    end: end_date,
    noReviews: false,
    token,
  });

  return normalize(raw, start_date, end_date) as unknown as Evidence;
}
