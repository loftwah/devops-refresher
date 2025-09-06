# Lab 02: Application Load Balancer

## Objectives

- Add an ALB, target group, and listeners (80 redirect to 443, 443 forward to TG) with a dummy target.

## Tasks

1. Create ALB across public subnets with a dedicated SG allowing 80/443.
2. Create a target group (HTTP, port 80) with `/health` check.
3. Create listeners 80→redirect 443, 443→forward to TG (attach ACM cert).
4. Temporarily register a test target (e.g., a dummy EC2 or skip until ECS).

## Acceptance Criteria

- ALB DNS serves 301 on http and valid TLS on https.
- Target group health passes (use a simple EC2 or proceed to ECS lab if skipping).

## Hints

- You can attach the TG later once ECS tasks exist; for now ensure ALB + listeners compile.
- Use Route53 alias to test a custom hostname if you have a domain.
