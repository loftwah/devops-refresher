# 22 – Observability (OpenTelemetry + Logs)

Goal: understand and wire tracing and better logging for the demo app on EKS using OpenTelemetry and a log shipper (Vector) with a vendor backend (Tempo/Grafana Cloud, Datadog, Axiom), while keeping AWS-native as a baseline.

## Objectives

- Explain signals and standards: metrics, logs, traces; W3C Trace Context; OTLP; OpenTelemetry (SDK + Collector).
- Add tracing to the demo Node app (HTTP/Express, Postgres, Redis) via OTel auto‑instrumentation.
- Deploy an in‑cluster OTel Collector gateway that receives OTLP and exports to a backend (logging by default; vendor optional).
- Optionally deploy Vector DaemonSet to ship Kubernetes logs to Axiom (with redaction transform).
- Validate end‑to‑end by generating traffic and inspecting traces/logs.

## Concepts (What and Why)

- OpenTelemetry (OTel): language SDKs emit spans/metrics/logs; Collector receives and forwards using OTLP. Decouples app instrumentation from backend vendor.
- Trace Context: `traceparent`/`tracestate` headers propagate request IDs across services and the browser → backend.
- Collector Pipelines: receivers → processors (batch, tail sampling) → exporters (Tempo/Datadog/X‑Ray/etc.).
- Logs: prefer structured JSON; ship via agents (Vector/Fluent Bit). Redact secrets before leaving the cluster.

## Prerequisites

- EKS cluster deployed (Lab 17) and the demo app running (Lab 20).
- `kubectl` configured for the cluster.
- Optional: an account with your chosen backend (Grafana Cloud, Datadog, Axiom). AWS-native baseline works without any vendor.

## Step 1 — Deploy OTel Collector (Gateway)

Apply the provided manifests:

```
kubectl apply -f aws-labs/kubernetes/manifests/otel-collector-gateway.yml
```

This creates:

- Namespace `observability`
- ConfigMap `otel-collector-config` with a minimal OTLP traces pipeline (exporter = logging by default)
- Deployment `otel-collector` and Service `otel-collector` exposing 4317 (gRPC) and 4318 (HTTP)

Optional: Edit the ConfigMap to enable a vendor exporter (Tempo/Grafana Cloud, Datadog, X‑Ray) and add a Secret with API key if needed.

## Step 2 — App Tracing (already instrumented)

The demo app includes OTel auto-instrumentation and imports tracing at process start.

Configure environment for your Deployment/Helm values:

- `OTEL_SERVICE_NAME=demo-node-app`
- `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability:4318`
- Optional: `OTEL_EXPORTER_OTLP_HEADERS` (e.g., `Authorization=Bearer <token>`)

Helm values example (container env):

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: demo-node-app
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: http://otel-collector.observability:4318
  # - name: OTEL_EXPORTER_OTLP_HEADERS
  #   value: Authorization=Bearer <token>
```

Redeploy your app (e.g., `helm upgrade`) and generate traffic (call `/selftest` or hit endpoints).

## Step 3 — Optional: Vector → Axiom (Logs)

Create the example Secret (fill in real values before applying in production):

```
kubectl apply -f aws-labs/kubernetes/manifests/secret-axiom-example.yml
```

Deploy Vector DaemonSet:

```
kubectl apply -f aws-labs/kubernetes/manifests/vector-daemonset-axiom.yml
```

This ships container logs from all nodes to Axiom with a simple redaction transform, and also prints to stdout for verification.

## Validation (Acceptance Criteria)

- Traces
  - OTel Collector `otel-collector` logs show received spans when you hit the app.
  - If a vendor exporter is enabled, traces appear in your chosen backend with service `demo-node-app`; spans show HTTP request and DB/Redis operations.
- Logs (optional)
  - Vector pods are Running on each node.
  - Axiom dataset shows ingested logs; secrets are redacted per the transform.

## Teardown

```
kubectl delete -f aws-labs/kubernetes/manifests/vector-daemonset-axiom.yml || true
kubectl delete -f aws-labs/kubernetes/manifests/secret-axiom-example.yml || true
kubectl delete -f aws-labs/kubernetes/manifests/otel-collector-gateway.yml || true
```

## Notes & Tips

- Start with logging exporter to validate OTel wiring; then enable a backend exporter.
- Keep metrics label cardinality bounded; for traces, consider tail-based sampling at the Collector as you scale.
- Redact secrets at the edge (Vector/Fluent Bit transforms) to avoid accidental exfiltration.
- Alternative paths: AWS X‑Ray (Collector exporter), Datadog OTLP ingest, Grafana Cloud Tempo.

## References

- `docs/observability-stack.md` — overview and choices
- Manifests: `aws-labs/kubernetes/manifests/otel-collector-gateway.yml`, `vector-daemonset-axiom.yml`, `secret-axiom-example.yml`
- App config: `demo-node-app/README.md` (OpenTelemetry Tracing)
