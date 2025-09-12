# Demo App Lab

This application exists in [loftwah/demo-node-app](https://github.com/loftwah/demo-node-app). Please refer to that repository for any information on the application.

## GitHub Container Registry

[demo-node-app](https://github.com/loftwah/demo-node-app/pkgs/container/demo-node-app)

There is a CI pipeline running in GitHub Actions that builds the application and pushes the image to the GitHub Container Registry. We aren't using this for the labs, but it's a good example of how to build and push an image to a container registry.

## Self-test endpoint

- The app exposes a protected `/selftest` endpoint that performs S3, DB, and Redis CRUD and returns a JSON summary.

Example (hosted):

```
https://demo-node-app-ecs.aws.deanlofts.xyz/selftest?token=<APP_AUTH_SECRET>
```

Expected success output (shape):

```json
{
  "s3": { "ok": true, "bucket": "<bucket>", "key": "app/selftest-<ts>.txt" },
  "db": { "ok": true, "id": "<uuid>" },
  "redis": { "ok": true, "key": "selftest:<uuid>" }
}
```

Auth options:

- Query: `?token=<APP_AUTH_SECRET>`
- Header: `Authorization: Bearer <APP_AUTH_SECRET>`
