/**
 * Shared helpers for API routes. Used by both Vite dev server and production server.ts.
 */

import type { IncomingMessage, ServerResponse } from "http";

export const DATE_YYYY_MM_DD = /^\d{4}-\d{2}-\d{2}$/;

export function readJsonBody(req: IncomingMessage): Promise<object> {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("end", () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (e) {
        reject(e);
      }
    });
  });
}

export function respondJson(res: ServerResponse, status: number, data: object): void {
  res.statusCode = status;
  res.setHeader("Content-Type", "application/json");
  res.end(JSON.stringify(data));
}

export function randomState(): string {
  return `st_${Date.now()}_${Math.random().toString(36).slice(2, 15)}`;
}
