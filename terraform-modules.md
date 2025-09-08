# Terraform Modules: Small & Composable vs Big & Turn‑key

A practical guide for designing Terraform modules you can live with in production.

---

## TL;DR

- **Small, composable modules** ("Lego bricks") are usually easier to read, test, and evolve.
- **Big, turn‑key modules** ("prefab kits") can be fast to start but are harder to customise and debug.
- **Environment differences** (dev/staging/prod) should live **in stacks** via inputs/vars, not hard‑wired in modules.
- **Make modules flexible, not bloated**: expose inputs you genuinely need; prefer composition over long toggle lists.

---

## Core principles

1. **A module is just a folder with `.tf` files.** Size doesn’t make it special.
2. **Inputs are your API.** Use `variables.tf` to expose only what consumers must decide.
3. **Outputs are your contract.** Use `outputs.tf` to return IDs/ARNs/attributes other code needs.
4. **Locals keep it DRY.** Use `locals.tf` for naming, tagging, and computed values.
5. **Be explicit with opinions.** Document defaults and trade‑offs in `README.md`.

---

## Standard layout (recommended)

```
modules/
  <module-name>/
    main.tf
    variables.tf
    outputs.tf
    locals.tf
    versions.tf
    README.md
    examples/
      basic/
        main.tf
```

- Keep the root of your repo for **stacks/environments**; keep reusable code under `modules/`.

---

## Environment strategy (dev/staging/prod)

### Recommended layout

```
stacks/
  dev/
    main.tf
    terraform.tfvars
  staging/
    main.tf
    terraform.tfvars
  prod/
    main.tf
    terraform.tfvars
modules/
  ...
```

- **Per‑env stacks** isolate state and blast radius.
- Use **per‑env `terraform.tfvars`** (or `*.auto.tfvars`) to feed different values into the same modules.

### Example: differing settings by environment

**`stacks/dev/terraform.tfvars`**

```hcl
name            = "dev"
region          = "ap-southeast-2"
enable_nat      = false
azs             = ["ap-southeast-2a", "ap-southeast-2b"]
vpc_cidr        = "10.20.0.0/16"
endpoints       = { s3 = true, dynamodb = true }
public_ingress  = ["0.0.0.0/0"]
instance_type   = "t3.small"
```

**`stacks/staging/terraform.tfvars`**

```hcl
name            = "staging"
region          = "ap-southeast-2"
enable_nat      = true
azs             = ["ap-southeast-2a", "ap-southeast-2b"]
vpc_cidr        = "10.30.0.0/16"
endpoints       = { s3 = true, dynamodb = true }
public_ingress  = ["203.0.113.0/24"]
instance_type   = "t3.large"
```

**`stacks/dev/main.tf` & `stacks/staging/main.tf`** (same code, different vars)

```hcl
provider "aws" { region = var.region }

module "network" {
  source      = "../../modules/vpc-complete"   # or compose small modules
  name        = var.name
  cidr        = var.vpc_cidr
  azs         = var.azs
  enable_nat  = var.enable_nat
  endpoints   = var.endpoints
}

module "app" {
  source          = "../../modules/app"         # your app infra
  vpc_id          = module.network.vpc_id
  public_ingress  = var.public_ingress
  instance_type   = var.instance_type
}
```

### Pattern catalogue: ways to vary by environment

1. **Per‑env var files**: simplest, most explicit.
2. **Maps keyed by env** inside a stack:

   ```hcl
   variable "env" { type = string }
   locals {
     instance_type = {
       dev = "t3.small"
       staging = "t3.large"
       prod = "m6i.large"
     }[var.env]
   }
   ```

3. **Conditional resources** via `count`/`for_each`:

   ```hcl
   resource "aws_nat_gateway" "this" {
     count = var.enable_nat ? length(var.public_subnet_ids) : 0
     # ...
   }
   ```

4. **Composition**: choose different combinations of small modules per env.
5. **Separate stacks or even repos for prod** for stronger guardrails.
6. **Workspaces**: okay for sandboxes, but prefer directories for clarity & isolation.

### When to add a new module input vs split modules

- Add an **input** when the resource set stays the same but _parameters differ_ (e.g. instance size, ingress CIDR).
- **Split/compose** when environments truly need _different resource topology_ (e.g. NAT per‑AZ in staging/prod, none in dev).
- Avoid giant modules with dozens of flags; they’re hard to test and reason about.

---

## Approach A — Small, composable modules (recommended) — Small, composable modules (recommended)

### Folder structure

```
modules/
  vpc-core/           # VPC + Internet Gateway + DHCP options
  vpc-subnets/        # Private/public subnets per AZ
  vpc-routing/        # Route tables, associations
  nat-gateway/        # NATs, EIPs
  vpc-endpoints/      # Interface/Gateway endpoints
stacks/
  dev/
    main.tf
```

### Example modules

**`modules/vpc-core/main.tf`** (excerpt)

```hcl
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "name" { type = string }
variable "cidr" { type = string }

locals {
  tags = {
    Name        = var.name
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = local.tags
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = local.tags
}

output "vpc_id" { value = aws_vpc.this.id }
output "igw_id" { value = aws_internet_gateway.this.id }
```

**`modules/vpc-subnets/main.tf`** (excerpt)

```hcl
variable "vpc_id" { type = string }
variable "azs"    { type = list(string) }
variable "cidrs_public"  { type = list(string) }
variable "cidrs_private" { type = list(string) }

resource "aws_subnet" "public" {
  for_each                = toset(var.azs)
  vpc_id                  = var.vpc_id
  cidr_block              = var.cidrs_public[index(var.azs, each.value)]
  availability_zone       = each.value
  map_public_ip_on_launch = true
  tags = {
    Name = "public-${each.value}"
  }
}

resource "aws_subnet" "private" {
  for_each          = toset(var.azs)
  vpc_id            = var.vpc_id
  cidr_block        = var.cidrs_private[index(var.azs, each.value)]
  availability_zone = each.value
  tags = {
    Name = "private-${each.value}"
  }
}

output "public_subnet_ids"  { value = values(aws_subnet.public)[*].id }
output "private_subnet_ids" { value = values(aws_subnet.private)[*].id }
```

**`modules/nat-gateway/main.tf`** (excerpt)

```hcl
variable "public_subnet_ids" { type = list(string) }
variable "enable_per_az"     { type = bool, default = true }

resource "aws_eip" "this" {
  count      = var.enable_per_az ? length(var.public_subnet_ids) : 1
  domain     = "vpc"
}

resource "aws_nat_gateway" "this" {
  count         = length(aws_eip.this)
  subnet_id     = var.public_subnet_ids[count.index]
  allocation_id = aws_eip.this[count.index].id
  depends_on    = [] # IGW implicit via route later
}

output "nat_gateway_ids" { value = aws_nat_gateway.this[*].id }
```

### Composed usage (root stack)

**`stacks/dev/main.tf`**

```hcl
provider "aws" { region = "ap-southeast-2" }

module "vpc" {
  source = "../../modules/vpc-core"
  name   = "dev-core"
  cidr   = "10.20.0.0/16"
}

module "subnets" {
  source         = "../../modules/vpc-subnets"
  vpc_id         = module.vpc.vpc_id
  azs            = ["ap-southeast-2a", "ap-southeast-2b"]
  cidrs_public   = ["10.20.0.0/24", "10.20.1.0/24"]
  cidrs_private  = ["10.20.10.0/24", "10.20.11.0/24"]
}

module "nat" {
  source            = "../../modules/nat-gateway"
  public_subnet_ids = module.subnets.public_subnet_ids
  enable_per_az     = true
}
```

**Pros**

- Clear responsibilities, easier review & blast‑radius control.
- Swap parts without rewriting everything.
- Works well with separate repos and version pins per module.

**Cons**

- Slightly more wiring in stacks.
- More modules to version and release.

---

## Approach B — Big, turn‑key module (one call builds all)

### Folder structure

```
modules/
  vpc-complete/
    main.tf
    variables.tf
    outputs.tf
    README.md
    examples/basic/main.tf
```

### Example module (excerpt)

**`modules/vpc-complete/variables.tf`**

```hcl
variable "name"        { type = string }
variable "cidr"        { type = string }
variable "azs"         { type = list(string) }
variable "enable_nat"  { type = bool, default = true }
variable "endpoints"   { type = map(bool), default = { s3 = true, dynamodb = true } }
```

**`modules/vpc-complete/main.tf`** (sketch)

```hcl
module "core" {
  source = "../vpc-core"
  name   = var.name
  cidr   = var.cidr
}

module "subnets" {
  source        = "../vpc-subnets"
  vpc_id        = module.core.vpc_id
  azs           = var.azs
  cidrs_public  = [for i in range(length(var.azs)) : cidrsubnet(var.cidr, 8, i)]
  cidrs_private = [for i in range(length(var.azs)) : cidrsubnet(var.cidr, 8, i + 10)]
}

module "nat" {
  count             = var.enable_nat ? 1 : 0
  source            = "../nat-gateway"
  public_subnet_ids = module.subnets.public_subnet_ids
}

# (Optionally add vpc-endpoints, routing, SGs, etc.)

output "vpc_id"             { value = module.core.vpc_id }
output "public_subnet_ids"  { value = module.subnets.public_subnet_ids }
output "private_subnet_ids" { value = module.subnets.private_subnet_ids }
```

### Usage (root stack)

```hcl
provider "aws" { region = "ap-southeast-2" }

module "network" {
  source      = "../../modules/vpc-complete"
  name        = "dev"
  cidr        = "10.30.0.0/16"
  azs         = ["ap-southeast-2a", "ap-southeast-2b"]
  enable_nat  = true
  endpoints   = { s3 = true, dynamodb = true }
}
```

**Pros**

- Fast to adopt; one variable file, one module call.
- Consistent opinionated defaults.

**Cons**

- Harder to customise; toggles lead to complexity or forks.
- Debugging failures is more opaque.
- Risk of “do‑everything” drift.

---

## Decision guide

- **Do you need fine‑grained control or experimentation?** → Prefer **small**.
- **Is speed more important than flexibility for this domain?** → A **big** wrapper can be OK.
- **Will different teams want different shapes?** → Prefer **small**.
- **Is this a stable pattern you own?** → Consider a **big** opinionated module built from your small ones.

---

## Naming, tagging, and locals

```hcl
locals {
  resource_prefix = "oper-dev"
  common_tags = {
    Environment = "dev"
    Owner       = "platform"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "${local.resource_prefix}-logs"
  tags   = local.common_tags
}
```

- Keep names/prefixes in **locals**, not duplicated strings.
- Ensure every module accepts a `tags` map and merges it into resources that support tags.

---

## Versioning & releases

- Use **SemVer** for modules. Breaking changes ⇒ **major** version.
- Pin in consumers, e.g. `source = "git::https://…?ref=v2.3.1"` or registry `version = "~> 2.3"`.
- Changelog with **Added/Changed/Removed/Fixed**.

---

## Testing & quality

- **Lint**: `tflint` with provider rulesets.
- **Validate/format**: `terraform fmt -check` and `terraform validate` in CI.
- **Docs**: `terraform-docs` to generate README inputs/outputs.
- **Tests**: Terratest (Go) for create/verify/destroy of example stacks.

Example Terratest skeleton:

```go
func TestVpcCore(t *testing.T) {
  t.Parallel()
  terraformOptions := &terraform.Options{ TerraformDir: "../../modules/vpc-core/examples/basic" }
  defer terraform.Destroy(t, terraformOptions)
  terraform.InitAndApply(t, terraformOptions)
  vpcId := terraform.Output(t, terraformOptions, "vpc_id")
  require.NotEmpty(t, vpcId)
}
```

---

## Publishing strategy

- Keep **small modules** in their own folders (or repos) and publish versions.
- Provide a **big convenience wrapper** only if you own the opinions and commit to maintaining it.
- Include `examples/` that actually work in CI.

---

## Anti‑patterns to avoid

- **Monolithic module with hundreds of toggles**.
- **Hidden side‑effects** (creating resources you don’t output).
- **Leaking provider config** from module internals to callers.
- **No examples** or examples that aren’t tested.

---

## Migration tips (big → small)

1. Identify sub‑domains (core VPC, subnets, routing, NATs, endpoints).
2. Extract each to a small module with focused inputs/outputs.
3. Replace big module calls in stacks with the small ones incrementally.
4. (Optional) Keep a thin wrapper that composes the small modules for convenience.

---

## Checklist for a “good” module

- [ ] Clear purpose in README
- [ ] `variables.tf` with types, descriptions, sane defaults
- [ ] `outputs.tf` only for what consumers need
- [ ] `locals.tf` for naming/tags/derived values
- [ ] Example under `examples/` that passes CI
- [ ] Version pinning guidance in README
- [ ] Lint/validate/docs CI badges
