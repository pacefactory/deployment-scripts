---
title: "Build a deployment"
type: how-to
derived_from:
  - build.sh
  - scripts/common/projectName.sh
  - scripts/common/runYq.sh
  - compose/docker-compose.ape.yml
  - compose/docker-compose.audit-perf-eval.yml
  - compose/docker-compose.autozone.yml
  - compose/docker-compose.base.yml
  - compose/docker-compose.cuda.yml
  - compose/docker-compose.expresso-010.yml
  - compose/docker-compose.expresso-020-cuda.yml
  - compose/docker-compose.expresso-030-trainer.yml
  - compose/docker-compose.https-digitalocean.yml
  - compose/docker-compose.https-godaddy.yml
  - compose/docker-compose.https-manual.yml
  - compose/docker-compose.https-no-certbot.yml
  - compose/docker-compose.mqtt-public.yml
  - compose/docker-compose.mqtts-public.yml
  - compose/docker-compose.node-red.yml
  - compose/docker-compose.ntfy.yml
  - compose/docker-compose.offline.yml
  - compose/docker-compose.rdb.yml
  - compose/docker-compose.service-ports.yml
  - compose/docker-compose.social.yml
  - compose/docker-compose.swift-labeler.yml
  - compose/docker-compose.tools.yml
last_verified: 2026-09-09
verified_against: ccf3768
---

# Build a deployment

## Goal

Produce the `docker-compose.yml` for this host by choosing build profiles and
answering their settings.

## Prerequisites

- [ ] Linux host with Docker and the docker compose plugin (`docker compose version`).
- [ ] mikefarah `yq` v4 on PATH (`yq --version` prints `yq (https://github.com/mikefarah/yq/) version v4…`), or Docker access to pull `mikefarah/yq:latest`. See [Install yq](install-yq.md). If `yq --version` prints a jq-style version, that is the Python wrapper; `build.sh` will silently produce an almost empty compose file with it.
- [ ] Repository checked out at `~/scv2/git_clones/deployment-scripts` (the path the fleet tooling and reference deployments assume).
- [ ] For `https-*` profiles: credentials or certificate files in place first (see [Enable HTTPS](enable-https.md)).
- [ ] `<PROJECT_NAME>`: lowercase letters, digits, `-`, `_`, starting with a letter or digit. Default `deployment-scripts`.

## Steps

1. Change to the repository root:

   ```bash
   cd ~/scv2/git_clones/deployment-scripts
   ```

2. Run the build script interactively:

   ```bash
   ./build.sh
   ```

   Confirm the project name, then answer `y`, `n` or `?` (help) for each
   prompted profile. Forced profiles (`base`, `tools`, `expresso-010`) are not
   asked. Sub-profiles (CUDA, plain MQTT, MQTTS) are asked right after their
   parent. Settings prompts show the default in brackets; press Enter to keep
   it.

   To pre-enable a profile from the command line add `--<profile-id>`, for
   example `./build.sh --ape`. Flags can only enable.

3. Review the `.env` diff the script prints when settings changed, and answer
   `y` to write it. The previous file is kept as `.env.backup`.

4. Answer `y` to "Save settings" so `.settings` records the selection for the
   next quiet run.

5. To rebuild later without prompts (same selection and values):

   ```bash
   ./build.sh -q
   ```

   Quiet runs apply new default settings automatically and always rewrite
   `.settings`.

## Verify

```bash
test -s docker-compose.yml && grep -q '^services:' docker-compose.yml && echo OK
docker compose config --services | sort
```

The service list must match the profiles you enabled (compare with the
[profile catalog](../architecture/profiles/README.md)). `build.sh` does not check
the exit code of `docker compose config`, so an empty file means the config
step failed: re-run with `-d` to see the assembled command and run it by hand
for the error.

## Rollback

`mv .env.backup .env` restores the previous settings; re-run `./build.sh -q`.

## Related

- [Build and update scripts reference](../reference/build-script.md)
- [Environment variable reference](../reference/environment-variables.md)
- [Update a deployment](update-a-deployment.md)
