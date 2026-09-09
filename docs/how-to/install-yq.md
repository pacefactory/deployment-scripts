---
title: Install yq
type: how-to
derived_from:
  - scripts/installYq.sh
  - scripts/common/runYq.sh
  - scripts/Dockerfile.build
last_verified: 2026-09-09
verified_against: ccf3768
---

# Install yq

## Goal

Put mikefarah `yq` v4 on the PATH so `build.sh` parses fragments natively
instead of pulling a container for every query.

## Prerequisites

- [ ] Egress to `github.com` (releases), or `snap` access.
- [ ] No other program named `yq` earlier on PATH. The Python `yq` wrapper (jq syntax) is incompatible: with it, `build.sh` fails every `runYq` call and produces an almost empty compose file.

## Steps

> **Ubuntu:** the snap is the shortest path:
>
> ```bash
> sudo snap install yq
> ```

> **RHEL:** and any host without snap: install the binary from GitHub to `~/bin`
> and add it to PATH. The repository script does this for your architecture
> and updates your shell rc file when needed:
>
> ```bash
> ./scripts/installYq.sh
> ```
>
> Equivalent by hand, pinning a version:
>
> ```bash
> mkdir -p ~/bin
> wget https://github.com/mikefarah/yq/releases/download/v4.50.1/yq_linux_amd64 -O ~/bin/yq
> chmod +x ~/bin/yq
> echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
> ```

Without `yq`, `build.sh` falls back to `docker run mikefarah/yq:latest` for
every query (`scripts/common/runYq.sh:26-32`), which is much slower and needs
Docker Hub access.

## Verify

```bash
yq --version   # yq (https://github.com/mikefarah/yq/) version v4.x
```

## Rollback

`rm ~/bin/yq` or `sudo snap remove yq`.

## Related

- [Build a deployment](build-a-deployment.md)
