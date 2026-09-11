---
title: "Publish a deployment-scripts release"
type: how-to
derived_from:
  - .github/workflows/ci.yml
  - scripts/release/stage.sh
  - scripts/release/Dockerfile
  - scripts/release/fetch-release.sh
last_verified: 2026-09-11
verified_against: 8d85e22
---

# Publish a deployment-scripts release

## Goal

Get a new version of the scripts tree onto Docker Hub as
`pacefactory/deployment-scripts:<tag>` so servers can fetch it with
`fetch-release.sh` or the install one-liner.

## Prerequisites

- [ ] Write access to `pacefactory/deployment-scripts` on GitHub (merge to `main`, push tags).
- [ ] The organization-level GitHub Actions variable `DOCKER_USER` and secret `DOCKER_PAT` exist and can push to the Docker Hub repository (`.github/workflows/ci.yml:90-94`). They are shared with the service repos; no repository-level secret is used. `TODO(source)`: who owns them and how they are rotated is outside this repository.
- [ ] A Docker Hub login that can pull the image, to verify (any server's token, or your own).
- [ ] For a versioned release: the version `<X.Y.Z>` and a release note for [`docs/upgrade-notes.md`](../upgrade-notes.md) if behaviour changed.

## Steps

1. Merge to `main`. Every push to `main` builds the image and moves
   `latest` (`.github/workflows/ci.yml:21-23,64-70`). Servers that used to
   follow `main` with `git pull` now follow `latest`, so a merge to `main` is
   a release to the fleet's next update.

   What the build does (`.github/workflows/ci.yml:59-107`):
   `scripts/release/stage.sh --tag <version>` assembles `scripts/release/stage/`
   from `git ls-files` using the allow-list in `scripts/release/stage.sh:61-69`
   and writes `.pf-release/MANIFEST` and `.pf-release/VERSION`; the
   `FROM scratch` Dockerfile copies that directory as the image's only layer
   (`scripts/release/Dockerfile:10-11`); `docker/build-push-action` pushes
   one `linux/amd64` image with SBOM and provenance attestations.

2. For a pinnable release, tag the merged commit and push the tag. The tag
   triggers the same workflow (`.github/workflows/ci.yml:23`):

   ```bash
   git tag -a v<X.Y.Z> -m "deployment-scripts v<X.Y.Z>"
   git push origin v<X.Y.Z>
   ```

3. Resulting tags (`.github/workflows/ci.yml:64-70`):

   | Event | Tags pushed |
   |---|---|
   | push to `main` | `main`, `latest`, `sha-<short commit>` |
   | tag `v<X.Y.Z>` | `<X.Y.Z>`, `<X.Y>`, `sha-<short commit>` |
   | `workflow_dispatch` on a branch | `<branch>`, `sha-<short commit>` |
   | pull request | `pr-<n>` is computed but nothing is pushed (`.github/workflows/ci.yml:102`) |

   `sha-<short>` is immutable and exists for every build; it is the rollback
   target when no `v*` tag fits. `PF_RELEASE` on a server accepts any of them
   (`scripts/release/fetch-release.sh:53`).

4. Pull requests to `main` run the lint and unit test path instead of a push:
   `shellcheck` and `bash -n` on the release scripts,
   `scripts/dev/test-fetch-release.sh`, a manifest check against the
   include/exclude rules, and a build without push (`.github/workflows/ci.yml:48-86`).
   Drafts are skipped (`.github/workflows/ci.yml:39`).

## Verify

From any machine logged in to Docker Hub with pull access:

```bash
docker pull pacefactory/deployment-scripts:<TAG>
cid=$(docker create pacefactory/deployment-scripts:<TAG> /pf-release)
docker cp "$cid:/.pf-release/VERSION" - | tar -xO
docker cp "$cid:/.pf-release/MANIFEST" - | tar -xO | wc -l
docker rm "$cid" >/dev/null
```

`VERSION` must show the expected `TAG` and the merged `COMMIT`
(`scripts/release/stage.sh:90-95`). The manifest must contain no `docs/`,
`scv2_base_images/`, `CLAUDE.md`, `.claude/`, `.github/`, `scripts/docs/` or
`scripts/dev/` entries: everything in the image is readable by every customer
machine token (`scripts/release/stage.sh:21-24`). On a server,
`./scripts/release/fetch-release.sh --check` exits 3 once the new release is
visible.

## Rollback

Servers roll back by fetching an older tag
(`PF_RELEASE=<TAG> ./scripts/release/fetch-release.sh`, see
[Install or repair](install-deployment-scripts.md#rollback)). To move `latest`
back, revert the offending commit on `main` and let CI rebuild; do not retag
by hand.

## Related

- [Install or repair deployment-scripts on a server](install-deployment-scripts.md)
- [Update a deployment](update-a-deployment.md)
- [Container registry egress](../architecture/integrations/registry-egress.md)
