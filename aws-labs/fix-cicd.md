I'll scan the server code to see where the home page string is set and then propose a minimal change to auto-detect ECS vs EKS with an env override.

[1 tool called]

I'll add a small runtime detection in `src/server.ts` that checks Kubernetes and ECS-specific env/files, with an optional env override, and update the homepage string accordingly. Then I'll run a linter check on the edited file.

[1 tool called]

I'll run a lint check on `src/server.ts` to ensure no errors were introduced.

[1 tool called]

- I added runtime detection in `src/server.ts` to auto-identify ECS vs EKS, with an optional env override. Lint is clean.

### How it works

- It checks, in order:
  - Explicit override via `DEPLOY_PLATFORM` (also accepts `RUN_PLATFORM` or `PLATFORM`): set to `ecs`, `eks`, or `kubernetes`.
  - Kubernetes/EKS signals: `KUBERNETES_SERVICE_HOST` or the service account file at `/var/run/secrets/kubernetes.io/serviceaccount/namespace`.
  - ECS signals: `ECS_CONTAINER_METADATA_URI_V4`, `ECS_CONTAINER_METADATA_URI`, or `AWS_EXECUTION_ENV` containing `ECS`.
  - Falls back to `unknown`.

- The home page line now reflects:
  - ECS: "Running on AWS ECS Fargate with:"
  - EKS: "Running on Kubernetes (EKS) with:"
  - Otherwise: "Running in container (platform unknown) with:"

- Logs now include `platform=<ecs|eks|unknown>`.

### What you can set

- Prefer `DEPLOY_PLATFORM=ecs` or `DEPLOY_PLATFORM=eks` if you want a hard override in your task definitions or Helm values.
- Otherwise, it will detect automatically in both environments.

-- YOU MUST --

- apply this to CI/CD so the correct ECS environment is used for ECS when we deploy there
- come up with the lab document for the kubernetes ci/cd (20) lab and ensure it covers everything
- apply this to the 20-cicd-eks-pipeline lab and ensure it is done properly and works

The goal is for ECS to show in the home page when we deploy there, and EKS to show in the home page when we deploy there.
