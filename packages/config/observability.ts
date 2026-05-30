// Sentry & OpenTelemetry configuration for Observability
import * as Sentry from '@sentry/nextjs';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

// 1. Sentry Configuration (Error Tracking & Crash Reports)
Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  tracesSampleRate: 1.0,
  profilesSampleRate: 1.0,
  environment: process.env.NODE_ENV || 'development',
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration({
      maskAllText: true,
      blockAllMedia: true,
    }),
  ],
});

// 2. OpenTelemetry Configuration (Distributed Tracing for Performance KPIs)
const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTLP_ENDPOINT,
  }),
  instrumentations: [], // Auto-instruments HTTP, Express, PostgreSQL, etc.
});

sdk.start();

// Exporting KPIs monitoring utility
export const monitorKPI = (metricName: string, executionTimeMs: number) => {
  // Enforce Production KPIs
  if (metricName === 'POS_SEARCH' && executionTimeMs > 100) {
    Sentry.captureMessage(`KPI Breach: POS Search took ${executionTimeMs}ms (Limit: 100ms)`, 'warning');
  }
  if (metricName === 'CHECKOUT' && executionTimeMs > 500) {
    Sentry.captureMessage(`KPI Breach: Checkout took ${executionTimeMs}ms (Limit: 500ms)`, 'warning');
  }
  if (metricName === 'KDS_DELIVERY' && executionTimeMs > 1000) {
    Sentry.captureMessage(`KPI Breach: KDS Delivery took ${executionTimeMs}ms (Limit: 1s)`, 'warning');
  }
  if (metricName === 'AI_RESPONSE' && executionTimeMs > 5000) {
    Sentry.captureMessage(`KPI Breach: AI Response took ${executionTimeMs}ms (Limit: 5s)`, 'warning');
  }
};
