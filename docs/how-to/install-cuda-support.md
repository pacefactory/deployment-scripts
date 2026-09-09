---
title: Install CUDA support
type: how-to
derived_from:
  - compose/docker-compose.cuda.yml
  - compose/docker-compose.expresso-020-cuda.yml
  - compose/docker-compose.expresso-030-trainer.yml
last_verified: 2026-09-09
verified_against: ccf3768
---

# Install CUDA support

## Goal

Prepare a host so the GPU sub-profiles (`cuda`, `expresso-020-cuda`,
`expresso-030-trainer`) can reserve the NVIDIA GPU.

**Placeholder.** This page will be based on the CUDA document in the
scv2_realtime repository (`CUDA.md`, currently linked from the root README) once
that content is reviewed against the current fragments. Until then it records
only what the fragments require.

## Prerequisites

- [ ] An NVIDIA GPU on the host.
- [ ] `TODO(source)`: driver version and the NVIDIA container toolkit installation steps (RHEL and Ubuntu), from scv2_realtime.

## Steps

1. `TODO(source)`: install the NVIDIA driver and container toolkit; configure
   the Docker runtime. See
   <https://github.com/pacefactory/scv2_realtime/blob/main/CUDA.md>.

2. Build with the GPU sub-profiles. The fragments reserve all GPUs with
   `driver: nvidia`, `count: all`, capabilities `gpu, utility, compute, video`
   (`compose/docker-compose.cuda.yml:14-24`) and set
   `REALTIME_PREFER_GPU=true` / `PF_PREFER_GPU=true`; the hidden settings switch
   the realtime and expresso_server image tags to `latest-gpu`.

   ```bash
   ./build.sh   # answer y to "Enable CUDA for Realtime?", "Enable CUDA for Expresso?", and optionally the Trainer
   ./update.sh
   ```

## Verify

```bash
docker compose exec realtime nvidia-smi
grep -c 'driver: nvidia' docker-compose.yml   # 2 with both CUDA sub-profiles, 3 with the trainer
```

## Rollback

Re-run `./build.sh`, answer `n` to the CUDA prompts (the tags return to
`latest`), then `./update.sh`.

## Related

- Reference deployment [GPU variant](../architecture/reference-deployments/gpu/README.md)
