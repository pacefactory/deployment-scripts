---
title: "Update a deployment"
type: how-to
derived_from:
  - update.sh
  - scripts/common/volumesToScv2User.sh
  - scripts/release/fetch-release.sh
  - scripts/common/dockerLogin.sh
last_verified: 2026-09-11
verified_against: 8d85e22
---

# Update a deployment

## Goal

Fetch the current deployment-scripts release, then pull the latest images and
relaunch the compose project, optionally rebuilding `docker-compose.yml` first.

## Prerequisites

- [ ] deployment-scripts installed from the release image at `~/scv2/git_clones/deployment-scripts` ([Install or repair deployment-scripts on a server](install-deployment-scripts.md)). A server that still holds the old `git clone` must be converted first with the same one-liner.
- [ ] A built `docker-compose.yml` (otherwise `update.sh` runs `build.sh` for you).
- [ ] Docker Hub access from the host (egress, possibly via the corporate proxy).
- [ ] The server's Docker Hub token in `~/scv2/docker_oat.sh` and a standing login as `pacefactory` (`scripts/common/dockerLogin.sh:5-13`). `update.sh` runs a bare `docker login` (`update.sh:79`), which re-uses the stored login; `fetch-release.sh` re-logs in with the token file only if its pull fails (`scripts/release/fetch-release.sh:124-131`). Token issuance is in the Pacefactory Deployment Guide (`TODO(source)`).

## Steps

1. From the install directory, after the proxy hook where the site has one:

   ```bash
   source ~/connect-to-proxy.sh   # only on sites with an egress proxy
   cd ~/scv2/git_clones/deployment-scripts
   ./scripts/release/fetch-release.sh
   ./build.sh
   ./update.sh
   ```

   `fetch-release.sh` replaces `git pull --ff-only`: it pulls
   `pacefactory/deployment-scripts:latest`, syncs the tree by manifest and
   prints what changed and the release before and after
   (`scripts/release/fetch-release.sh:9-13,280-287`). Site files (`.env`,
   `.settings`, `docker-compose.yml`, credentials, custom fragments) are never
   touched. It does not run `build.sh` or `update.sh` itself.

2. Answer "Reconfigure deployment?" with `y` to run `build.sh` (needed after a
   fetch that changed fragments or defaults), `n` to keep the current compose
   file.

3. Answer "Pull from DockerHub?" (`y` default). The script runs `docker login`,
   `docker compose pull`, migrates volume ownership to uid 1234, then
   `docker compose up --detach --remove-orphans` and reloads nginx in the
   apigateway.

4. Answer "Logout from DockerHub?" (`n` default). Keep `n`: the server must
   stay logged in as `pacefactory` for the next fetch and pull.

Non-interactive form used by the fleet tooling:

```bash
./scripts/release/fetch-release.sh && ./build.sh -q && ./update.sh -q --pull true --logout false
```

To pin or roll back the scripts tree use `PF_RELEASE=<TAG> ./scripts/release/fetch-release.sh`
(`scripts/release/fetch-release.sh:53`); `--check` reports whether a newer
release exists without changing anything (exit 3 when it does).

## Verify

The run must print `Deployment complete`. Then:

```bash
cat .pf-release/VERSION
docker compose ps
docker ps -a --filter label=com.docker.compose.project=<PROJECT_NAME> --format '{{.Names}}\t{{.Status}}'
```

Replace `<PROJECT_NAME>` with the name of the project (default:
`deployment-scripts`; the value recorded in `.settings`).

`VERSION` shows the installed release `TAG` and `COMMIT`. Every container is
`Up` and none says `(unhealthy)`. A pull failure skips the `up` step but still
exits 0; the absence of `Deployment complete` is the signal.

## Rollback

Images: pin the previous image tags in `.env` (`<SERVICE>_TAG=<previous tag>`),
run `./build.sh -q` and `./update.sh -q`. Scripts tree:
`PF_RELEASE=<TAG> ./scripts/release/fetch-release.sh` then the same two
commands. Volumes are not changed by an update.

## Troubleshooting

- `git pull` fails with an authentication or repository-not-found error: the
  repository is private and this server has not been migrated. Run the
  one-liner from [Install or repair deployment-scripts on a server](install-deployment-scripts.md)
  once; it converts the checkout in place, then use `fetch-release.sh` as above.
- `fetch-release.sh` reports `could not pull`: the server's token may have been
  revoked or lack pull scope; see the same how-to.

## Related

- [Install or repair deployment-scripts on a server](install-deployment-scripts.md)
- [Build a deployment](build-a-deployment.md)
- [Build and update scripts reference](../reference/build-script.md)
- [Update the fleet from Windows](update-fleet-from-windows.md)
