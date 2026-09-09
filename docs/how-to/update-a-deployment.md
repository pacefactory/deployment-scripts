---
title: "Update a deployment"
type: how-to
derived_from:
  - update.sh
  - scripts/common/volumesToScv2User.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# Update a deployment

## Goal

Pull the latest images and relaunch the compose project, optionally rebuilding
`docker-compose.yml` first.

## Prerequisites

- [ ] A built `docker-compose.yml` (otherwise `update.sh` runs `build.sh` for you).
- [ ] Docker Hub access from the host (egress, possibly via the corporate proxy: `source ~/connect-to-proxy.sh` first where the site uses one).
- [ ] Docker Hub credentials for `docker login`.

## Steps

1. From the repository root:

   ```bash
   cd ~/scv2/git_clones/deployment-scripts
   git pull --ff-only
   ./update.sh
   ```

2. Answer "Reconfigure deployment?" with `y` to run `build.sh` (needed after a
   `git pull` that changed fragments or defaults), `n` to keep the current
   compose file.

3. Answer "Pull from DockerHub?" (`y` default). The script runs `docker login`,
   `docker compose pull`, migrates volume ownership to uid 1234, then
   `docker compose up --detach --remove-orphans` and reloads nginx in the
   apigateway.

4. Answer "Logout from DockerHub?" (`n` default).

Non-interactive form used by the fleet tooling:

```bash
./build.sh -q && ./update.sh -q --pull true --logout false
```

## Verify

The run must print `Deployment complete`. Then:

```bash
docker compose ps
docker ps -a --filter label=com.docker.compose.project=<PROJECT_NAME> --format '{{.Names}}\t{{.Status}}'
```

Replace `<PROJECT_NAME>` with the name of the project (default:
`deployment-scripts`; the value recorded in `.settings`).

Every container is `Up` and none says `(unhealthy)`. A pull failure skips the
`up` step but still exits 0; the absence of `Deployment complete` is the signal.

## Rollback

Pin the previous image tags in `.env` (`<SERVICE>_TAG=<previous tag>`), run
`./build.sh -q` and `./update.sh -q`. Volumes are not changed by an update.

## Related

- [Build a deployment](build-a-deployment.md)
- [Build and update scripts reference](../reference/build-script.md)
- [Update the fleet from Windows](update-fleet-from-windows.md)
