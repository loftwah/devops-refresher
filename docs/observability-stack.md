# Observability Stack

A practical map for metrics, logs, and traces across this repo’s stacks (ECS, EKS, Terraform), including standards (OpenTelemetry), agents/shippers (Vector, Fluent Bit), and backends (Grafana/Prometheus, Datadog, Axiom, AWS-native).

## Signals & Standards

- Metrics: Time-series numbers (counters, gauges, histograms). Use labels sparingly (cardinality).
- Logs: Event records; prefer structured (JSON). Redact secrets at the edge.
- Traces: Request lifecycles across services. Spans include timing and attributes.
- Trace Context: W3C `traceparent`/`tracestate` headers for propagation across HTTP.
- OpenTelemetry (OTel): Cross-language SDKs + Collector. OTLP is the wire protocol.

## Collection Patterns

- EKS (Kubernetes):
  - Metrics: Prometheus Operator or OTel Collector with Prometheus receiver; kube-state-metrics, node-exporter.
  - Logs: Vector or Fluent Bit as a DaemonSet shipping container logs.
  - Traces: OTel Collector as DaemonSet/Deployment; apps export OTLP → Collector → backend.
- ECS (Fargate):
  - Metrics: CloudWatch Container Insights out-of-the-box; OTel sidecar optional for custom metrics.
  - Logs: FireLens (Fluent Bit/Vector) sidecar or awslogs to CloudWatch.
  - Traces: OTel sidecar or app exports OTLP to a Collector (in VPC) or vendor endpoint.

## Backends & Tooling

- Self-managed (OSS):
  - Metrics: Prometheus + Alertmanager; remote_write to long-term storage if needed.
  - Dashboards: Grafana; supports Prometheus, CloudWatch, Loki, Tempo, Jaeger.
  - Logs: Loki (via Promtail, Fluent Bit, or Vector).
  - Traces: Tempo or Jaeger; OTLP ingest via OTel Collector.
- Managed:
  - AWS-native: CloudWatch Logs/Metrics/Alarms + X-Ray for traces.
  - Grafana Cloud: Hosted Prometheus/Loki/Tempo + Grafana.
  - Datadog: Unified metrics/logs/traces; supports OTel and native agents.
  - Axiom: Managed logs/analytics; ingest via Vector/HTTP; supports OTel pipelines.

## Vector & Axiom (Logs)

- Vector placement: DaemonSet on EKS; FireLens/sidecar on ECS; or EC2/systemd for host logs.
- Transforms: Parse JSON, drop noise, redact PII, derive fields.
- Outputs: Axiom (HTTP), S3 (backup), CloudWatch (operational), or other sinks.
- Reliability: Use buffers and backpressure; size carefully to avoid memory spikes.

## Tracing (Backend and Frontend)

- Microservices backend:
  - Instrument services with OTel SDKs (Node, Go, Python, etc.).
  - Propagate trace context via HTTP headers (`traceparent`, `tracestate`).
  - Export OTLP to a local OTel Collector; Collector exports to vendor/backend.
  - Correlate: Include `trace_id`/`span_id` in logs to link logs↔traces.
- Web applications:
  - Use OTel JS SDK in the browser to create client-side spans (page load, XHR/fetch).
  - The browser DevTools network tab shows similar timing waterfall, but vendor tracing systems persist and correlate spans across services.
  - Ensure the browser forwards `traceparent` so the backend spans join the same trace.

## Minimal, Repo-Ready Options

- Stay AWS-native (current labs): CloudWatch Logs + Metrics + Alarms; X-Ray optional.
- Add traces with minimal change:
  - Run an OTel Collector (EKS Deployment or small EC2) as an OTLP gateway.
  - Instrument the demo app with OTel SDK; export OTLP → Collector → backend (Grafana Cloud/Tempo, Datadog, or X-Ray via Collector exporter).
- Improve logs:
  - Add Vector as a shipper with redaction/filters; send to Axiom for search/retention and optionally to S3 for archive.

## Design Tips

- Labels/cardinality: Keep metrics label sets bounded; avoid unbounded user IDs.
- Sampling: Use tail-based sampling at the Collector for traces to keep costs sane.
- Privacy: Redact tokens/passwords early (Vector/Fluent Bit transforms).
- SLOs: Define SLIs (latency, error rate) and SLOs; alert on symptoms, not causes.
- Dashboards: Start with “Golden Signals” per service; add drill-down links to logs/traces.

## Next Steps (if we want this here)

- Add OTel Collector manifests under `aws-labs/kubernetes/manifests/`:
  - `otel-collector-gateway.yml` (Namespace, ConfigMap, Deployment, Service)
- Add Vector DaemonSet for EKS:
  - `vector-daemonset-axiom.yml` (Namespace, ConfigMap, DaemonSet)
  - `secret-axiom-example.yml` (template; create a real Secret with your token)
- Instrument the demo Node app with OTel SDK (already added):
  - `demo-node-app/src/tracing.ts` and import at top of `src/server.ts`
  - Configure env: `OTEL_SERVICE_NAME=demo-node-app`, `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability:4318`
- Choose a backend (Grafana Cloud, Datadog, Axiom+Tempo, or X-Ray) and wire exporters in the Collector config.
