# Lab 10: CloudFront (CDN + TLS)

## Objective

Front public content and services with CloudFront for performance, security, and TLS, using Route 53 for DNS.

## Patterns

- Static assets: S3 bucket as origin, OAC (Origin Access Control) to block public S3 access.
- Dynamic app behind ALB: ALB as origin (ECS/EKS services), cache by path, protect with WAF (optional).

## Decisions

- Certs: ACM certificate in `us-east-1` for custom domains (CloudFront requirement).
- DNS: records under `aws.deanlofts.xyz` (e.g., `app.aws.deanlofts.xyz`).
- Caching: minimal caching for APIs (`Cache-Control` based), stronger for static.

## Tasks (ALB origin)

1. Request/validate ACM cert in `us-east-1` for `app.aws.deanlofts.xyz` (DNS validation in Route 53).
2. Create CloudFront distribution with ALB origin; set Origin Request Policy and Cache Policy.
3. Add Route 53 alias record to CloudFront domain.

## Acceptance Criteria

- `curl -I https://app.aws.deanlofts.xyz` returns 200 via CloudFront.
- ALB not publicly exposed by direct DNS in client paths (optional).

## Terraform Hints

- `aws_acm_certificate` (us-east-1 provider alias), `aws_cloudfront_distribution`, `aws_route53_record`.
- For S3 origin, use OAC and bucket policy to only allow CloudFront access.
