/**
 * In-memory store for verified Stripe payment sessions.
 * Prevents double-use of a session and caches verification results.
 */

const PAID_SESSION_MAX = 1000;

/** Set of Stripe session IDs that have been verified as paid. */
const paidSessions = new Set<string>();

export function markSessionPaid(sessionId: string): void {
  // ES2015+ guarantees Set iterates in insertion order, so this evicts the oldest entry.
  if (paidSessions.size >= PAID_SESSION_MAX) {
    const first = paidSessions.values().next().value;
    if (first !== undefined) paidSessions.delete(first);
  }
  paidSessions.add(sessionId);
}

export function isSessionPaid(sessionId: string): boolean {
  return paidSessions.has(sessionId);
}

/** Clear store (for tests). */
export function clearPaymentStore(): void {
  paidSessions.clear();
}
