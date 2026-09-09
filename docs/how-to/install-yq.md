---
title: "Install yq"
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

On every host, install the binary from mikefarah's GitHub releases. It is
markedly faster than the snap build.

1. Run the repository script, which downloads the latest release for your
   architecture to `~/bin/yq` and adds `~/bin` to your PATH in the shell rc
   file when needed:

   ```bash
   ./scripts/installYq.sh
   ```

   Equivalent by hand:

   ```bash
   mkdir -p ~/bin
   wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O ~/bin/yq
   chmod +x ~/bin/yq
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
   ```

   Requires egress to `github.com` and `objects.githubusercontent.com`, via the
   corporate proxy where the site uses one.

> **Ubuntu:** the snap is an alternative when GitHub is unreachable, at the
> cost of slower `build.sh` runs:
>
> ```bash
> sudo snap install yq
> ```

Without `yq`, `build.sh` falls back to `docker run mikefarah/yq:latest` for
every query (`scripts/common/runYq.sh:26-32`), which is slower still and needs
Docker Hub access.

## Verify

```bash
yq --version   # yq (https://github.com/mikefarah/yq/) version v4.x
```

## Rollback

`rm ~/bin/yq` or `sudo snap remove yq`.

## Related

- [Build a deployment](build-a-deployment.md)
