import { describe, it, expect, vi, beforeEach } from "vitest";
import { generateRoutes } from "../server/routes/generate.ts";
import { clearPaymentStore, markSessionPaid } from "../lib/payment-store.ts";

function respondJson(res, status, data) {
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json");
  res.end(JSON.stringify(data));
}

function mockRes() {
  return {
    statusCode: 200,
    headers: {},
    setHeader(k, v) { this.headers[k] = v; },
    end(data) { this._body = data; },
    _body: null,
    get body() { return JSON.parse(this._body || "{}"); },
  };
}

const validEvidence = {
  timeframe: { start_date: "2025-01-01", end_date: "2025-12-31" },
  contributions: [],
};

function makeOptions(overrides = {}) {
  const runPipeline = vi.fn().mockResolvedValue({ themes: {}, bullets: {}, stories: {}, self_eval: {} });
  const createJob = vi.fn().mockReturnValue("job-1");
  const runInBackground = vi.fn((jobId, fn) => fn(() => {}));
  return {
    readJsonBody: vi.fn().mockResolvedValue({ ...validEvidence }),
    respondJson,
    validateEvidence: (ev) => ({ valid: !!ev?.timeframe?.start_date }),
    createJob,
    runInBackground,
    runPipeline,
    getStripe: () => null,
    ...overrides,
  };
}

describe("generateRoutes – premium flag", () => {
  beforeEach(() => clearPaymentStore());

  it("runs free pipeline when no stripe_session_id", async () => {
    const opts = makeOptions();
    const handler = generateRoutes(opts);
    const req = { method: "POST", url: "/" };
    const res = mockRes();
    await handler(req, res, () => {});
    expect(opts.createJob).toHaveBeenCalledWith("generate");
    expect(opts.runPipeline).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ premium: false })
    );
    expect(res.body).toMatchObject({ job_id: "job-1", premium: false });
  });

  it("returns 402 when stripe_session_id is provided but session not paid", async () => {
    const opts = makeOptions({
      readJsonBody: vi.fn().mockResolvedValue({
        ...validEvidence,
        _stripe_session_id: "cs_unpaid",
      }),
      getStripe: () => ({
        checkout: {
          sessions: {
            retrieve: vi.fn().mockResolvedValue({ payment_status: "unpaid", id: "cs_unpaid" }),
          },
        },
      }),
    });
    const handler = generateRoutes(opts);
    const req = { method: "POST", url: "/" };
    const res = mockRes();
    await handler(req, res, () => {});
    expect(res.statusCode).toBe(402);
    expect(res.body.error).toMatch(/payment required/i);
    expect(opts.runPipeline).not.toHaveBeenCalled();
  });

  it("runs premium pipeline when stripe session is already marked paid", async () => {
    markSessionPaid("cs_paid_123");
    const opts = makeOptions({
      readJsonBody: vi.fn().mockResolvedValue({
        ...validEvidence,
        _stripe_session_id: "cs_paid_123",
      }),
    });
    const handler = generateRoutes(opts);
    const req = { method: "POST", url: "/" };
    const res = mockRes();
    await handler(req, res, () => {});
    expect(opts.createJob).toHaveBeenCalledWith("generate-premium");
    expect(opts.runPipeline).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ premium: true })
    );
    expect(res.body).toMatchObject({ job_id: "job-1", premium: true });
  });

  it("runs premium pipeline when stripe session is verified as paid via API", async () => {
    const mockStripe = {
      checkout: {
        sessions: {
          retrieve: vi.fn().mockResolvedValue({ payment_status: "paid", id: "cs_stripe_paid" }),
        },
      },
    };
    const opts = makeOptions({
      readJsonBody: vi.fn().mockResolvedValue({
        ...validEvidence,
        _stripe_session_id: "cs_stripe_paid",
      }),
      getStripe: () => mockStripe,
    });
    const handler = generateRoutes(opts);
    const req = { method: "POST", url: "/" };
    const res = mockRes();
    await handler(req, res, () => {});
    expect(opts.createJob).toHaveBeenCalledWith("generate-premium");
    expect(opts.runPipeline).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ premium: true })
    );
    expect(res.body).toMatchObject({ premium: true });
  });

  it("strips _stripe_session_id from evidence before validation and pipeline", async () => {
    markSessionPaid("cs_strip_test");
    let capturedEvidence = null;
    const opts = makeOptions({
      readJsonBody: vi.fn().mockResolvedValue({
        ...validEvidence,
        _stripe_session_id: "cs_strip_test",
      }),
      runPipeline: vi.fn((ev, _opts) => {
        capturedEvidence = ev;
        return Promise.resolve({ themes: {}, bullets: {}, stories: {}, self_eval: {} });
      }),
    });
    const handler = generateRoutes(opts);
    const req = { method: "POST", url: "/" };
    const res = mockRes();
    await handler(req, res, () => {});
    expect(capturedEvidence).not.toHaveProperty("_stripe_session_id");
  });
});
