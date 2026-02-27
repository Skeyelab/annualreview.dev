/**
 * Generate API: POST / - validate evidence, create job, run pipeline in background.
 * Supports an optional _stripe_session_id field for premium (higher-quality) generation.
 * Returns Connect-style middleware (req, res, next).
 */

import type { IncomingMessage, ServerResponse } from "http";
import type { ValidationResult } from "../../lib/validate-evidence.js";
import type { Evidence } from "../../types/evidence.js";
import type { PipelineResult } from "../../lib/run-pipeline.js";
import { isSessionPaid, markSessionPaid } from "../../lib/payment-store.js";
import Stripe from "stripe";

export interface GenerateRoutesOptions {
  readJsonBody: (req: IncomingMessage) => Promise<object>;
  respondJson: (res: ServerResponse, status: number, data: object) => void;
  validateEvidence: (evidence: unknown) => ValidationResult;
  createJob: (type: string) => string;
  runInBackground: (
    jobId: string,
    fn: (report: (data: { progress?: string }) => void) => void | Promise<void>
  ) => void;
  runPipeline: (
    evidence: Evidence,
    opts: { onProgress: (data: { stepIndex: number; total: number; label: string }) => void; premium?: boolean }
  ) => Promise<PipelineResult>;
  /** Optional injected Stripe client (for tests). */
  getStripe?: () => Stripe | null;
}

type Next = () => void;

function defaultGetStripe(): Stripe | null {
  const key = process.env.STRIPE_SECRET_KEY;
  return key ? new Stripe(key) : null;
}

/** Verify a Stripe Checkout session is paid. Returns true on success. */
async function verifyStripeSession(sessionId: string, getStripe: () => Stripe | null): Promise<boolean> {
  if (isSessionPaid(sessionId)) return true;
  const stripe = getStripe();
  if (!stripe) return false;
  try {
    const session = await stripe.checkout.sessions.retrieve(sessionId);
    if (session.payment_status === "paid") {
      markSessionPaid(sessionId);
      return true;
    }
  } catch {
    // session not found or API error → not paid
  }
  return false;
}

export function generateRoutes(options: GenerateRoutesOptions) {
  const {
    readJsonBody,
    respondJson,
    validateEvidence,
    createJob,
    runInBackground,
    runPipeline,
    getStripe = defaultGetStripe,
  } = options;

  return async function generateMiddleware(
    req: IncomingMessage,
    res: ServerResponse,
    next: Next
  ): Promise<void> {
    if (req.method !== "POST") {
      next();
      return;
    }
    try {
      const body = await readJsonBody(req);

      const { _stripe_session_id: rawSessionId, ...evidence } = body as Record<string, unknown>;
      const stripeSessionId = typeof rawSessionId === "string" ? rawSessionId : undefined;

      const validation = validateEvidence(evidence);
      if (!validation.valid) {
        const msg =
          validation.errors?.length
            ? validation.errors
                .map((e) => `${e.instancePath ?? "evidence"} ${e.message}`)
                .join("; ")
            : "Evidence must have timeframe (start_date, end_date) and contributions array.";
        respondJson(res, 400, { error: "Invalid evidence", details: msg });
        return;
      }

      // Verify payment if a session ID was provided
      let premium = false;
      if (stripeSessionId) {
        premium = await verifyStripeSession(stripeSessionId, getStripe);
        if (!premium) {
          respondJson(res, 402, { error: "Payment required or session not found" });
          return;
        }
      }

      const jobId = createJob(premium ? "generate-premium" : "generate");
      runInBackground(jobId, (report) =>
        runPipeline(evidence as Evidence, {
          premium,
          onProgress: ({ stepIndex, total, label }) =>
            report({ progress: `${stepIndex}/${total} ${label}` }),
        })
      );
      respondJson(res, 202, { job_id: jobId, premium });
    } catch (e) {
      const err = e as Error;
      respondJson(res, 500, { error: err.message || "Pipeline failed" });
    }
  };
}
