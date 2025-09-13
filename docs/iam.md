# AWS IAM Explanation

## 1. What IAM Is

AWS Identity and Access Management (IAM) is the central service that controls **who** can access **what** in your AWS account, and **how** they can access it.

It functions as:

- **Identity provider**: manages users, roles, groups, and federated identities.
- **Authorisation system**: enforces access rules through policies.
- **Trust manager**: defines which identities or services can assume which roles, under what conditions.

---

## 2. Core Concepts

### Identities

- **Users**: Human or programmatic accounts with credentials.
- **Groups**: Collections of users with shared permissions.
- **Roles**: Temporary identities designed for AWS services, applications, or federated access.

### Policies

Policies are JSON documents that define:

- **Effect**: Either `Allow` or `Deny`.
- **Actions**: AWS API calls (for example `s3:GetObject`, `ec2:StartInstances`).
- **Resources**: The resources affected (for example `arn:aws:s3:::mybucket/*`).
- **Conditions**: Optional restrictions (time, IP range, MFA requirement).

### Trust Policies

Special JSON policies that define _who can assume a role_. Example: the EC2 service can assume an instance role.

### Temporary Credentials

Roles use short-lived credentials issued by AWS (via STS). These are automatically rotated and injected into the resource (for example via EC2 Instance Metadata Service).

---

## 3. Analogy to Windows and Active Directory

- **IAM Users** ≈ AD Users
- **IAM Groups** ≈ AD Groups
- **IAM Roles** ≈ Service accounts (but with auto-issued, rotating credentials)
- **IAM Policies** ≈ NTFS ACLs or Group Policy permissions
- **Trust Policies** ≈ Domain Trusts (who can log in where)

IAM is effectively **Active Directory for AWS resources**, but expressed as JSON policy docs tied to AWS API actions.

---

## 4. IAM Evaluation Logic and Precedence

Every API call to AWS is evaluated by IAM according to strict precedence rules:

1. **Implicit Deny (default)**
   - By default, all requests are denied if no policy allows them.

2. **Explicit Allow**
   - If a policy explicitly allows an action on a resource, the request is allowed, unless overridden by a deny.

3. **Explicit Deny (highest precedence)**
   - If any policy explicitly denies the action, that deny always overrides any allow.

### Example

User has two policies:

Allow policy:

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::general-bucket/*"
}
```

Deny policy:

```json
{
  "Effect": "Deny",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::sensitive-bucket/*"
}
```

Result:

- `general-bucket`: Allowed.
- `sensitive-bucket`: Denied (explicit deny overrides allow).

**Key takeaway**: Explicit Deny always wins.

---

## 5. As Simple as Read/Write

At its simplest, IAM is like filesystem permissions:

- Allow or Deny
- On specific resources
- For specific actions

Example: read-only access to an S3 bucket:

```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject"],
  "Resource": "arn:aws:s3:::mybucket/*"
}
```

---

## 6. Real-World Examples with Why

### Example 1: EC2 Instance with IAM Role

**How**: Attach a role to an EC2 instance that allows S3 write access. AWS injects temporary credentials into the instance.

**Why**: Without a role you would store long-lived keys on the server, which is insecure. A role provides short-lived, automatically rotated credentials.

**Goal**: Run an app on EC2 that securely uploads logs or data to S3.

---

### Example 2: ECS Task Role

**How**: Attach a task role to an ECS container with DynamoDB access permissions.

**Why**: Containers need AWS credentials to call APIs. Baking static keys into images risks secret leakage. Task roles inject temporary credentials at runtime.

**Goal**: Allow a containerised microservice to safely query DynamoDB.

---

### Example 3: Cross-Account Access

**How**: Create a role in the Prod account that Dev users can assume. The role allows S3 read access.

**Why**: Many organisations separate Dev, Test, and Prod into different AWS accounts. Sometimes Dev users need Prod data. Rather than duplicating users or sharing keys, Dev users assume a role that grants just the required permissions.

**Goal**: Enable secure data sharing across accounts without long-lived keys.

---

### Example 4: GitHub Actions with OIDC

**How**: Configure a role that trusts GitHub’s OIDC identity provider. Workflows assume the role dynamically during a run.

**Why**: CI/CD pipelines often need to deploy to AWS. Storing long-lived access keys in GitHub secrets is a security risk. OIDC provides short-lived credentials tied to specific repos and branches.

**Goal**: Let GitHub Actions securely deploy apps to AWS (for example update ECS services, push to ECR, or upload to S3) without managing static secrets.

---

## CI/CD → ECS permissions

See the runbook for diagnosing and unblocking ECS Deploy permissions:
- `docs/runbooks/cicd-ecs-permissions.md`

---

## 7. Summary

AWS IAM is:

- A **permissions system** like RBAC or NTFS ACLs.
- The **identity and trust framework** for AWS services.

It ensures that:

- Default access is denied.
- Explicit allow permits access.
- Explicit deny always overrides.

Real-world usage focuses on:

- Eliminating long-lived credentials.
- Automating deployments securely.
- Enforcing least privilege.
- Enabling cross-account and service-to-service access safely.

IAM is the foundation of secure operations in AWS.
