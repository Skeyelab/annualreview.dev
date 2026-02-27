/**
 * PostHog Node.js logs (OpenTelemetry OTLP). Optional: set POSTHOG_API_KEY (and POSTHOG_HOST) to send logs to PostHog.
 * @see https://posthog.com/docs/logs/installation/nodejs
 */

import { NodeSDK } from "@opentelemetry/sdk-node";
import { OTLPLogExporter } from "@opentelemetry/exporter-logs-otlp-http";
import { BatchLogRecordProcessor } from "@opentelemetry/sdk-logs";
import { resourceFromAttributes } from "@opentelemetry/resources";
import { logs, type Logger } from "@opentelemetry/api-logs";

const token = process.env.POSTHOG_API_KEY;
const host = process.env.POSTHOG_HOST || "https://us.i.posthog.com";
const logsUrl = `${host.replace(/\/$/, "")}/i/v1/logs`;

let sdk: NodeSDK | null = null;

if (token?.startsWith("phc_")) {
  sdk = new NodeSDK({
    resource: resourceFromAttributes({
      "service.name": "annualreview-server",
    }),
    logRecordProcessors: [
      new BatchLogRecordProcessor(
        new OTLPLogExporter({
          url: logsUrl,
          headers: { Authorization: `Bearer ${token}` },
        })
      ),
    ],
  });
  sdk.start();
}

const noopLogger: Logger = {
  emit: (_logRecord: Parameters<Logger["emit"]>[0]) => {},
};

/** Logger that emits to PostHog when POSTHOG_API_KEY is set; otherwise no-op. */
export const logger: Logger = sdk ? logs.getLogger("annualreview-server") : noopLogger;

/** Call before process exit to flush batched logs (e.g. in server shutdown). */
export async function shutdownPostHogLogs(): Promise<void> {
  if (sdk) await sdk.shutdown();
}
