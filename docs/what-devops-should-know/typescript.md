# What A Senior DevOps Engineer Should Know About TypeScript (2025)

TypeScript is a typed superset of JavaScript that compiles to standard JS. For DevOps engineers in 2025, it is a core language across Infrastructure as Code, AWS SDK automation, serverless functions, CLIs, and Kubernetes tooling. Strong typing protects pipelines and production systems by catching mistakes before runtime. Official docs: TypeScript Handbook, AWS SDK v3, AWS CDK, Pulumi, cdk8s. ([TypeScript][1], [AWS Documentation][2], [pulumi][3], [cdk8s.io][4])

---

## The short version

- Use the current Node.js LTS for servers, CLIs, and Lambda. Check support and EOL before upgrades. ([endoflife.date][5])
- Prefer npm for simplicity, pnpm for monorepos and faster installs, Bun if your dev and CI images are standardised on it. ([pnpm.io][6], [GitHub][7])
- Use AWS SDK for JavaScript v3 with modular imports and first class TypeScript. ([AWS Documentation][2], [Amazon Web Services, Inc.][8])
- For IaC, AWS CDK with TypeScript on AWS, Pulumi with TypeScript for multi cloud, cdk8s with TypeScript for Kubernetes YAML. ([AWS Documentation][9], [pulumi][3], [cdk8s.io][4])
- Build and bundle with tsup or esbuild. Use tsx for local execution during development. ([tsup.egoist.dev][10], [esbuild.github.io][11], [tsx][12])
- In Lambda, use a currently supported Node runtime. Verify on the runtime page. ([AWS Documentation][13])

---

## What a type is

A type describes the shape and kind of data. It is a contract the compiler checks before your code runs.

```ts
let region: string = "ap-southeast-2";
let replicas: number = 3;
let logging: boolean = true;
```

Type errors fail your build early, which is ideal for automation and IaC. Reference: TypeScript Handbook. ([TypeScript][1])

---

## What an object is

An object is a collection of key value pairs. In TypeScript you add a type so the compiler enforces structure.

```ts
const server = {
  name: "api",
  cpu: 4,
  memoryGb: 16,
  region: "ap-southeast-2",
};
```

Almost everything you touch in DevOps is an object shaped thing: CDK props, Pulumi args, Kubernetes manifests, AWS SDK responses. CDK, Pulumi and cdk8s model these as typed objects in TypeScript. ([AWS Documentation][9], [pulumi][3], [cdk8s.io][4])

---

## Interfaces, union types, and how you actually use them

### Interfaces

An interface defines the required shape of an object and is imported where needed.

```ts
// src/types.ts
export interface DeploymentConfig {
  service: string;
  replicas: number;
  region: string;
  logging?: boolean; // optional
}
```

Use it from another module:

```ts
// src/deploy.ts
import { DeploymentConfig } from "./types.js";

export function deployApp(cfg: DeploymentConfig) {
  console.log(
    `Deploying ${cfg.service} to ${cfg.region} with ${cfg.replicas} replicas`,
  );
}
```

Call it:

```ts
// src/run-deploy.ts
import { deployApp } from "./deploy.js";

await deployApp({
  service: "web",
  replicas: 3,
  region: "ap-southeast-2",
  logging: true,
});
```

Interfaces give you autocomplete and build time checks. Handbook section covers interfaces and structural typing. ([TypeScript][1])

### Union types

A union allows a value to be one of a fixed set of possibilities. Great for safe config and CLI flags.

```ts
type Environment = "dev" | "staging" | "prod";

export interface PipelineConfig {
  name: string;
  env: Environment;
}

export const cfg: PipelineConfig = { name: "build-deploy", env: "prod" }; // safe
```

This prevents typos like "production". Handbook covers unions and narrowing. ([TypeScript][1])

### Retry helpers

APIs throttle or blip, so wrap calls with a typed retry helper.

```ts
// src/retry.ts
export interface RetryConfig {
  tries: number;
  backoffMs: number; // base delay
}

export async function retry<T>(
  fn: () => Promise<T>,
  { tries, backoffMs }: RetryConfig,
): Promise<T> {
  let last: unknown;
  for (let i = 0; i < tries; i++) {
    try {
      return await fn();
    } catch (e) {
      last = e;
      await new Promise((r) => setTimeout(r, backoffMs * Math.max(1, i)));
    }
  }
  throw last;
}
```

Use it with the modular AWS SDK v3:

```ts
// src/s3-list.ts
import { S3Client, ListBucketsCommand } from "@aws-sdk/client-s3";
import { retry } from "./retry.js";

const s3 = new S3Client({ region: "ap-southeast-2" });

export async function listBuckets() {
  return retry(
    async () => {
      const res = await s3.send(new ListBucketsCommand({}));
      return (res.Buckets ?? [])
        .map((b) => b?.Name)
        .filter(Boolean) as string[];
    },
    { tries: 5, backoffMs: 200 },
  );
}
```

SDK v3 is modular with first class TypeScript support, which keeps bundles small and types precise. ([AWS Documentation][2], [Amazon Web Services, Inc.][8])

---

## Success vs failure patterns you will actually use

You have two practical options in TypeScript. Pick one per project and be consistent.

### Exceptions with try or catch

Simple and common for scripts and Lambdas.

```ts
try {
  const buckets = await listBuckets();
  console.log("OK", buckets);
  process.exit(0);
} catch (err) {
  console.error("FAIL", err);
  process.exit(1);
}
```

Exit code 0 is success, non zero is failure. This is what CI expects.

### Result objects with discriminated unions

Useful if you want to avoid exceptions in control flow.

```ts
type Ok<T> = { ok: true; value: T };
type Err = { ok: false; error: Error };
type Result<T> = Ok<T> | Err;

export async function safeListBuckets(): Promise<Result<string[]>> {
  try {
    return { ok: true, value: await listBuckets() };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e : new Error(String(e)) };
  }
}

// call site
const r = await safeListBuckets();
if (!r.ok) {
  console.error(r.error.message);
  process.exit(1);
}
console.log(r.value);
```

Both patterns are idiomatic TypeScript. Pick exceptions for brevity or a Result type when you need explicit control.

---

## Imports, modules, and how to structure projects

Use ESM across Node in 2025.

**package.json**

```json
{
  "name": "devops-ts",
  "type": "module",
  "private": true,
  "scripts": {
    "dev": "tsx src/cli.ts",
    "build": "tsup src --format=cjs,esm --dts --sourcemap",
    "typecheck": "tsc --noEmit",
    "lint": "eslint .",
    "test": "vitest run"
  },
  "devDependencies": {
    "typescript": "^5.6.0",
    "tsup": "^8.0.0",
    "tsx": "^4.0.0",
    "eslint": "^9.0.0",
    "@typescript-eslint/parser": "^7.0.0",
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "vitest": "^2.0.0"
  }
}
```

**tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "resolveJsonModule": true,
    "esModuleInterop": true,
    "outDir": "dist",
    "declaration": true,
    "sourceMap": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

tsup bundles with esbuild and supports ESM and CJS outputs for broad compatibility. tsx runs TypeScript directly in Node for local development. ([tsup.egoist.dev][10], [esbuild.github.io][11], [tsx][12])

### Suggested directory layout

Single package layout:

```
devops-ts/
  src/
    cli.ts            # Commander CLI entrypoint
    retry.ts          # shared retry helper
    s3-list.ts        # AWS SDK helper
    deploy.ts         # business logic
    types.ts          # shared interfaces and unions
  infra/
    cdk/              # AWS CDK app in TS
    pulumi/           # Pulumi program in TS
    cdk8s/            # cdk8s app in TS to emit YAML
  lambda/
    write-to-s3/      # Lambda handler in TS
  package.json
  tsconfig.json
```

Monorepo option with pnpm workspaces:

```
devops-ts/
  packages/
    cli/
    libs-aws/
    infra-cdk/
    infra-pulumi/
    infra-cdk8s/
  pnpm-workspace.yaml
```

pnpm workspaces are built in and ideal for large repos. ([pnpm.io][6])

---

## Building a real CLI so you can call things

CLI that lists S3 buckets using Commander. Commander is a popular Node CLI framework. ([npm][14], [GitHub][15])

```ts
// src/cli.ts
#!/usr/bin/env node
import { Command } from "commander";
import { listBuckets } from "./s3-list.js";
import { safeListBuckets } from "./result-example.js"; // optional Result flow

const program = new Command();

program
  .name("devops-cli")
  .description("DevOps helper CLI in TypeScript")
  .version("1.0.0");

program
  .command("s3:list")
  .description("List S3 buckets in the configured region")
  .option("--safe", "Return success or failure via Result object")
  .action(async (opts) => {
    try {
      if (opts.safe) {
        const r = await safeListBuckets();
        if (!r.ok) {
          console.error("FAIL", r.error.message);
          process.exit(1);
        }
        console.log("OK", r.value);
        process.exit(0);
      }
      const buckets = await listBuckets();
      console.log("OK", buckets);
      process.exit(0);
    } catch (e) {
      console.error("FAIL", e);
      process.exit(1);
    }
  });

program.parseAsync(process.argv);
```

Run it in development:

```bash
npm run dev -- s3:list
# or
npx tsx src/cli.ts s3:list
```

Bundle it for distribution:

```bash
npm run build
node dist/cli.mjs s3:list
```

Commander docs and usage examples are current on npm and GitHub. ([npm][14], [GitHub][15])

---

## Real Lambda example and how it is invoked

Handler that writes a file to S3. Lambda calls your exported handler automatically.

```ts
// lambda/write-to-s3/src/handler.ts
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
const s3 = new S3Client({});

export const handler = async () => {
  await s3.send(
    new PutObjectCommand({
      Bucket: process.env.BUCKET!,
      Key: "status.txt",
      Body: "hello from lambda typescript",
    }),
  );
  return { statusCode: 200, body: "ok" };
};
```

Bundle and deploy a zip:

```bash
cd lambda/write-to-s3
npx tsup src/handler.ts --format=cjs --out-dir dist --minify
zip -j lambda.zip dist/handler.js
aws lambda update-function-code --function-name write-to-s3 --zip-file fileb://lambda.zip
```

Pick a supported Node.js runtime for Lambda. Verify supported versions before deploying. ([AWS Documentation][13])

---

## Real IaC example with AWS CDK and how you run it

```ts
// infra/cdk/lib/artifacts-stack.ts
import { Stack, StackProps, aws_s3 as s3 } from "aws-cdk-lib";
import { Construct } from "constructs";

export class ArtifactsStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);
    new s3.Bucket(this, "Artifacts", {
      versioned: true,
      encryption: s3.BucketEncryption.S3_MANAGED,
    });
  }
}
```

Deploy:

```bash
cd infra/cdk
npx cdk synth
npx cdk deploy
```

CDK TypeScript support is stable and first class. ([AWS Documentation][9])

---

## Real Kubernetes example with cdk8s and how you run it

```ts
// infra/cdk8s/main.ts
import { App, Chart } from "cdk8s";
import * as kplus from "cdk8s-plus-27";

const app = new App();
const chart = new Chart(app, "web");

new kplus.Deployment(chart, "api", {
  replicas: 2,
  containers: [{ image: "nginx:1.27" }],
});

app.synth(); // emits dist/*.k8s.yaml
```

Generate YAML and apply:

```bash
cd infra/cdk8s
cdk8s synth
kubectl apply -f dist/
```

cdk8s has a TypeScript getting started guide and API reference. ([cdk8s.io][4])

---

## Real Pulumi example and how you run it

```ts
// infra/pulumi/index.ts
import * as aws from "@pulumi/aws";
const bucket = new aws.s3.Bucket("artifacts", {
  versioning: { enabled: true },
});
export const bucketName = bucket.id;
```

Deploy and destroy:

```bash
pulumi up
pulumi destroy
```

Pulumi supports TypeScript end to end for AWS. ([pulumi][3])

---

## Installing and using TypeScript in 2025

Choose a package manager.

- npm is default and works everywhere
- pnpm is faster and space efficient with a content addressed store, ideal for monorepos
- Bun is fast and Node compatible, use when your base images and team have standardised on it

Docs: pnpm workspaces and store, Bun package manager docs, npm docs. ([pnpm.io][6], [GitHub][7])

Project initialisation with npm:

```bash
npm init -y
npm install -D typescript tsup tsx eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
npx tsc --init --strict
```

tsup bundles with esbuild under the hood. esbuild is a very fast bundler. tsx runs TS files directly for development. ([tsup.egoist.dev][10], [esbuild.github.io][11], [tsx][12])

---

## Running, testing, and CI

Local runs:

```bash
# direct run for development
npx tsx src/cli.ts s3:list

# production style run after bundling
npm run build
node dist/cli.mjs s3:list
```

Type checking, linting, tests:

```bash
npm run typecheck
npm run lint
npm test
```

GitHub Actions snippet:

```yaml
name: ci
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "lts/*" }
      - run: npm ci
      - run: npm run typecheck
      - run: npm run lint
      - run: npm test -- --run
      - run: npm run build
```

Node release status and LTS windows change over time, check the current schedule before pinning versions. ([endoflife.date][5])

---

## Deployment in AWS

Lambda

- Zip: bundle with tsup or esbuild, zip the output, update function code
- Container: build an image based on an official Lambda Node.js base, push, update function to use the image
- Confirm supported runtimes before shipping changes

Docs: Lambda runtimes page. ([AWS Documentation][13])

ECS Fargate

- Build an image that runs your compiled JS or your Node app
- Use task roles for AWS APIs and attach to an ALB
- Prefer health checks and minimum scaling to absorb spikes

EKS

- Package Node services as containers
- Generate manifests with cdk8s or use Helm
- Apply with kubectl through your pipeline

CDK pipelines

- Define pipeline stages and stacks in TypeScript
- Reuse constructs for multi account and multi region patterns

AWS CDK TS docs cover pipelines and constructs. ([AWS Documentation][9])

---

## Patterns that save you in production

- Validate external inputs. Prefer `unknown` over `any`, then narrow. Handbook explains narrowing. ([TypeScript][1])
- Use `satisfies` for config objects so types are checked without widening.

```ts
const alarm = {
  threshold: 90,
  period: 60,
} satisfies { threshold: number; period: 60 | 300 };
```

- Wrap AWS SDK calls with retries, backoff, and timeouts
- Return clear success or failure
- Exit with the correct code in CLIs so CI knows what happened

---

## Exercises for muscle memory

1. Build a CLI command `s3:list` and `ec2:list` that prints JSON and pretty tables. Use Commander and your retry helper. ([npm][14])
2. Create a `DeploymentConfig` interface, load a JSON file, assert with `satisfies`, and deploy an S3 bucket in CDK using those values. ([AWS Documentation][9])
3. Write a Lambda in TypeScript that reads a JSON from S3, transforms it, and writes to another bucket. Bundle with tsup and deploy. ([tsup.egoist.dev][10])
4. Convert a Kubernetes Deployment YAML into cdk8s TypeScript, emit YAML, and `kubectl apply`. ([cdk8s.io][4])
5. Set up a pnpm workspace with `packages/cli` and `packages/libs-aws`, share types, and cache the store in CI. ([pnpm.io][6])

---

## Troubleshooting and common pitfalls

- Mixing ESM and CJS. Use `"type": "module"` and `moduleResolution: NodeNext` then import with ESM syntax. Handbook and Node docs cover the module story. ([TypeScript][1])
- Running TS directly in production. Prefer compiled JS for Lambda and containers. Use tsx only for local development. Node’s guide notes tsx does not type check, so run `tsc --noEmit` first. ([Node.js][16])
- SDK v2 vs v3. Use v3 for modular imports and types. ([AWS Documentation][2], [Amazon Web Services, Inc.][8])
- Node version drift. Keep dev, CI, and runtime on the same LTS line. Check the current schedule. ([endoflife.date][5])

---

## Sources

- TypeScript Handbook. Credibility: High. ([TypeScript][1])
- AWS SDK for JavaScript v3 docs and announcement of first class TypeScript and modularity. Credibility: High. ([AWS Documentation][2], [Amazon Web Services, Inc.][8])
- AWS CDK in TypeScript. Credibility: High. ([AWS Documentation][9])
- Pulumi on AWS with TypeScript. Credibility: High. ([pulumi][3])
- cdk8s TypeScript getting started and API reference. Credibility: High. ([cdk8s.io][4])
- pnpm workspaces and content addressed store. Credibility: High. ([pnpm.io][6], [GitHub][7])
- tsup and esbuild getting started. Credibility: High. ([tsup.egoist.dev][10], [esbuild.github.io][11])
- tsx official site and Node guide. Credibility: High. ([tsx][12], [Node.js][16])
- Commander docs. Credibility: High. ([npm][14], [GitHub][15])
- Node release and EOL status. Credibility: Medium High for aggregator, verify with Node itself for final decisions. ([endoflife.date][5])
- Lambda runtimes page. Credibility: High. ([AWS Documentation][13])

---

[1]: https://www.typescriptlang.org/docs/handbook/intro.html "The TypeScript Handbook"
[2]: https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/ "AWS SDK for JavaScript v3"
[3]: https://www.pulumi.com/docs/iac/clouds/aws/ "AWS - Pulumi Docs"
[4]: https://cdk8s.io/docs/latest/get-started/typescript/ "TypeScript - cdk8s"
[5]: https://endoflife.date/nodejs "Node.js - endoflife.date"
[6]: https://pnpm.io/workspaces "Workspace - pnpm"
[7]: https://github.com/pnpm/pnpm/blob/main/pnpm/README.md "pnpm/pnpm/README.md at main · pnpm/pnpm · GitHub"
[8]: https://aws.amazon.com/blogs/developer/first-class-typescript-support-in-modular-aws-sdk-for-javascript/ "First-class TypeScript support in modular AWS SDK for JavaScript"
[9]: https://docs.aws.amazon.com/cdk/v2/guide/work-with-cdk-typescript.html "Working with the AWS CDK in TypeScript"
[10]: https://tsup.egoist.dev/ "tsup"
[11]: https://esbuild.github.io/getting-started/ "esbuild - Getting Started"
[12]: https://tsx.is/ "TypeScript Execute (tsx) | tsx"
[13]: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html "Lambda runtimes - AWS Lambda"
[14]: https://www.npmjs.com/package/commander "Commander.js - npm"
[15]: https://github.com/tj/commander.js/blob/master/Readme.md "commander.js/Readme.md at master · tj/commander.js · GitHub"
[16]: https://nodejs.org/en/learn/typescript/run "Running TypeScript with a runner - Node.js"
