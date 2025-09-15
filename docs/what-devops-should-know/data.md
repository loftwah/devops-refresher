# What a Senior DevOps Engineer Should Know About Data

## Assumptions

- Primary cloud is AWS in ap-southeast-2.
- Tooling commonly used: GitHub, GitHub Actions, Terraform, Docker, ECS or EKS, S3, RDS, ElastiCache, CloudWatch, CloudTrail, GuardDuty, IAM, KMS, Cloudflare for edge.
- Audience is a Senior DevOps Engineer who partners with data engineering but is not a full-time data engineer.

---

## 1. Why data matters to DevOps

Data is not only business analytics. It is how systems behave, scale and fail. DevOps sits at the intersection of reliability, security, cost and velocity.

- **Reliability:** Broken pipelines lead to stale dashboards, incorrect ML features and user-visible issues. Treat pipelines as production systems with SLOs, error budgets and incident runbooks.
- **Observability:** Logs, metrics and traces are data. Telemetry pipelines need the same reliability patterns as product data pipelines.
- **Scalability:** Data volume and cardinality grow nonlinearly. Architect for partitioning, backpressure and horizontal scale.
- **Security and compliance:** PII, PHI and financial data require encryption, fine-grained access, auditing and retention policies.
- **Cost:** Storage and query engines can silently balloon costs. Storage tiering, columnar formats and partition pruning are key.
- **Velocity:** Good platform abstractions and IaC enable rapid, safe iteration for data engineers and analysts.

---

## 2. Core data concepts a DevOps engineer should know

- **OLTP vs OLAP:** OLTP for transactions and user serving. OLAP for analytics and reporting. Keep them separated via replication or CDC.
- **Batch vs streaming:** Batch processes fixed windows on a schedule. Streaming processes continuous events with windowing and late data handling.
- **Schema-on-write vs schema-on-read:** Warehouses enforce schema at load time. Lakes apply schema when queried. Lakehouse adds table formats with ACID properties.
- **Idempotency:** All pipeline steps should be safely re-runnable. Use deterministic file paths, upsert strategies and idempotent sinks.
- **Delivery semantics:** At least once is common. Exactly once is hard and usually an end-to-end property combining idempotent sinks, dedup keys and transactional writes.
- **Data quality:** Define freshness, completeness, accuracy and distribution checks. Automate and page on breaches where business critical.
- **File formats:** Prefer columnar formats such as Parquet or ORC for analytics. Use gzip or zstd compression where supported.
- **Partitioning:** Partition on time or high-selectivity keys. Avoid over-partitioning that creates many small files.

---

## 3. ETL vs ELT

### 3.1 ETL

**Extract, Transform, Load.**

- Extract from sources such as RDS, Postgres, MySQL, REST, event topics.
- Transform outside the destination using a separate compute engine.
- Load the shaped data into a warehouse.

**Use ETL when:**

- Transformations are heavy, privacy-bearing, or must be controlled before storage.
- The destination has limited compute or strict schema constraints.
- You must guarantee only curated data lands in the warehouse.

**Trade-offs:**

- Pros: Strong governance before data lands, predictable shape on arrival.
- Cons: More complex infrastructure and potential double compute.

### 3.2 ELT

**Extract, Load, Transform.**

- Extract and load raw data into a scalable destination first.
- Transform inside the warehouse or lake using its compute.

**Use ELT when:**

- You use modern warehouses such as BigQuery, Snowflake or Redshift RA3.
- You want to retain raw history for reprocessing.
- Teams prefer SQL-first modelling with versioned transformations.

**Trade-offs:**

- Pros: Flexible, audit-friendly, simpler ingestion, leverages warehouse elasticity.
- Cons: Requires rigorous governance to avoid a swamp of raw tables and ad hoc logic.

### 3.3 Choosing ETL or ELT

- Privacy or contractual constraints before storage: ETL.
- Need raw retention and fast iteration: ELT.
- Lakehouse with Iceberg or Delta tables: often ELT with table-format transactions.
- Mixed approach is common: EL for ingestion, and T in both places depending on sensitivity.

---

## 4. Data pipelines

Pipelines are production software. Treat them with SRE discipline.

**Orchestration**

- Airflow, Prefect or AWS Step Functions for DAGs, retries, backoff and timeouts.
- Use task queues with concurrency limits to protect downstream systems.

**Movement and compute**

- Batch: Glue, EMR, Spark, Ray or database-native SQL.
- Streaming: Kafka, Kinesis, MSK, Flink, Beam.
- CDC: Debezium, DMS or native database logical replication.

**Reliability patterns**

- Exactly-once approximation: stable dedup keys, upsert sinks, transactional tables.
- Dead-letter queues for poison messages.
- Backpressure and scaling with partitions and consumer groups.
- Idempotent file naming such as s3://bucket/raw/source=foo/ingest_date=YYYY=MM=DD/run_id=UUID.

**Testing and CI/CD**

- Unit test transforms with fixtures.
- Data tests for not null, uniqueness, referential integrity and distribution checks.
- Contract tests for schemas at integration boundaries.
- Promotion pipelines for staging to production with data diff gates.

**Observability**

- Emit metrics for throughput, lag, error rate and data freshness.
- Track lineage for impact analysis and compliance.
- Store operational metadata such as run_id, source offsets and counts.

---

## 5. Data warehouses

Warehouses serve analytics on structured data.

**Common options**

- Amazon Redshift RA3 with managed storage.
- Google BigQuery.
- Snowflake.

**Key concepts**

- Concurrency and workload management: queues, slots or virtual warehouses.
- Pruning and clustering to reduce scanned bytes.
- Materialised views for precomputation and predictable performance.
- Time travel and snapshots for recovery.

**Security**

- Column and row level security.
- Dynamic data masking for PII.
- Encryption at rest and in transit, keys in KMS or cloud-native key services.
- Fine-grained IAM and query audit logs.

**Cost management**

- Prefer columnar formats and partition pruning.
- Use result caching, materialised views and workload separation.
- Scale compute only when jobs run, shut it down aggressively when idle.
- Track cost per team via tags and views.

---

## 6. Data lakes

A lake keeps raw, semi-structured and unstructured data.

**On AWS**

- S3 with versioning for immutability and rollbacks.
- Glue Data Catalog for metadata.
- Lake Formation for permissions and governance.
- Athena or Trino for serverless querying.

**Layout**

- Zones: raw, staged, curated and sandbox.
- Partition by event date or load date.
- Use Parquet with snappy or zstd compression.

**Governance**

- S3 bucket policies with least privilege.
- SSE-KMS for encryption, restrict kms\:Decrypt to roles.
- Lifecycle to Glacier for cold data and delete after retention.
- Object Lock where immutability is required.

---

## 7. Lakehouse patterns

Add table formats that bring ACID and schema evolution to the lake.

- **Apache Iceberg, Delta Lake, Apache Hudi** provide transactional tables, upserts, time travel and compaction.
- Benefits: warehouse-like management on cheap object storage.
- Considerations: choose engines with first-class support, plan compaction and metadata scaling.

---

## 8. Streaming data

Real-time pipelines power features, monitoring and near real-time analytics.

**Concepts**

- Topics, partitions, retention and consumer groups.
- Ordering within a partition. Key selection matters.
- Windowing and watermarking for late data.

**Design**

- Keep producers thin and resilient.
- Define schemas with Avro or Protobuf and enforce via a schema registry.
- Use DLQs, replay tools and offset checkpoints.

**Common patterns**

- Log enrichment and fan-out.
- Real-time CDC from OLTP to analytics.
- Near real-time materialised views updated by stream processors.

---

## 9. Security, privacy and compliance

Treat data security as a first-class requirement.

- **Classification:** Tag data domains such as public, internal, confidential, restricted. Store tags in the catalog.
- **Encryption:** TLS in transit, SSE-KMS or client-side at rest. Rotate keys and use grants with least privilege.
- **Access control:** IAM roles bound to groups, not humans. JIT access with short-lived credentials. Avoid static credentials.
- **Masking and tokenisation:** Apply at query time or with transform jobs for PII.
- **Auditing:** CloudTrail, Lake Formation logs, warehouse query logs. Send to a central immutable log store.
- **Retention:** Define per-domain retention and implement with lifecycle policies and table TTLs.

---

## 10. Reliability and SRE for data

Define SLOs that reflect business use.

- **Freshness SLO:** Example 99.5 percent of daily fact tables complete by 06:00 local time.
- **Completeness SLO:** Example 99.9 percent of events delivered within 24 hours.
- **Correctness SLO:** Data tests pass at 99.9 percent, deviations trigger rollback.

**Runbooks**

- Common failure modes: source schema drift, credential expiry, quota throttling, skew and hot partitions, small files.
- Remediation: pause consumers, compact files, backfill with idempotent runs, rebuild models, rotate keys.

---

## 11. Cost management

- Prefer columnar formats and partition pruning to reduce scanned bytes.
- Compact small files to target sizes such as 256 MB to 1 GB.
- Right-size compute and schedule windows to benefit from spot or autoscaling.
- Use storage lifecycle to move old data to Glacier Instant Retrieval, then to Glacier Flexible Retrieval if acceptable.
- Attribute costs with tags and Curated Cost and Usage Reports. Alert on anomalies.

---

## 12. Reference architectures in AWS ap-southeast-2

### 12.1 Batch ELT to Redshift and S3

- Sources: RDS Postgres, application logs in S3.
- Ingestion: AWS DMS or custom extractors on ECS to S3 raw zone as Parquet partitioned by ingest_date.
- Transform: dbt running in GitHub Actions or on ECS against Redshift. Models generate curated schemas.
- Query: BI tools or Athena for ad hoc exploration of raw.
- Governance: Lake Formation sharing, IAM role based access, KMS keys per domain.

### 12.2 Streaming CDC to Snowflake

- Sources: RDS MySQL and Postgres with Debezium on MSK.
- Transport: Kafka topics with Avro schemas validated by Schema Registry.
- Load: Snowpipe streams ingest topics to staging tables.
- Transform: dbt in Snowflake applying SCD Type 2 for dimensions and incremental facts.
- Observability: Topic lag, DLQ counts and freshness metrics in CloudWatch and Grafana.

### 12.3 Lakehouse with Iceberg on S3

- Compute: EMR or Glue with Spark, Trino for ad hoc.
- Storage: S3 buckets per domain, Iceberg tables with partition evolution.
- Governance: Lake Formation grants on tables and columns.
- Benefits: ACID and time travel without proprietary warehouse lock-in.

---

## 13. Practical step-by-step: minimal ELT on AWS with S3, Athena, Glue and dbt

**Goal:** Land raw data in S3, model it with dbt and query with Athena.

1. **Create S3 buckets**
   - s3://org-data-raw-ap-southeast-2
   - s3://org-data-curated-ap-southeast-2

2. **Enable versioning**
   - Use versioning and Object Lock if immutable retention is required.

3. **Set bucket policies and encryption**
   - SSE-KMS with a CMK limited to pipeline roles.
   - Deny unencrypted puts and public access.

4. **Glue Data Catalog**
   - Create databases raw and curated.
   - Define crawlers to infer schemas for raw Parquet partitions.

5. **Ingest raw**
   - Drop Parquet into s3://org-data-raw-ap-southeast-2/source=app/ingest_date=YYYY=MM=DD/.

6. **dbt project**
   - Profiles target Athena via the Athena driver.
   - Models read from raw database and write to curated as Iceberg or Parquet-backed tables.

7. **Quality checks**
   - Add tests for not_null, unique and accepted_values.
   - Fail build if critical tests fail.

8. **Schedule**
   - Orchestrate with GitHub Actions on cron at 05:00 Australia/Melbourne or Step Functions for richer control.

9. **Access**
   - Analysts query curated tables with Athena. Enforce row and column grants with Lake Formation.

---

## 14. Example snippets

### 14.1 S3 bucket policy hardening (Terraform)

```hcl
resource "aws_s3_bucket" "raw" {
  bucket = "org-data-raw-ap-southeast-2"
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data_key.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "deny_unencrypted" {
  bucket = aws_s3_bucket.raw.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "DenyUnEncryptedInTransit",
        Effect   = "Deny",
        Principal= "*",
        Action   = "s3:*",
        Resource = [
          "${aws_s3_bucket.raw.arn}",
          "${aws_s3_bucket.raw.arn}/*"
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
```

### 14.2 dbt model with data tests

`models/customers.sql`

```sql
{{ config(materialized='incremental', unique_key='customer_id') }}

with src as (
  select
    cast(customer_id as bigint) as customer_id,
    lower(email) as email,
    created_at::timestamp as created_at
  from raw.app_customers
  {% if is_incremental() %}
    where created_at > (select coalesce(max(created_at), '1970-01-01') from {{ this }})
  {% endif %}
)

select * from src;
```

`models/customers.yml`

```yaml
version: 2
models:
  - name: customers
    tests:
      - not_null:
          column_name: customer_id
      - unique:
          column_name: customer_id
      - relationships:
          to: ref('orders')
          field: customer_id
```

### 14.3 Kafka topic with DLQ pattern

```text
Topics:
  orders.v1                - primary event stream
  orders.v1.dlq            - events that failed validation or processing
Schema:
  Protobuf with versioning, enforced via Schema Registry

Consumer:
  - At least once processing
  - Validate schema and business rules
  - On failure, write to orders.v1.dlq with error reason and original payload
```

---

## 15. Operational checklist

- Access and security
  - IAM roles with least privilege. No long-lived keys.
  - SSE-KMS for all storage. Rotate keys.

- Reliability
  - Retries with exponential backoff and jitter.
  - DLQs for streaming and batch fallbacks.
  - Idempotent writes and deterministic paths.

- Observability
  - Metrics for throughput, lag, error rates and freshness.
  - Logs with structured fields and correlation ids.
  - Lineage for tables and models.

- Cost
  - Partition pruning and file compaction.
  - Autoscaling compute and shut down idle clusters.
  - Lifecycle policies to Glacier and deletions after retention.

- Change management
  - IaC for all data infra. Code reviews mandatory.
  - CI with data tests and schema contract checks.
  - Feature flags for risky transforms and backfill tooling.

- Compliance
  - Data classification tags.
  - Masking for PII, audit logs centralised and immutable.
  - Documented retention by domain.

---

## 16. Common pitfalls and how to avoid them

- Small files problem on S3: implement compaction jobs.
- Hot partitions: choose keys with even distribution, evolve partitions if required.
- Schema drift from sources: contract tests and automated pull request checks.
- Unbounded costs: alert on scanned bytes and job duration, enforce budgets.
- One-off analyst logic in production: require dbt models or approved jobs, not ad hoc queries.
- Over-indexing on exactly once: aim for idempotency and deduplication, reserve transactional guarantees where critical.

---

## 17. Glossary

- **CDC:** Change data capture. Stream changes from OLTP to analytics.
- **DLQ:** Dead-letter queue. Holding area for failed messages or records.
- **Iceberg, Delta, Hudi:** Table formats that add transactions and schema evolution to lakes.
- **Partition pruning:** Skipping irrelevant file partitions during queries.
- **SCD Type 2:** Pattern to track slowly changing dimensions by versioning rows.

---

## Sources and credibility rating

- AWS Analytics and Big Data whitepapers and service docs. Credibility: High.
- Google BigQuery documentation. Credibility: High.
- Snowflake documentation. Credibility: High.
- Apache Kafka and Confluent documentation. Credibility: High.
- dbt documentation and best practices. Credibility: High.
- Apache Iceberg and Delta Lake documentation. Credibility: High.
- Martin Fowler articles on data pipelines and CDC. Credibility: High.
