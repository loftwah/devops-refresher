# What a Senior DevOps Engineer Should Know About Kubernetes

## What Kubernetes is, in DevOps terms

**What**
Kubernetes is a control plane that keeps your containers running in the state you declare. You post YAML to an API, and a set of controllers reconciles real state to match it. Workloads run in Pods, grouped and updated by Deployments, exposed by Services and Ingress or the Gateway API.

**Where it runs**
On AWS you use **Amazon EKS**. Control plane is managed by AWS, nodes are EC2, or you can run Pods on Fargate for some workloads.

**When to use it**
You want repeatable deploys, built-in health checks and autoscaling, standardised networking, and portability between laptops, staging and production.

**How it helps DevOps**
You get one way to rollout, scale, observe, and recover services. That consistency is the value.

---

## EKS building blocks you will actually touch

### Local/dev clusters (k3s, kind, minikube)

- k3s: lightweight CNCF-conformant Kubernetes, great for dev/edge and lab work in 2025. Uses a single binary and SQLite by default; can run on a small VM or Raspberry Pi. Handy when you want real Kubernetes semantics with minimal footprint.
- kind: runs Kubernetes in Docker. Fastest spin-up for CI and local testing.
- minikube: single-node cluster with multiple drivers (Docker/Hyperkit/etc.).

Use EKS for managed/staging/prod. Use k3s/kind/minikube locally to iterate on manifests/Helm charts before pushing to EKS. Keep the API objects the same (Deployments/Services/Ingress) so your manifests stay portable.

### Cluster, nodes and scheduling

- **Cluster** is the control plane API you talk to.
- **Nodes** are EC2 instances in managed node groups, or Fargate. Use managed node groups for most apps.
- **Scheduling** places Pods based on requests and constraints. Always set CPU and memory **requests** to get predictable bin-packing and eviction rules. Requests and limits control QoS tiers. ([AWS Documentation][1])

**How to create a cluster quickly with eksctl**

```bash
# Creates a basic cluster with one managed node group
eksctl create cluster --name dev --region ap-southeast-2 --nodes 3 --node-type m6i.large
# Verify
kubectl get nodes -o wide
```

eksctl is the supported CLI for day-one creation and day-two node group management. ([Eksctl][2], [AWS Documentation][3])

---

## Networking on EKS

### Services and load balancers

- **ClusterIP** Service for in-cluster communication.
- **LoadBalancer** Service provisions an AWS **Network Load Balancer (NLB)**. Good for TCP, gRPC, or when you do TLS at the app or a service mesh. EKS supports NLB behaviour through Service annotations. ([AWS Documentation][4])
- **Ingress** exposes HTTP or HTTPS through an **Application Load Balancer (ALB)** via the **AWS Load Balancer Controller**. It watches Ingress and Services and creates AWS load balancing resources. You can set the ALB health check path with an annotation. ([AWS Documentation][4], [GitHub][5])

**When to choose what**

- Public web apps and APIs: Ingress with ALB.
- Private TCP or gRPC: Service type LoadBalancer with NLB.
- Complex cross-VPC or cross-cluster traffic policy: Gateway API with AWS Gateway API Controller.

### VPC CNI and security groups for Pods

EKS uses the **Amazon VPC CNI** so Pods get VPC IPs. You can attach **security groups to Pods** for tighter east-west controls, which you configure in the VPC CNI. Use this for high value workloads that need L3 filtering beyond NetworkPolicy. ([GitHub][6], [AWS Documentation][7])

---

## Storage on EKS

- Use the **EBS CSI driver** for block storage on EC2 nodes. It manages PersistentVolumes and generic ephemeral volumes.
- Use the **EFS CSI driver** for shared POSIX access across Pods.
- You cannot mount EBS to Pods on Fargate. Plan accordingly. ([AWS Documentation][8])

---

## Identity and secrets

### AWS permissions to Pods

Two supported patterns in 2025:

- **EKS Pod Identity** is the new path. You create a **pod identity association** linking a service account to an IAM role. An agent on each node brokers short-lived credentials. Not supported for Fargate or Windows Pods at this time. ([AWS Documentation][1])
- **IRSA** (IAM Roles for Service Accounts) is the older, still common pattern using the cluster OIDC provider.

**When to use**
Prefer Pod Identity for new clusters. Use IRSA where you already have it and migration is not justified.

### Kubernetes Secrets vs AWS Secrets Manager

- Keep app config in ConfigMaps and Kubernetes Secrets.
- For high value secrets, store in AWS Secrets Manager or SSM Parameter Store and fetch at runtime. Consider the Secrets Store CSI driver if you want file mounts from those providers.

---

## Health checks that drive rollout and traffic

Kubernetes knows three checks:

- **readinessProbe** tells when a Pod can receive traffic.
- **livenessProbe** tells when a container should be restarted.
- **startupProbe** protects slow starters before liveness begins. Use longer thresholds here.
  Pattern: use a cheap endpoint for both readiness and liveness, but make liveness slower so Pods go unready before restart. ([Kubernetes][9])

**Why paths like `/readyz` and `/livez`**
Kubernetes components expose `/healthz`, `/readyz`, and `/livez`. Projects copy that convention. `/healthz` is considered legacy on some components but remains present. In your apps prefer explicit `/readyz` and `/livez`. ([Kubernetes][10], [GitHub][11])

**Ingress health**
For ALB, set the annotation to point the ALB target group health check at `/readyz` so traffic stops before the Pod is restarted. ([AWS Documentation][4])

---

## Autoscaling you will rely on

- **HPA v2** scales replicas from CPU, memory, or custom metrics. Needs **Metrics Server**. ([geoffcline.github.io][12], [GitHub][13])
- **Cluster Autoscaler** grows or shrinks node groups to fit pending Pods.
- **Karpenter** is a high-performance node provisioning controller that launches the right size nodes in under a minute and can reduce costs by packing well. Use Karpenter with managed node groups or instead of Cluster Autoscaler. ([AWS Documentation][14], [karpenter.sh][15])

**When to choose**

- If you run many diverse workloads and want just-in-time capacity and cost control, choose Karpenter.
- If you want conservative autoscaling tied to a few fixed groups, use Cluster Autoscaler.

---

## Observability on AWS

- **CloudWatch Container Insights** collects cluster, node, Pod metrics and logs. Install the CloudWatch agent or the Observability add-on. ([AWS Documentation][16])
- **Prometheus** scrapes app and component metrics. Use the Kubernetes Metrics Reference to know what to expect from core components. ([Kubernetes][17])
- **ExternalDNS** creates Route 53 records for Ingress and Services automatically. Great for GitOps. ([GitHub][18], [Amazon Web Services Repost][19])
- **cert-manager** issues TLS for Ingress. Pair with Let’s Encrypt DNS-01 on Route 53 or with **AWS Private CA Issuer** when you need private trust. ([cert-manager][20], [GitHub][21])

---

## A complete, runnable example for EKS

This is a minimal HTTP API with clear health endpoints, exposed through ALB. It shows how you call it in dev and how you see success or failure. Use the same pattern for Rails, Go, Node, or your stack.

### App with `/livez`, `/readyz`, `/healthz`

```go
// app/main.go
package main

import (
  "encoding/json"
  "log"
  "net/http"
  "os"
  "sync/atomic"
  "time"
)

var ready int32

func main() {
  go func() {
    time.Sleep(3 * time.Second) // simulate init
    atomic.StoreInt32(&ready, 1)
  }()
  http.HandleFunc("/livez", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(200); w.Write([]byte("ok")) })
  http.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
    if atomic.LoadInt32(&ready) == 1 { w.WriteHeader(200); w.Write([]byte("ready")); return }
    http.Error(w, "not ready", http.StatusServiceUnavailable)
  })
  http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(200); w.Write([]byte("ok")) })
  http.HandleFunc("/api/v1/echo", func(w http.ResponseWriter, r *http.Request) {
    var p map[string]any; _ = json.NewDecoder(r.Body).Decode(&p)
    _ = json.NewEncoder(w).Encode(map[string]any{"echo": p, "host": os.Getenv("HOSTNAME"), "ts": time.Now().UTC().Format(time.RFC3339)})
  })
  log.Fatal(http.ListenAndServe(":8080", nil))
}
```

### Container image

```dockerfile
# docker/Dockerfile
FROM golang:1.22 as build
WORKDIR /src/app
COPY app/ .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/server

FROM gcr.io/distroless/base-debian12
COPY --from=build /out/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

Build and push to ECR:

```bash
export AWS_REGION=ap-southeast-2
export IMAGE_REPO="<your ECR repo URI>"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$(dirname "$IMAGE_REPO")"
docker build -t echo:latest -f docker/Dockerfile .
docker tag echo:latest "$IMAGE_REPO:latest"
docker push "$IMAGE_REPO:latest"
```

### Kubernetes manifests for EKS

```yaml
# kubernetes/manifests/deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata: { name: echo, labels: { app: echo } }
spec:
  replicas: 2
  selector: { matchLabels: { app: echo } }
  template:
    metadata: { labels: { app: echo } }
    spec:
      serviceAccountName: echo-sa
      containers:
        - name: echo
          image: 123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/echo:latest
          ports: [{ containerPort: 8080 }]
          readinessProbe:
            {
              httpGet: { path: /readyz, port: 8080 },
              initialDelaySeconds: 2,
              periodSeconds: 5,
            }
          livenessProbe:
            {
              httpGet: { path: /livez, port: 8080 },
              initialDelaySeconds: 5,
              periodSeconds: 10,
            }
          resources:
            requests: { cpu: "100m", memory: "128Mi" }
            limits: { cpu: "250m", memory: "256Mi" }
---
# kubernetes/manifests/service.yml
apiVersion: v1
kind: Service
metadata: { name: echo, labels: { app: echo } }
spec:
  selector: { app: echo }
  ports: [{ name: http, port: 80, targetPort: 8080 }]
  type: ClusterIP
---
# kubernetes/manifests/ingress.yml (AWS Load Balancer Controller)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /readyz
spec:
  rules:
    - http:
        paths:
          - path: /api
            pathType: Prefix
            backend: { service: { name: echo, port: { number: 80 } } }
```

Apply and verify:

```bash
kubectl apply -f kubernetes/manifests/
kubectl rollout status deploy/echo
kubectl get ingress echo
# when ALB DNS is ready
curl -s https://<alb-dns>/api/v1/echo -d '{"msg":"hi"}' -H 'Content-Type: application/json' | jq .
# success is HTTP 200, non-zero exit means failure
echo $?
```

Ingress and ALB behaviour is managed by the AWS Load Balancer Controller. The health check annotation points the target group at `/readyz`. ([AWS Documentation][4])

---

## Real world EKS patterns with what, where, when, how

### Public web API behind ALB

- **What**: Internet traffic hits ALB, routes to Ingress, then to Service and Pods.
- **Where**: Use public subnets for ALB, private subnets for nodes.
- **When**: Any HTTP or HTTPS service that faces the internet.
- **How**: Install AWS Load Balancer Controller, use an Ingress with annotations, terminate TLS on ALB with ACM, and use `/readyz` as the health check. ([AWS Documentation][4])

### Private gRPC between microservices

- **What**: NLB with internal scheme, targets Pod IPs.
- **Where**: Inside the VPC, no public exposure.
- **When**: Low latency L4, gRPC, or custom protocols.
- **How**: Service type LoadBalancer with NLB annotations, or use Gateway API and VPC Lattice when you need policy and cross-VPC discovery. ([AWS Documentation][4])

### Work queues with SQS using KEDA

- **What**: Consumers scale on queue depth.
- **Where**: Namespaced worker Deployments.
- **When**: Variable throughput jobs and event processing.
- **How**: Install KEDA, create a ScaledObject pointing at SQS, provide AWS access via Pod Identity or IRSA.

### Stateful services

- **What**: Databases or stateful apps with per-Pod volumes.
- **Where**: EC2 nodes with EBS CSI.
- **When**: You need persistent block storage per Pod.
- **How**: StatefulSet with a PersistentVolumeClaim template. Do not plan to run on Fargate because EBS is not supported there. ([AWS Documentation][8])

### DNS and certificates

- **What**: Automate Route 53 records and TLS.
- **Where**: Cluster-wide controllers.
- **When**: You want GitOps for DNS and certs.
- **How**: Install ExternalDNS to create Route 53 records from Ingress. Install cert-manager for TLS and use Let’s Encrypt DNS-01 or AWS Private CA Issuer for internal trust. ([GitHub][18], [cert-manager][20])

### Logs and metrics

- **What**: Cluster, node, Pod metrics and application logs.
- **Where**: CloudWatch Container Insights.
- **When**: Default for EKS teams without an existing observability stack.
- **How**: Install the CloudWatch agent or Observability add-on, ship stdout logs and metrics to CloudWatch. ([AWS Documentation][16])

### IAM to Pods

- **What**: AWS credentials without static keys.
- **Where**: Namespaced service accounts.
- **When**: Any app that calls AWS APIs.
- **How**: Prefer EKS Pod Identity. Create an IAM role, associate it to a service account. The agent on nodes exchanges for temporary creds. Note current limitation on Fargate and Windows. ([AWS Documentation][1])

---

## Day two operations you will be asked about

### Rollouts and safety

```bash
kubectl set image deploy/echo echo=$IMAGE_REPO:abc123
kubectl rollout status deploy/echo
kubectl rollout history deploy/echo
kubectl rollout undo deploy/echo
```

- Success is a completed rollout and passing readiness. Failure shows in `kubectl describe` events and rollout status.

### Upgrades

- Upgrade EKS control plane, then node groups. Use surge node groups to drain and replace nodes safely. Test in a non-prod cluster first.

### Autoscaling posture

- Set requests so HPA has a sensible baseline.
- Pair HPA with Cluster Autoscaler or Karpenter so the cluster scales when Pods need capacity. ([geoffcline.github.io][12], [AWS Documentation][14])

### Network controls

- Start with default-deny **NetworkPolicy** then allow required flows. Combine with security groups for Pods on sensitive services. ([AWS Documentation][22])

### Backups and recovery

- Backup EBS volumes and critical cluster state.
- Consider Velero for namespaces and PVCs.

---

## How to reason about success or failure in practice

- Probes
  - `readinessProbe` 200 means Pod joins Service endpoints and ALB turns target healthy. 503 or timeout means removed from endpoints.
  - `livenessProbe` failures restart the container. Keep failureThreshold higher than readiness to avoid flapping. ([Kubernetes][9])

- Traffic
  - `kubectl get ingress` shows an ALB DNS name when ready. If missing, check the AWS Load Balancer Controller logs and Ingress annotations. ([AWS Documentation][4])

- Autoscaling
  - `kubectl top` requires Metrics Server. HPA conditions show if scaling happens. ([GitHub][13])

- Identity
  - From a Pod, `aws sts get-caller-identity` should show the role you associated with Pod Identity or IRSA. ([AWS Documentation][1])

---

## Exercises to lock it in

- Swap the Ingress for a Service type LoadBalancer with NLB and prove gRPC works end to end. Validate target health in the AWS console and with `kubectl get svc`. ([AWS Documentation][4])
- Install Metrics Server, apply an HPA at 60 percent CPU, generate load with `kubectl run hey --image=rakyll/hey -- -z 2m -c 20 http://echo.default.svc.cluster.local/api/v1/echo`, and observe scaling. ([GitHub][13])
- Install Karpenter, create a Provisioner that allows Spot and On-Demand with multiple instance families, and watch it launch right-sized nodes under load. ([karpenter.sh][15])
- Attach a security group to a sensitive Pod using the VPC CNI configuration, then prove blocked and allowed flows with `curl` and `ss`. ([AWS Documentation][7])
- Install ExternalDNS and cert-manager, then create an Ingress with a Route 53 hostname and issue a Let’s Encrypt certificate automatically. ([GitHub][18], [cert-manager][20])
- Enable CloudWatch Container Insights and confirm application logs and cluster metrics appear in CloudWatch within minutes. ([AWS Documentation][16])

---

## Quick reference you will use daily

```bash
# Apply and verify
kubectl apply -k kubernetes/overlays/prod
kubectl rollout status deploy/echo
kubectl get events --sort-by=.lastTimestamp

# Inspect health
kubectl get pods -o wide
kubectl describe pod <name>
kubectl logs -f deploy/echo

# Port-forward for local testing
kubectl port-forward deploy/echo 8080:8080
curl -s http://localhost:8080/readyz && echo OK || echo FAIL
```

Rollout and debugging commands are in the kubectl reference and common workflows.

---

## Sources and credibility

- Kubernetes probes, Deployments, Services, metrics reference. **High credibility**. ([Kubernetes][9])
- Kubernetes API health endpoints and component conventions. **High credibility**. ([Kubernetes][10])
- AWS EKS Pod Identity docs and setup. **High credibility**. ([AWS Documentation][1])
- AWS Load Balancer Controller behaviour and annotations. **High credibility**. ([AWS Documentation][4], [GitHub][5])
- Amazon VPC CNI and security groups for Pods. **High credibility**. ([GitHub][6], [AWS Documentation][7])
- EBS CSI driver on EKS and Fargate limitation. **High credibility**. ([AWS Documentation][8])
- Metrics Server for HPA. **High credibility**. ([GitHub][13])
- Karpenter autoscaling. **High credibility**. ([AWS Documentation][14], [karpenter.sh][15])
- CloudWatch Container Insights. **High credibility**. ([AWS Documentation][16])

[1]: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html "Learn how EKS Pod Identity grants pods access to AWS services"
[2]: https://eksctl.io/usage/creating-and-managing-clusters/ "Creating and managing clusters - eksctl"
[3]: https://docs.aws.amazon.com/eks/latest/eksctl/creating-and-managing-clusters.html "Creating and managing clusters - Eksctl User Guide"
[4]: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html "Route internet traffic with Amazon Load Balancer Controller"
[5]: https://github.com/kubernetes-sigs/aws-load-balancer-controller "GitHub - kubernetes-sigs/aws-load-balancer-controller: A Kubernetes ..."
[6]: https://github.com/aws/amazon-vpc-cni-k8s "GitHub - aws/amazon-vpc-cni-k8s: Networking plugin repository for pod ..."
[7]: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-pods-deployment.html "Configure the Amazon VPC CNI plugin for Kubernetes for security groups ..."
[8]: https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html "Use Kubernetes volume storage with Amazon EBS - Amazon EKS"
[9]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ "Configure Liveness, Readiness and Startup Probes - Kubernetes"
[10]: https://kubernetes.io/docs/reference/using-api/health-checks/ "Kubernetes API health endpoints"
[11]: https://github.com/kubernetes/kubernetes/issues/133184 "List available endpoints for kubelet's /statusz #133184"
[12]: https://geoffcline.github.io/aws-load-balancer-controller/guide/ingress/annotations/ "Annotations - AWS LoadBalancer Controller"
[13]: https://github.com/kubernetes-sigs/metrics-server "Kubernetes Metrics Server - GitHub"
[14]: https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html "Scale cluster compute with Karpenter and Cluster Autoscaler"
[15]: https://karpenter.sh/docs/ "Documentation - Karpenter"
[16]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/deploy-container-insights-EKS.html "Setting up Container Insights on Amazon EKS and Kubernetes"
[17]: https://kubernetes.io/docs/reference/instrumentation/metrics/ "Kubernetes Metrics Reference"
[18]: https://github.com/kubernetes-sigs/external-dns "GitHub - kubernetes-sigs/external-dns: Configure external DNS servers ..."
[19]: https://repost.aws/knowledge-center/eks-set-up-externaldns "Set up ExternalDNS with Amazon EKS | AWS re:Post"
[20]: https://cert-manager.io/docs/tutorials/getting-started-aws-letsencrypt/ "Deploy cert-manager on AWS Elastic Kubernetes Service (EKS) and use Let ..."
[21]: https://github.com/cert-manager/aws-privateca-issuer "GitHub - cert-manager/aws-privateca-issuer: Addon for cert-manager that ..."
[22]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-EKS-quickstart.html "Quick Start setup for Container Insights on Amazon EKS and Kubernetes"
