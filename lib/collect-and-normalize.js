/**
 * Fetch GitHub data for the authenticated user and return evidence JSON.
 * Uses GraphQL collector (batched) + normalize (evidence contract).
 * Token is used in-memory only; never stored or logged.
 *
 * @param {{ token: string, start_date: string, end_date: string }} opts
 * @returns {Promise<{ timeframe: { start_date: string, end_date: string }, contributions: unknown[], role_context_optional?: unknown }>}
 */
export async function collectAndNormalize({ token, start_date, end_date }) {
  const { collectRawGraphQL } = await import("../scripts/collect-github.js");
  const { normalize } = await import("../scripts/normalize.js");

  const raw = await collectRawGraphQL({
    start: start_date,
    end: end_date,
    noReviews: false,
    token,
  });

  return normalize(raw, start_date, end_date);
}
