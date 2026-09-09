---
title: "Build and update scripts"
type: reference
derived_from:
  - build.sh
  - update.sh
  - scripts/common/projectName.sh
  - scripts/common/prompts.sh
  - scripts/common/runYq.sh
  - scripts/common/volumesToScv2User.sh
  - scripts/build-mac.sh
  - scripts/Dockerfile.build
last_verified: 2026-09-09
verified_against: ccf3768
---

# Build and update scripts

What `build.sh` and `update.sh` accept, read, write and leave behind. For the
variables themselves see the [environment variable reference](environment-variables.md);
for the procedure see [Build a deployment](../how-to/build-a-deployment.md).

## `build.sh`

Assembles the enabled build profiles into one `docker-compose.yml`. Must run
from the repository root (all paths are relative). On macOS it delegates to
`scripts/build-mac.sh`, which runs the same script inside a `pf-build`
container (`build.sh:4-10`); that path is a developer convenience and is not
used in production.

### Flags

| Flag | Effect | Source |
|---|---|---|
| `-n NAME`, `--name NAME` | Compose project name. Must match `^[a-z0-9][a-z0-9_-]*$`; an invalid name aborts. | `build.sh:66-70`; `scripts/common/projectName.sh:12-14,42-45` |
| `-q`, `--quiet` | No prompts. Uses `.settings` and `.env` as they are, applies new `.env` defaults automatically, always rewrites `.settings`. | `build.sh:71-74,393-395,450-452` |
| `-d`, `--debug` | Prints the assembled `--profile` and `-f` strings before building. | `build.sh:75-78,431-435` |
| `--<profile-id>` | Enables that build profile (the fragment `compose/docker-compose.<profile-id>.yml` must exist, else exit 1). Flags can only enable, never disable. | `build.sh:79-91` |
| anything else | Collected as positional arguments and never used. | `build.sh:92-99` |

There is no dry-run or print-only mode. Every run writes the files below and
requires the docker compose plugin (`build.sh:16`); `docker compose ls` is
called for the default project name and fails harmlessly without a daemon
(`scripts/common/projectName.sh:2`). `docker compose config` itself needs no
daemon.

### Inputs

| Input | Read at | Notes |
|---|---|---|
| `.settings` | `build.sh:37` | Sourced. A `typeset -p` dump of `SCV2_PROFILES` (associative array of profile → `"true"`/`"false"`), `PROJECT_NAME`, and optionally `DOCKER_LOGOUT`, `DOCKER_PULL`. Sourcing replaces `SCV2_PROFILES` wholesale, so default-on profiles are re-applied afterwards only where `.settings` has no answer (`build.sh:39-48`). |
| `.env` | `build.sh:114-118` | Sourced into the shell **and** passed to compose as `--env-file .env`. Any variable already exported in the calling shell is also visible to both. |
| `compose/docker-compose.*.yml` | `build.sh:301` | Iterated in glob (alphabetical) order; `x-pf-info` metadata drives prompts (see [profile metadata](profile-metadata.md)). |
| `/proc/meminfo` | `build.sh:123` | Host RAM chooses the `MONGO_*_DEFAULT` values. |
| Interactive answers | throughout | Skipped in quiet mode. |

### Selection algorithm

1. Defaults: `social`, `rdb`, `node-red`, `mqtt-public`, `mqtts-public` are
   marked true unless `.settings` already answers them (`build.sh:30-48`).
2. Forced: `base`, `custom`, `tools`, `expresso-010` are set true and marked
   skip-prompt (`build.sh:51-58`).
3. For each fragment in alphabetical order (`build.sh:301-378`): skip if
   `x-pf-info.sub-profile: true`; prompt unless quiet or skip-prompt; if
   enabled, append `--profile <id>` and `-f <fragment>`, then prompt its
   `sub-profiles` (`build.sh:185-249`), load its settings
   (`build.sh:139-181`), and force-enable its `required-profiles`
   (`build.sh:255-287`), retroactively if they were already passed over.
4. Settings: for each `x-pf-info.settings` key, hidden settings take their
   default; others are prompted with `default_var`'s value or `default` as the
   suggestion; every non-empty value is appended to `.env.new`
   (`build.sh:139-181`). In quiet mode nothing is prompted, so a
   non-hidden setting is written only if it already had a value.
5. `.env.new` replaces `.env` (previous kept as `.env.backup`); interactively
   the diff is confirmed first (`build.sh:380-424`).
6. `docker compose --project-name … --env-file .env --profile … -f … config > docker-compose.yml`
   (`build.sh:437-442`). The exit code of `docker compose config` is **not**
   checked; a failed config leaves an empty or partial file and build.sh still
   exits 0 (the fleet payload validates the file for this reason).
7. `.settings` is rewritten (always in quiet mode, on confirmation otherwise)
   (`build.sh:444-465`).

### Outputs

| File | Content |
|---|---|
| `docker-compose.yml` | Fully resolved compose file (variables interpolated, relative paths made absolute, `x-pf-info` merged in). Gitignored. |
| `.env` | Settings with a value; `.env.backup` is the previous version. Gitignored. |
| `.settings` | Profile selection and project name. Gitignored. |

### Exit codes

`0` normal (also after a failed `docker compose config`); `1` missing docker
compose, invalid `--<profile>`, invalid project name; `2` user declined the
`.env` change.

### Requirements and pitfalls

- mikefarah `yq` v4 on PATH, or Docker access to pull `mikefarah/yq:latest`
  (`scripts/common/runYq.sh`). The Python `yq` wrapper (jq-based) is also
  installed as `yq` on some systems; with it, every `runYq` call fails and the
  profile loop aborts silently after the first profile with settings, producing
  a compose file with almost nothing in it. Check with `yq --version`.
- `compose/docker-compose.custom.yml`, if present, is merged in alphabetical
  position (after `base`, before `expresso-010`), so later fragments override
  it.
- Bind-mount paths and `${HOME}` are baked into the output for the machine that
  ran the build.

## `update.sh`

Pulls images and (re)launches the project. Reads `.settings` for
`PROJECT_NAME`, `DOCKER_PULL`, `DOCKER_LOGOUT` (`update.sh:3-4`).

| Flag | Effect | Source |
|---|---|---|
| `-n NAME`, `--name NAME` | Project name (validated as for build.sh). | `update.sh:11-15` |
| `-q`, `--quiet` | No prompts; passes `--quiet` to `docker compose pull`. | `update.sh:16-19,89-92` |
| `-d`, `--debug` | Sets `DEBUG` (unused by update.sh). | `update.sh:20-23` |
| `--logout VALUE` | Sets `DOCKER_LOGOUT` (`true`/`false`); prompted otherwise, default `false`. | `update.sh:24-28,130-141` |
| `--pull VALUE` | Sets `DOCKER_PULL` (`true`/`false`); prompted otherwise, default `true`. | `update.sh:29-33,71-73` |

Sequence: optional reconfigure (runs `./build.sh --name "$PROJECT_NAME"`,
forced when `docker-compose.yml` is missing, `update.sh:54-67`) → `docker login`
and `docker compose pull` when pulling (`update.sh:75-99`) → on success,
`scripts/common/volumesToScv2User.sh` chowns the listed volumes to uid 1234
(`update.sh:105-109`) → `docker compose up --detach --remove-orphans` →
`nginx -s reload` in the apigateway (`update.sh:111-121`). A failed pull skips
the `up` step but `update.sh` still exits 0; "Deployment complete" is printed
only on the success path (`update.sh:124`).
