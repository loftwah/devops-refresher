# CloudFront (Optional Theory)

## When To Use It

- Not required for this backend-only demo. Useful when you add a static frontend or need global caching/acceleration.

## Common Patterns

- Static frontend: S3 as origin with OAC, CloudFront for TLS and caching.
- API via ALB: CloudFront with ALB origin for edge WAF, geo policies, or custom caching; keep minimal caching for APIs.

## Key Decisions

- Certificates: ACM in `us-east-1` for CloudFront distributions.
- DNS: Route 53 alias to the CloudFront domain.
- Security: Prefer OAC for S3 and WAF for protection if exposed globally.

## Reference Tasks (if adopted later)

1. Request/validate ACM cert in `us-east-1` for your domain.
2. Create CloudFront distribution with S3 or ALB origin; attach suitable cache/origin request policies.
3. Create Route 53 alias record pointing at the distribution.

## Terraform Hints

- `aws_acm_certificate` (us-east-1 provider alias), `aws_cloudfront_distribution`, `aws_route53_record`.
- For S3 origin, use OAC and bucket policy to restrict access to CloudFront.
