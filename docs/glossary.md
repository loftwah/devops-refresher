# Repository Glossary (A–Z)

An extensive, practical glossary tailored to this repository: AWS labs, Terraform, Kubernetes, CI/CD, the demo Node app, networking labs, and interview materials. Acronyms come first; repo-specific terms and domain glossaries follow.

Tip: Use your editor’s search to jump to a term (e.g., "RDS", "KMS", "canary").

---

## Repo Map (Where Things Live)

- AWS Labs: `aws-labs/` — numbered labs 00–21; validators in `aws-labs/scripts/`
- Kubernetes: `aws-labs/kubernetes/helm/` and `aws-labs/kubernetes/manifests/`
- Demo App: `demo-node-app/` — TypeScript API, `Dockerfile`, `buildspec.yml`
- Docs: `docs/` — references, runbooks, decisions (ADR), walkthroughs
- Decisions: `docs/decisions/` — ADR-000..007
- Runbooks: `docs/runbooks/` — rotation, permissions, imports
- Interview: `interview/` — behavioural (STAR/SOAR), system design, coding
- Networking Labs: `networking-labs/packet-tracer-campus/` — Cisco configs

## Acronyms (A–Z)

- 2FA: Two-Factor Authentication — Auth requiring two distinct factors.
- 3DES: Triple Data Encryption Standard — Legacy symmetric cipher.
- 4xx/5xx: Client/Server HTTP error classes — 4xx client, 5xx server.
- AAD: Azure Active Directory — Microsoft identity platform (now Entra ID).
- ABAC: Attribute-Based Access Control — Access by attributes/claims.
- ABI: Application Binary Interface — Low-level interface contract for binaries.
- ABR: Average Bitrate — Encoding/streaming measure; variable bitrate average.
- ACL: Access Control List — Per-object allow/deny rules.
- ACM: AWS Certificate Manager — Manages TLS certs on AWS.
- ACID: Atomicity, Consistency, Isolation, Durability — Transaction properties.
- ACK: Acknowledgement — Signal of receipt in protocols like TCP.
- ADC: Application Delivery Controller — Load balancing/acceleration device.
- ADR: Architecture Decision Record — Lightweight decision log artifact.
- AES: Advanced Encryption Standard — Modern symmetric cipher (AES-128/256).
- AIDE: Advanced Intrusion Detection Environment — File integrity checker.
- AKS: Azure Kubernetes Service — Managed Kubernetes on Azure.
- ALB: Application Load Balancer — L7 load balancer on AWS.
- AMI: Amazon Machine Image — EC2 instance image template.
- AMQP: Advanced Message Queuing Protocol — Messaging protocol.
- ANSI: American National Standards Institute — Standards body.
- APM: Application Performance Monitoring — Tracing, metrics, profiling of apps.
- API: Application Programming Interface — Contract for programmatic interaction.
- APIGW: API Gateway — Managed API front door (e.g., AWS API Gateway).
- ARP: Address Resolution Protocol — Maps IP to MAC on LAN.
- ASG: Auto Scaling Group — EC2 instance scaling group on AWS.
- ASP: Application Security Posture — Overall security state of applications.
- ASR: Automatic Speech Recognition — Speech-to-text (infra considerations).
- ATC: Access Token — OAuth/JWT token used to access APIs.
- ATH: Amazon Athena — Serverless SQL over S3.
- ATL: Acceptable Tolerance Level — Ops threshold for error/latency.
- ATLASSIAN: Vendor (Jira, Confluence, Bitbucket) — Not an acronym but common.
- AUFS: Another Union File System — Legacy Docker storage driver.
- AUR: Arch User Repository — Community repo for Arch Linux packages.
- AURORA: Amazon Aurora — MySQL/Postgres compatible managed DB on AWS.
- AV: Anti-Virus — Malware detection software.
- AWS: Amazon Web Services — Cloud provider.
- AZ: Availability Zone — Isolated DC within a region (AWS/Azure).
- BaaS: Backend as a Service — Managed backend services.
- BBR: Bottleneck Bandwidth and RTT — TCP congestion control algorithm.
- BCP: Business Continuity Plan — Keeping business running during disruption.
- BCR: Business Change Request — Change management artifact.
- BDD: Behavior-Driven Development — Collaborative testing approach.
- BE: Back End — Server-side components/services.
- BGP: Border Gateway Protocol — Internet routing protocol.
- BI: Business Intelligence — Analytics and reporting.
- BIOS: Basic Input/Output System — Firmware initialization.
- BMR: Bare-Metal Restore — Restore OS/app onto bare hardware.
- BOM: Bill of Materials — Dependency/component list (e.g., CycloneDX, SPDX).
- BPMN: Business Process Model and Notation — Workflow notation.
- BPF/eBPF: Extended Berkeley Packet Filter — In-kernel programmable hooks.
- BSS: Basic Service Set — Wi‑Fi cell; networking term.
- CAC: Change Advisory Committee — ITIL change governance board.
- CA: Certificate Authority — Issues and signs certificates.
- CAP: Consistency, Availability, Partition tolerance — Distributed systems tradeoff.
- CAR: Corrective Action Request — Quality or process remediation.
- CAS: Compare And Swap — Atomic operation in concurrency.
- CASB: Cloud Access Security Broker — Security posture between users and cloud.
- CCB: Change Control Board — Change governance body.
- CCD: Continuous Compliance/Continuous Control Deployment — Automating compliance.
- CDN: Content Delivery Network — Edge caching network.
- CD: Continuous Delivery/Deployment — Frequent, automated releases.
- CDK: Cloud Development Kit — IaC via general-purpose languages.
- CDP: CodeDeploy — AWS deployment orchestrator (used by some pipelines).
- CEE: Customer Engineering Experience — Internal/customer support quality.
- CEF: Common Event Format — Log event schema.
- CEP: Complex Event Processing — Real-time event aggregation/computation.
- CERT: Computer Emergency Response Team — Incident response organization.
- CFR: Code Freeze — Temporary stop on new changes.
- CF: CloudFormation — AWS IaC service.
- CFN: CloudFormation — Alternate abbreviation commonly used.
- CFS: Config File System — Filesystem-based configuration patterns.
- CIDR: Classless Inter-Domain Routing — IP addressing notation (e.g., 10.0.0.0/16).
- CI: Continuous Integration — Frequent merges + automated tests.
- CICD: Continuous Integration and Continuous Delivery/Deployment — Shorthand for CI/CD.
- CICS: Customer Information Control System — Mainframe transaction server.
- CIS: Center for Internet Security — Benchmarks/best practices.
- CISO: Chief Information Security Officer — Security leadership role.
- CKMS: Cryptographic Key Management System — Key lifecycle management.
- CLI: Command-Line Interface — Terminal-driven interface.
- CLOB: Character Large Object — Database large text field.
- CNAME: Canonical Name — DNS alias record.
- CNCF: Cloud Native Computing Foundation — Open source foundation (K8s, etc.).
- CNI: Container Network Interface — Plugin interface for container networking.
- COBOL: Common Business-Oriented Language — Legacy language (infra migration).
- COI: Container-Optimized Image — OS image tuned for containers.
- CPU: Central Processing Unit — Compute resource.
- CR: Change Request/Code Review — Change artifact or review.
- CRD: Custom Resource Definition — Kubernetes custom extension type.
- CRM: Customer Relationship Management — Tooling (e.g., Salesforce).
- CRL: Certificate Revocation List — Revoked certificates list.
- CRT: Certificate file — X.509 certificate storage.
- CRYPTO: Cryptography — Security domain; not an acronym but frequent.
- CS: Computer Science/Customer Support — Context dependent.
- CSA: Cloud Security Alliance — Security best practices org.
- CSE: Customer Support Engineer — Support-focused engineer role.
- CSI: Container Storage Interface — Kubernetes storage plugin interface.
- CSIRT: Computer Security Incident Response Team — Incident responders.
- CSP: Content Security Policy — Browser security header.
- CSR: Certificate Signing Request — Request for a new cert.
- CSRF: Cross-Site Request Forgery — Web attack class.
- CSV: Comma-Separated Values — Simple tabular data format.
- CT: Certificate Transparency — Public logs of issued certs.
- CTO: Chief Technology Officer — Tech leadership role.
- CTR: Counter mode — Block cipher operation mode (AES-CTR).
- CVE: Common Vulnerabilities and Exposures — Public vulnerability IDs.
- CVSS: Common Vulnerability Scoring System — Severity scoring for CVEs.
- CWE: Common Weakness Enumeration — Software weakness taxonomy.
- DAC: Discretionary Access Control — Access by owner discretion.
- DAG: Directed Acyclic Graph — Pipeline/task graph structure.
- DB: Database — Structured data store.
- DDoS: Distributed Denial of Service — Flooding attack.
- DDB: DynamoDB — NoSQL DB used here for legacy TF state locking (<=1.9).
- DDP: Data Distribution Platform — Data sharing infra.
- DDR: Disaster Detection and Response — Early detection + response.
- DLP: Data Loss Prevention — Prevent exfiltration/leakage.
- DMS: Database Migration Service — AWS DMS for migration/replication.
- DNS: Domain Name System — Maps names to IPs.
- DoH: DNS over HTTPS — Encrypted DNS queries.
- DoS: Denial of Service — Service degradation attack.
- DORA: DevOps Research and Assessment — Four key metrics (LT, DF, CFR, MTTR).
- DPA: Data Processing Agreement — Legal contract for data processing.
- DPI: Deep Packet Inspection — Inspect packet payloads.
- DPIA: Data Protection Impact Assessment — GDPR risk assessment.
- DR: Disaster Recovery — Restore service after disaster.
- DRBD: Distributed Replicated Block Device — Block-level replication.
- DRF: Django REST Framework — Not DevOps-specific but common.
- DRIFT: Config Drift — Deviation from desired state.
- DRM: Digital Rights Management — Content protection.
- DRY: Don’t Repeat Yourself — Engineering principle.
- DS: Data Science — Analytics/ML discipline.
- DSC: Desired State Configuration — Windows config management.
- DSL: Domain-Specific Language — Purpose-built language (e.g., HCL).
- DSS: Decision Support System — Analytics system.
- DTLS: Datagram TLS — TLS over UDP.
- DTR: Docker Trusted Registry — On-prem Docker registry.
- DVCS: Distributed Version Control System — E.g., Git.
- DWH: Data Warehouse — Analytical data store.
- E2E: End to End — Test or flow across systems.
- EBS: Elastic Block Store — AWS block storage for EC2.
- EC2: Elastic Compute Cloud — AWS virtual machines.
- ECC: Elliptic-Curve Cryptography — Public-key cryptography type.
- ECR: Elastic Container Registry — AWS container image registry.
- ECS: Elastic Container Service — AWS container orchestrator.
- ECS Exec: Encrypted interactive shell into ECS containers via SSM.
- EDR: Endpoint Detection & Response — Endpoint security telemetry.
- EFA: Elastic Fabric Adapter — High performance network for EC2.
- EFS: Elastic File System — AWS managed NFS.
- EIP: Elastic IP — Static public IPv4 on AWS.
- EKMS: Enterprise Key Management System — Org-wide key management.
- EKS: Elastic Kubernetes Service — Managed Kubernetes on AWS.
- ELB: Elastic Load Balancing — Family of AWS load balancers.
- ELB Controller/LBC: AWS Load Balancer Controller — Provisions ALBs/NLBs for K8s.
- ELK: Elasticsearch, Logstash, Kibana — Logging/analytics stack.
- ELT: Extract, Load, Transform — Data pipeline model.
- ELV: Elastic Logging Vector — Not a standard acronym; Vector is a log shipper.
- OTLP: OpenTelemetry Protocol — Wire protocol for metrics/logs/traces.
- OTel: OpenTelemetry — Vendor-neutral telemetry framework (SDKs + Collector).
- Jaeger: Distributed tracing system (OSS); supports OTLP via Collector.
- Tempo: Grafana’s distributed tracing backend (OSS/hosted); OTLP via Collector.
- Loki: Grafana’s log store (OSS/hosted); integrates with Promtail/Vector.
- Prom: Prometheus — Metrics store and scraper; Alertmanager for alerts.
- Grafana: Visualization/dashboards for metrics/logs/traces.
- Datadog: Managed observability (metrics/logs/traces); supports OTel.
- Axiom: Managed logs/analytics; integrates with Vector/OTel.
- Vector: High-performance log/metrics shipper; agent with transforms.
- ELT: Extract, Load, Transform — Data pipeline model.
- EMR: Elastic MapReduce — AWS managed Hadoop/Spark.
- Envoy: Service proxy — Common sidecar/data-plane (not acronym).
- EOF: End of File — File terminator.
- EOL: End of Life — No longer supported.
- EPP: Event Processing Pipeline — Streaming/analytics pipeline.
- EPS: Events Per Second — Throughput metric.
- ESK: External Secrets Kubernetes — External secrets operator.
- ESO: External Secrets Operator — Sync secrets from SM/SSM to K8s.
- ETAG: Entity Tag — HTTP cache validation ID.
- etcd: Distributed KV store for K8s — Not acronym but key.
- ETL: Extract, Transform, Load — Data pipeline model.
- EULA: End-User License Agreement — Software license for end users.
- FaaS: Functions as a Service — Serverless functions.
- FACL: File ACL — Filesystem-level permissions list.
- FIM: File Integrity Monitoring — Detect unauthorized changes.
- FIFO: First In, First Out — Queue ordering.
- FIPS: Federal Information Processing Standards — Crypto/security standards.
- FIPS-140: Security requirements for cryptographic modules — Certification.
- FQDN: Fully Qualified Domain Name — Absolute DNS name.
- FUSE: Filesystem in Userspace — User-space filesystem framework.
- GA: General Availability — Production-grade release.
- GAE: Google App Engine — Managed app platform.
- GCE: Google Compute Engine — VMs on GCP.
- GCR: Google Container Registry — Container registry on GCP.
- GCS: Google Cloud Storage — Object storage on GCP.
- GDP: Guaranteed Delivery Protocol — Messaging guarantee concept.
- GDPR: General Data Protection Regulation — EU data privacy law.
- GHA: GitHub Actions — CI/CD platform.
- GHES: GitHub Enterprise Server — Self-hosted GitHub.
- GHCR: GitHub Container Registry — Container registry under ghcr.io.
- GIN: Go web framework — Common in platform services.
- GKE: Google Kubernetes Engine — Managed Kubernetes on GCP.
- GPG: GNU Privacy Guard — OpenPGP implementation.
- GPU: Graphics Processing Unit — Accelerator hardware.
- gRPC: gRPC Remote Procedure Calls — High-performance RPC framework.
- HA: High Availability — Minimize downtime via redundancy.
- HADR: High Availability & Disaster Recovery — HA + DR strategy.
- HAR: HTTP Archive — Web performance capture format.
- HBA: Host-Based Authentication — DB auth model (e.g., PostgreSQL).
- HCL: HashiCorp Configuration Language — Terraform language.
- HDFS: Hadoop Distributed File System — Big data storage.
- HMAC: Hash-based Message Authentication Code — Authenticated hashing.
- HPA: Horizontal Pod Autoscaler — K8s scaling controller.
- HSM: Hardware Security Module — Physical key storage device.
- HTTP/2/3: HTTP versions — Multiplexed/binary (2) and QUIC-based (3).
- IAM: Identity and Access Management — Users, roles, policies.
- IaC: Infrastructure as Code — Declarative provisioning (e.g., Terraform).
- ICMP: Internet Control Message Protocol — Ping, traceroute.
- IOPS: I/O Operations Per Second — Storage perf metric.
- IDS/IPS: Intrusion Detection/Prevention System — Threat detection/mitigation.
- IdP: Identity Provider — Issues/validates identities (e.g., Okta, AAD).
- IETF: Internet Engineering Task Force — Internet standards body.
- IGW: Internet Gateway — VPC edge to the internet.
- IKE: Internet Key Exchange — IPsec key management.
- IMDS: Instance Metadata Service — EC2 instance metadata endpoint.
- IMDSv2: Session-oriented IMDS — Mitigates SSRF risks.
- IMDSv1: Legacy IMDS — Simpler, vulnerable to SSRF.
- IMDS hop limit: TTL for IMDS — Prevent container escape to IMDS.
- IMDS endpoint: 169.254.169.254 — Link-local address for IMDS.
- IMDS token: IMDSv2 session token — Required for requests in v2.
- IMDS creds: Temporary credentials via IMDS — For EC2 roles.
- IMMU: Immutable Infrastructure — Rebuild instead of mutate in-place.
- INODE: Index Node — Filesystem metadata entry.
- IoT: Internet of Things — Connected devices at the edge.
- IP: Internet Protocol — Network layer addressing/routing.
- IPSec: Internet Protocol Security — Network encryption/auth.
- IR: Incident Response — Process to handle incidents.
- IRSA: IAM Roles for Service Accounts — Fine-grained IAM for K8s pods.
- IRR: Internet Routing Registry — Routing policy database.
- ISMS: Information Security Management System — Governance framework.
- ISO: International Organization for Standardization — Standards body.
- ITOps: IT Operations — Traditional operations practice.
- ITSM: IT Service Management — ITIL-based operations.
- ITIL: IT Infrastructure Library — ITSM framework.
- JSON: JavaScript Object Notation — Data format.
- JWT: JSON Web Token — Self-contained auth token.
- Kafka: Distributed event streaming platform — Not acronym but key.
- KDF: Key Derivation Function — Derive keys from passwords.
- KEDA: K8s Event-Driven Autoscaling — Scale on events.
- KMS: Key Management Service — Cloud key management (AWS KMS).
- K8s: Kubernetes — Container orchestrator.
- KV: Key-Value — Data model.
- LACP: Link Aggregation Control Protocol — Bonding interfaces.
- LAG: Link Aggregation Group — Bundled network links.
- LAN: Local Area Network — On-prem network segment.
- LARP: Least Authority Role/Principle — Principle of least privilege variant.
- LB: Load Balancer — Distributes traffic.
- LCM: Lifecycle Management — Managing resource lifecycles.
- LDAP: Lightweight Directory Access Protocol — Directory services.
- LDT: Logical Data Tape — Backup medium concept.
- LFS: Large File Storage — Git LFS for big binaries.
- LFU: Least Frequently Used — Cache eviction policy.
- LRU: Least Recently Used — Cache eviction policy.
- LTS: Long-Term Support — Supported release period.
- LVM: Logical Volume Manager — Disk management layer.
- MAC: Media Access Control — Layer 2 address; also Message Auth Code.
- MACsec: Media Access Control Security — L2 encryption.
- MFA: Multi-Factor Authentication — Auth with multiple factors.
- MITM: Man-In-The-Middle — Interception attack.
- MMU: Memory Management Unit — Virtual memory hardware.
- MPLS: Multiprotocol Label Switching — WAN traffic engineering.
- MQ: Message Queue — Messaging component (SQS, RabbitMQ).
- MQTT: MQ Telemetry Transport — Lightweight pub/sub protocol.
- MTBF: Mean Time Between Failures — Reliability metric.
- MTLS: Mutual TLS — Client/server certificate auth.
- MTTR: Mean Time To Recovery/Repair — Restoration speed.
- MTTD: Mean Time To Detect — Detection speed.
- MTTF: Mean Time To Failure — Expected failure time.
- NAT: Network Address Translation — Private/public IP mapping.
- NATGW: NAT Gateway — Managed NAT in VPC.
- NACL: Network ACL — Stateless subnet-level firewall.
- NCD: Network Change Detection — Observability for network changes.
- NCO: Network Cut Over — Migration event.
- NFS: Network File System — Distributed filesystem protocol.
- NGFW: Next-Gen Firewall — Application-aware firewall.
- NGINX: Web server/reverse proxy — Not an acronym but common.
- NIST: National Institute of Standards and Technology — Security standards.
- NLB: Network Load Balancer — L4 LB on AWS.
- NOC: Network Operations Center — Ops team/room.
- NoSQL: Non-relational databases — Key-value, doc, columnar, graph.
- NTP: Network Time Protocol — Clock sync protocol.
- OIDC: OpenID Connect — Identity layer over OAuth 2.0.
- OAuth2: Authorization framework — Delegated access protocol.
- OBS: Object Storage — S3-compatible storage layer.
- OCI: Open Container Initiative — Image/runtime specs.
- OOM: Out Of Memory — Memory exhaustion condition.
- OPA: Open Policy Agent — Policy engine (Gatekeeper in K8s).
- OPEX: Operational Expenditure — Ongoing costs.
- OS: Operating System — System software.
- OSI: Open Systems Interconnection — 7-layer network model.
- OSS: Open Source Software — Source-available licensing.
- OTP: One-Time Password — Single-use token.
- OTEL: OpenTelemetry — Vendor-neutral traces/metrics/logs.
- OWASP: Open Web Application Security Project — AppSec best practices.
- PaaS: Platform as a Service — Managed app/runtime platform.
- PAC: Proxy Auto-Config — Script to define proxy rules.
- PAM: Pluggable Authentication Modules — Unix auth framework.
- PAN: Personal Area Network — Short-range network.
- PAT: Port Address Translation — Many-to-one NAT.
- PCAP: Packet Capture — Network packet recording.
- PCI DSS: Payment Card Industry Data Security Standard — Compliance.
- PDB: Pod Disruption Budget — K8s min pod availability during disruptions.
- PEM: Privacy-Enhanced Mail — Base64/PEM certificate/key format.
- PKCS#12/P12: Public Key Cryptography Standards #12 — Bundled key+cert format.
- PGO: Postgres Operator — K8s operator for Postgres.
- PGP: Pretty Good Privacy — Email encryption format.
- PBKDF2: Password-Based Key Derivation Function 2 — KDF for secrets.
- PHI: Protected Health Information — Healthcare data.
- PII: Personally Identifiable Information — Sensitive personal data.
- PKCE: Proof Key for Code Exchange — OAuth2 extension.
- PKI: Public Key Infrastructure — Certificates, keys, trust.
- PLG: Product-Led Growth — Growth motion leveraging product.
- PMF: Product Market Fit — Fit of product vs. market.
- PMM: Product Marketing Management — Marketing role.
- PoC: Proof of Concept — Validation prototype.
- PoP: Point of Presence — Edge presence site.
- PoP: Policy on a Page — Internal policy doc.
- POSIX: Portable Operating System Interface — Unix standards.
- PPK: PuTTY Private Key — Key file format for PuTTY.
- PQR: Post-Quantum Readiness — Planning for PQ crypto.
- PR: Pull Request — Proposed code change in Git.
- PRAW: Python Reddit API Wrapper — Not DevOps-specific; seen in scripts.
- PROXY: Proxy protocol — Preserves client info via proxy.
- PSP: Pod Security Policy — Deprecated K8s security policy.
- PSR: Problem Service Request — ITSM incident/request artifact.
- PSTN: Public Switched Telephone Network — Telephony network.
- PTY: Pseudo Terminal — Terminal emulation device.
- QA: Quality Assurance — Testing and quality.
- QoS: Quality of Service — Traffic shaping/prioritization.
- QPS: Queries Per Second — Throughput metric.
- QUIC: Quick UDP Internet Connections — Transport protocol.
- RAID: Redundant Array of Inexpensive Disks — Storage redundancy.
- RBAC: Role-Based Access Control — Role-driven permissions.
- RCE: Remote Code Execution — Vulnerability class.
- RCU: Read-Copy-Update — Concurrency strategy.
- RDS: Relational Database Service — AWS managed relational DB.
- REST: Representational State Transfer — HTTP-based API style.
- RHEL: Red Hat Enterprise Linux — Enterprise Linux distro.
- RFC: Request For Comments — Internet standards/proposals.
- RFI: Request For Information — Procurement information request.
- RFP: Request For Proposal — Procurement proposal request.
- RGA: Rolling/Gradual Adoption — Phased rollout model.
- RGE: Regional Edge — Edge region presence.
- RHEL: Red Hat Enterprise Linux — Enterprise Linux.
- RLS: Row-Level Security — DB access control.
- RMM: Remote Monitoring and Management — Fleet mgmt tooling.
- ROP: Return-Oriented Programming — Exploit technique.
- RPO: Recovery Point Objective — Max tolerable data loss.
- RPS: Requests Per Second — Throughput metric.
- RQ: Rate Queue — Throttling construct.
- RTA: Real-Time Analytics — Streaming analytics.
- RTO: Recovery Time Objective — Target restore time.
- RTT: Round Trip Time — Latency measure.
- RUM: Real User Monitoring — Client-side performance telemetry.
- SaaS: Software as a Service — Hosted software.
- SAML: Security Assertion Markup Language — SSO federation protocol.
- SAN: Storage Area Network — Block storage network.
- SBOM: Software Bill of Materials — Dependency inventory.
- SCCM: System Center Configuration Manager — Windows config mgmt.
- SCP: Secure Copy — File transfer over SSH.
- SCR: Service Change Request — Change management item.
- SDK: Software Development Kit — Tooling/library bundle.
- SDLC: Software Development Life Cycle — Phases of software dev.
- SDN: Software-Defined Networking — Programmable networking.
- SDP: Software-Defined Perimeter — Zero-trust network model.
- SED: Self-Encrypting Drive — Hardware-disk encryption.
- SELinux: Security-Enhanced Linux — Mandatory access control.
- SEM: Security Event Management — Log/event mgmt.
- SES: Simple Email Service — Email sending; domain verification required.
- SFTP: SSH File Transfer Protocol — Encrypted file transfer.
- SG: Security Group — Stateful VPC firewall.
- SHA: Secure Hash Algorithm — Hash functions (SHA-256/512).
- SIEM: Security Information and Event Management — Centralized security telemetry.
- SIG: Special Interest Group — Community working group.
- SLI: Service Level Indicator — Measured metric (latency, error rate).
- SLO: Service Level Objective — Target for SLI.
- SLA: Service Level Agreement — Contracted expectations.
- SM: Secret Manager/Service Mesh — Context dependent.
- SMB: Server Message Block — Windows file sharing protocol.
- SMTP: Simple Mail Transfer Protocol — Email sending protocol.
- SMTPS: SMTP over TLS — Encrypted email sending.
- SNAT: Source NAT — NAT of source address.
- SNS: Simple Notification Service — Pub/sub notifications on AWS.
- SNMP: Simple Network Management Protocol — Network mgmt telemetry.
- SOA: Start of Authority — DNS zone record type.
- SOAP: Simple Object Access Protocol — XML-based messaging protocol.
- SOAR: Security Orchestration, Automation, and Response — Security automation.
- SOC 2: Service Organization Control — Security/compliance attestation.
- SOPS: Secrets OPerationS — Encrypted file management.
- SSM: AWS Systems Manager — Includes Parameter Store and Session Manager.
- SRE: Site Reliability Engineering — Ops discipline using software.
- SRI: Subresource Integrity — Browser integrity check for assets.
- SRR: Same-Region Replication — S3 replication within region.
- SSTD: Standard Deviation (Stats) — Performance variance measurement.
- SSH: Secure Shell — Remote admin protocol.
- SSL: Secure Sockets Layer — Legacy TLS predecessor.
- SSRF: Server-Side Request Forgery — Attack via server making requests.
- SSO: Single Sign-On — One auth grants access to many apps.
- STH: Short-Term Holdback — Delayed release window.
- STIG: Security Technical Implementation Guide — Hardening guidance.
- STS: Security Token Service — Temporary credentials provider.
- SWG: Secure Web Gateway — Web filtering/security proxy.
- SWIM: Scalable Weakly-consistent Infection-style Membership — Gossip protocol.
- SWR: Stale-While-Revalidate — Caching strategy.
- SYN: Synchronize — TCP connection initiation flag.
- Syslog: System Logging Protocol — Standardized logging (RFC 5424).
- Tailscale: WireGuard-based mesh VPN — Not acronym but frequent.
- TAM: Technical Account Manager — Customer liaison role.
- TAP: Test Anything Protocol — Minimalist test format.
- TBAC: Task-Based Access Control — Task-scoped permissions model.
- TCP: Transmission Control Protocol — Reliable transport protocol.
- TDE: Transparent Data Encryption — DB-at-rest encryption.
- TDP: Thermal Design Power — Hardware thermal metric.
- TEE: Trusted Execution Environment — Secure enclave (SGX/SEV/TPM).
- TLS: Transport Layer Security — Network encryption/auth.
- TOTP: Time-based One-Time Password — Time-synced OTP.
- TPM: Trusted Platform Module — Hardware root of trust.
- TPS: Transactions/Requests Per Second — Throughput metric.
- TRIM: SSD discard command — Frees unused blocks.
- TTFB: Time To First Byte — Latency metric.
- TTL: Time To Live — Cache/packet lifetime.
- TTY: Teletype — Terminal device abstraction.
- TUF: The Update Framework — Secure update framework.
- UAC: User Account Control — Windows elevation control.
- UDP: User Datagram Protocol — Unreliable transport protocol.
- UEBA: User and Entity Behavior Analytics — Anomaly detection.
- UID/GID: User/Group ID — Unix identifiers.
- UMA: User-Managed Access — OAuth extension for user consent.
- UMASK: User file-creation mask — Default permission mask.
- UMP: Unified Metrics Platform — Org-wide telemetry.
- UPS: Uninterruptible Power Supply — Backup power.
- URL: Uniform Resource Locator — Resource address string.
- USB: Universal Serial Bus — Peripheral bus.
- UTC: Coordinated Universal Time — Time standard.
- UTM: Urchin Tracking Module — Analytics tagging.
- UTS: Unix Time-Sharing — Kernel namespace concept.
- UWSGI: uWSGI protocol — Web app container protocol.
- VAE: Vulnerability Assessment & Evaluation — Security scanning.
- VCS: Version Control System — Git, Mercurial, etc.
- VDI: Virtual Desktop Infrastructure — Desktop virtualization.
- VIF: Virtual Interface — Network interface abstraction.
- VLAN: Virtual LAN — Segmented L2 network.
- VLT: Virtual Link Trunking — Multi-chassis link aggregation.
- VMs: Virtual Machines — Hardware virtualization.
- VNET/VPC: Virtual Network/Private Cloud — Software-defined networks.
- VPN: Virtual Private Network — Encrypted tunnels.
- VTL: Virtual Tape Library — Backup virtualization.
- VTT: Video Text Tracks — Subtitle format (infra for players).
- VPC Lattice: AWS app networking — Service-to-service networking (not acronym).
- VPA: Vertical Pod Autoscaler — K8s resource rightsizing.
- WASM: WebAssembly — Portable binary format/runtime.
- WAF: Web Application Firewall — HTTP-layer firewall.
- WAL: Write-Ahead Logging — DB durability mechanism.
- WAN: Wide Area Network — Network across sites/regions.
- WMI: Windows Management Instrumentation — Windows mgmt API.
- WORM: Write Once, Read Many — Immutable storage.
- WSS: WebSocket Secure — WebSockets over TLS.
- X.509: Certificate standard — PKI certificate format.
- XDR: Extended Detection and Response — Security telemetry consolidation.
- XML: eXtensible Markup Language — Markup format.
- XSS: Cross-Site Scripting — Web injection attack.
- YAML: YAML Ain’t Markup Language — Human-friendly data format.
- ZK: ZooKeeper — Coordination service (not an acronym).
- ZTA: Zero Trust Architecture — Assume breach; verify explicitly.

---

## Core Terms by Domain

### Delivery & Release

- Blue/Green Deployment: Two identical environments; switch traffic between them to release with minimal downtime.
- Canary Release: Progressive rollout to a small subset before full release.
- Shadow Traffic: Mirror live traffic to a non-user-facing environment for validation.
- Feature Flag: Toggle features at runtime; decouple deploy from release.
- Progressive Delivery: Gradual rollouts with automated metrics-based guardrails.
- Trunk-Based Development: Short-lived branches; frequent merge to trunk/main.
- Change Failure Rate: Fraction of changes causing incidents; DORA metric.
- Lead Time for Changes: Commit-to-prod time; DORA metric.
- Deployment Frequency: How often you ship; DORA metric.
- MTTR: Mean time to restore; DORA metric for recovery.

### Reliability & SRE

- Error Budget: Allowable unreliability derived from SLO (1 - target availability).
- Four Golden Signals: Latency, Traffic, Errors, Saturation — Core observability.
- Toil: Manual, repetitive, automatable ops work — Minimize via automation.
- Blameless Postmortem: Learning-focused incident analysis — Actionable improvements.
- Runbook: Step-by-step operational procedure to handle known events.
- Playbook: Higher-level operational scenario guide; links to runbooks.
- Incident Commander: Single leader during incidents; coordinates response.
- Paging Policy: Rules to notify/on-call; escalations and schedules.
- Service Maturity: Operational readiness level; runbooks, SLOs, alerts, DR.

### Observability

- Metrics: Numeric time-series; aggregated behavior over time.
- Logs: Discrete, often unstructured events; context for debugging.
- Traces: Distributed request lifecycles; spans show timing and causality.
- Cardinality: Number of unique label combinations; impacts cost/perf.
- Histogram: Bucketed distribution type; enables p50/p95/p99 calculations.
- RED Method: Rate, Errors, Duration — Observability focus for services.
- USE Method: Utilization, Saturation, Errors — Resource-focused monitoring.
- OpenTelemetry (OTel): Instrumentation SDKs and Collector; export OTLP.
- Trace Context: W3C headers `traceparent`/`tracestate` for propagation.
- Prometheus: Pull-based metrics; ServiceMonitors to discover scrape targets.
- Grafana: Dashboards; supports Prometheus/Loki/Tempo/CloudWatch.
- Tempo/Jaeger: Tracing backends; integrate via OTel Collector.
- Loki: Log store; ingest via Promtail/Fluent Bit/Vector.
- Vector/Fluent Bit: Agents/shippers for logs (and some metrics); add redaction.
- Datadog/Axiom: Managed platforms for metrics/logs/traces ingest and search.

### Architecture & Patterns

- Idempotency: Safe to retry without side effects.
- Circuit Breaker: Stop calls to failing dependency to protect system.
- Bulkhead: Isolate components to limit failure blast radius.
- Backpressure: Signal upstream to slow down to prevent overload.
- Event-Driven: Loosely-coupled components react to events asynchronously.
- CQRS: Separate reads and writes for scaling and clarity.
- Saga: Long-running distributed transactions with compensating actions.
- Strangler Fig: Incrementally replace legacy systems by routing and carving off functionality.
- Sidecar Pattern: Co-located helper container (e.g., proxy, agent) with main app.
- Service Mesh: Layer for service-to-service networking, mTLS, retries, policy (e.g., Istio, Linkerd).

### Kubernetes & Containers

- Pod: Smallest deployable unit; one or more containers sharing network/storage.
- Deployment: Controller for stateless Pods; manages rollout/rollback.
- StatefulSet: Workload with stable identities/storage for stateful apps.
- DaemonSet: Runs one Pod per node; commonly agents (logs, metrics).
- Job/CronJob: Batch processes; run to completion or on schedule.
- Ingress: L7 routing into cluster; often backed by an ingress controller.
- OIDC Provider: EKS IAM OIDC provider enabling IRSA for service accounts.
- Service: Stable virtual IP/DNS for Pods; ClusterIP, NodePort, LoadBalancer.
- ConfigMap/Secret: Configuration and sensitive data injection into Pods.
- PV/PVC/StorageClass: Persistent storage abstractions in Kubernetes.
- Taints/Tolerations: Node-level constraints for scheduling.
- Affinity/Anti-affinity: Pod placement rules across nodes/azs.
- Liveness/Readiness/Startup Probes: Health and readiness checks for Pods.
- Operators: Controllers implementing domain-specific automation via CRDs.
- CNI/CSI: Plugins for networking and storage in Kubernetes.

### Terraform & IaC

- Remote State: S3 backend with lockfile or DynamoDB lock table; avoids local state drift.
- Lockfile: `.terraform.lock.hcl` — Provider checksums/versions for reproducibility.
- Workspaces vs States: Prefer separate states per env/stack; workspaces for small variants.
- `terraform_remote_state`: Data source to read outputs from another state.
- `-chdir`: Run Terraform in a specific directory without `cd`.
- `-var` / `*.tfvars` / `*.auto.tfvars`: Ways to pass variables; prefer files over long flags.
- `for_each` / `count`: Resource iteration patterns; prefer map-based `for_each` for determinism.
- `cidrsubnet()`: Derive child CIDRs from a parent block predictably.
- Default Tags: Provider-level tags merged with resource tags (use `merge()`).

### Cloud (AWS-centric, with cross-cloud analogs)

- Region: Geographic area comprising isolated Availability Zones.
- Availability Zone (AZ): Isolated datacenter(s) within a region.
- VPC: Isolated virtual network; subnets span AZs.
- Subnet: IP range segment in a VPC; public/private.
- Route Table: Routing rules applied to subnets.
- IGW/NATGW: Internet/NAT gateways; egress/ingress boundaries.
- NACL/Security Group: Stateless vs. stateful network controls.
- S3: Object storage; versioning, encryption, lifecycle, replication.
- S3 Block Public Access: Account/bucket-wide controls to block public ACLs/policies.
- EC2: Virtual machines; instance types, EBS volumes, security.
- ECS/EKS: Container orchestration managed services.
- RDS/Aurora: Managed relational databases; backups, read replicas.
- ElastiCache: Managed Redis/Memcached; caching layer.
- Lambda: Serverless functions; event-driven compute.
- API Gateway: Managed API front-door; auth, throttling, caching.
- CloudFront: CDN; edge caching and routing.
- CloudWatch: Metrics, logs, alarms; dashboards and insights.
- CloudTrail: API audit logs; governance and forensics.
- SES: Simple Email Service — Email delivery with DKIM/SPF.
- ACM: AWS Certificate Manager — Issues TLS certs for ALB/CloudFront.
- KMS: Key management; envelope encryption; grants and key policies.
- Parameter Store/Secrets Manager: Configuration and secrets storage.
- Route 53: DNS/Health checks; traffic policies and private hosted zones.

### Security

- Defense in Depth: Layered security controls across boundaries.
- Zero Trust: Verify explicitly; least privilege; assume breach.
- Principle of Least Privilege: Grant minimal required permissions.
- Shift Left: Address security early in development lifecycle.
- Key Rotation: Regularly replace keys/tokens/certs to reduce risk window.
- Token Boundaries: Clear scoping for access tokens and service accounts.
- Threat Modeling: Identify assets, threats, mitigations before build.
- Secrets Hygiene: Don’t embed secrets in code/images; rotate and scope.
- Vulnerability Management: Scan, prioritize (CVSS + exploitability), remediate.
- Hardening: Disable defaults; patching; secure configs; CIS benchmarks.
- SSE: Server-Side Encryption — S3 SSE-S3 or SSE-KMS.
- KMS Grants/Key Policy: Fine-grained permissions model for CMKs.

### Networking

- OSI Model: Conceptual 7-layer networking model.
- Anycast: Same IP advertised from multiple locations for latency/resilience.
- Overlay Network: Virtual network built atop another network (e.g., VXLAN).
- East/West vs. North/South: Internal service traffic vs. external ingress/egress.
- MTU/MSS: Packet/frame sizes; impacts fragmentation and throughput.
- DNS TTL: Cache lifetime; affects propagation and failover speed.
- Health Checks: L4/L7 probes for availability and routing decisions.
- 802.1Q/dot1q: VLAN tagging standard used on trunk links.
- Subinterface: Router interface split by VLAN ID (e.g., `Gi0/1.10`).
- DHCP Pool: Scope providing IPs, default-router, DNS to VLANs.
- PAT: Port Address Translation — Many-to-one NAT with port multiplexing.
- Port Forward: Static NAT of a specific port to an internal host.

### Data & Storage

- ACID vs. BASE: Transaction guarantees vs. eventual consistency tradeoffs.
- OLTP vs. OLAP: Transactional vs. analytical workloads and systems.
- Partitioning/Sharding: Split data across nodes for scale and isolation.
- Replication: Copy data across nodes/regions for HA/DR and locality.
- Snapshot: Point-in-time copy; for backup or cloning.
- CDC: Change Data Capture — Stream changes to downstream systems.
- JSONB: Postgres binary JSON type enabling fast queries on JSON data.

### Testing & Quality

- Unit/Integration/E2E Tests: Smallest to full-system coverage levels.
- Property-Based Testing: Randomized inputs asserting general properties.
- Chaos Engineering: Inject controlled failures to validate resilience.
- Soak Testing: Long-duration load to find leaks/drift.
- Load/Stress/Spike Testing: Perf under expected/overload/rapid growth.
- Self-Test: App boots, exercises dependencies (S3/RDS/Redis), reports results.

### Process & Governance

- RFC: Lightweight proposal process for changes; get feedback early.
- ADR: Permanent record of key decisions; rationale and context.
- CAB/CCB: Governance reviews for changes in regulated environments.
- RACI: Responsible, Accountable, Consulted, Informed — Role clarity matrix.
- Runway: Lead time to set up infra/processes before scaling teams.

### Cost & FinOps

- Tagging Strategy: Consistent metadata for cost allocation and governance.
- Rightsizing: Adjust resources to actual usage; autoscale, instance size.
- Purchase Options: On-demand vs. Savings/Reserved vs. Spot instances.
- Data Egress: Outbound data costs; design to minimize costly patterns.
- Observability Costs: Cardinality and retention tuning to control spend.

### Culture & Principles

- DevOps: Collaboration across dev and ops; automation and ownership.
- Platform Engineering: Product mindset; paved roads; golden paths.
- SRE: Reliability via engineering; SLOs and error budgets.
- GitOps: Ops via Git as source of truth; reconcile loop.
- DevSecOps: Security integrated into dev and ops practices.
- DRY/KISS/YAGNI: Core engineering principles to keep systems maintainable.

---

## Repo-Specific Terms

### AWS Labs Flow (00 → 21)

- Backend: S3 state bucket (us-east-1), optional DDB locks for <= TF 1.9.
- VPC: Public/private subnets across two AZs; IGW/NAT; endpoints.
- Endpoints: S3 Gateway + interface endpoints (SSM, ECR, Logs) with Private DNS.
- ECR: Scan on push; lifecycle policies; image tags `staging` + commit SHA.
- DNS: Delegated subdomain in Route 53; A/AAAA/CNAME records.
- IAM: Task execution and task roles; least-privilege `iam:PassRole`.
- Security Groups: ALB SG → App SG ingress; least-privilege egress.
- S3: Versioned, private bucket with Block Public Access; SSE on.
- RDS: Postgres in private subnets; Secrets Manager for `DB_PASS`.
- Redis: TLS-enabled ElastiCache; `rediss://` only.
- Parameter Store: Non-secrets (host, port, user, name) under a path by env/service.
- ALB: HTTPS listener + target group; health checks.
- ECS: Fargate service with awslogs; ECS Exec enabled.
- CI/CD (ECS): CodePipeline → CodeBuild builds image + `imagedefinitions.json`.
- Observability: CloudWatch dashboard and alarms; Container Insights.
- EKS: Cluster + node group; ALB Controller + ExternalDNS; app via Helm.
- CI/CD (EKS): Optional pipeline building helm chart and deploying via CodeBuild.

### CI/CD & Notifications

- CodePipeline Stages: Source → Build → Deploy (ECS/EKS/CFN or custom).
- Buildspec: `buildspec.yml` describes install, build, post_build; emits artifacts.
- `imagedefinitions.json`: ECS deployment artifact mapping container name → image.
- GitHub Actions: Optional PR/CI flow; may push images to GHCR.
- Slack Notifications: CodeStar Notifications → SNS → Lambda → Slack webhook.

### Demo Node App

- Endpoints: `/healthz`, `/selftest`, `/s3/:id`, `/db/items`, `/cache/:key`.
- Env Vars: `APP_ENV`, `LOG_LEVEL`, `S3_BUCKET`, `AWS_REGION`, DB*\* vars, `REDIS*\*`, `SELF_TEST_ON_BOOT`.
- Local Dev: `docker compose` for Postgres and Redis; port 3000.
- Helm: Values configure image repo, DB/Redis endpoints, secrets; ALB Ingress.

### Interview Materials

- STAR: Situation, Task, Action, Result (+ Learnings).
- SOAR: Situation, Obstacle, Action, Result.
- CAR: Challenge, Action, Result (short form).
- System Design: Prompts, scoring rubrics; focus on trade-offs and SLOs.

### Networking Labs (Cisco Campus)

- Trunk: 802.1Q tagged link carrying multiple VLANs.
- Subinterfaces: VLAN-specific L3 interfaces (e.g., `Gi0/1.10`).
- DHCP Pools: Provide IP/DNS/domain for VLANs.
- NAT Overload: PAT on WAN interface; inside/outside designation.
- Port Forward: Static NAT of 443 to a server in VLAN20.

---

## Handy Equivalents (Cross-Cloud)

- AWS ALB ≈ GCP External HTTP(S) LB ≈ Azure Application Gateway.
- AWS NLB ≈ GCP External TCP/UDP LB ≈ Azure Load Balancer.
- AWS EKS ≈ GKE ≈ AKS.
- AWS S3 ≈ GCS ≈ Azure Blob Storage.
- AWS RDS/Aurora ≈ Cloud SQL/AlloyDB ≈ Azure Database for MySQL/Postgres.
- AWS CloudWatch Logs ≈ GCP Cloud Logging ≈ Azure Monitor Logs.
- AWS KMS ≈ GCP KMS ≈ Azure Key Vault.
- AWS Secrets Manager ≈ GCP Secret Manager ≈ Azure Key Vault Secrets.

---

## Reading Notes

- Keep definitions short and actionable; link to internal runbooks for deep dives.
- Prefer vendor-neutral terms; call out vendor specifics when behavior differs.
- Expand this file as your stack evolves; keep acronyms alphabetical.

---

## Contributing

- Add new terms in alphabetical order under Acronyms or relevant domain.
- Keep definitions concise (one line where possible).
- Include context when a term is overloaded (e.g., SM: Secret Manager/Service Mesh).
- Submit changes via PR; reviewers should verify clarity and correctness.
