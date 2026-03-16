---
name: deploy
description: Deploy MapWise to production on GCP via Kamal 2
disable-model-invocation: false
---

Deploy MapWise to production. Before deploying:

1. Run the test suite (`bin/rails test`) and abort if any tests fail
2. Check `git status` — warn if there are uncommitted changes
3. Confirm with the user before proceeding with deployment
4. Run `bin/kamal deploy` to deploy to GCP

## Environment
- **Host**: GCP Compute Engine `e2-small` — IP set via `DEPLOY_HOST` in `.kamal/secrets`
- **Registry**: GCP Artifact Registry `us-central1-docker.pkg.dev/edy-ai-playground/mapwise`
- **Requires**: Docker Desktop running locally + `gcloud` authenticated

## Useful post-deploy commands
- `bin/kamal logs` — view production logs
- `bin/kamal console` — open Rails console on production
- `bin/kamal shell` — SSH into the container
