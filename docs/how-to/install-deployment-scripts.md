---
title: "Install or repair deployment-scripts on a server"
type: how-to
derived_from:
  - scripts/release/fetch-release.sh
  - scripts/common/dockerLogin.sh
  - scripts/release/stage.sh
  - https://github.com/pacefactory/deploy/blob/main/install.sh
last_verified: 2026-09-11
verified_against: 8d85e22
---

# Install or repair deployment-scripts on a server

## Goal

Put the current deployment-scripts release on a server from the private
Docker Hub image `pacefactory/deployment-scripts`, or convert a server that
still holds the old `git clone`, or repair a broken install. One command does
all three.

## Prerequisites

- [ ] Linux host with Docker Engine and the docker compose plugin; the operating account (normally `pacefactory`) is in the `docker` group so `docker info` works without `sudo` (the bootstrap never uses `sudo`).
- [ ] This server's Docker Hub token in `~/scv2/docker_oat.sh`, mode 700, containing `export DOCKER_OAT=dckr_oat_...` (`scripts/common/dockerLogin.sh:5-13`). The token is a per-server Docker Organization Access Token with image-pull scope; how it is issued and named is in the Pacefactory Deployment Guide, not in this repository (`TODO(source)`: issuance procedure). A server already logged in as `pacefactory` works without the file; a legacy `pfclient` login works with a warning.
- [ ] Egress to Docker Hub over HTTPS 443 and to `get.pacefactory.dev` for the bootstrap itself (see [site requirements](../architecture/network/site-requirements.md)). Where the site uses a proxy: `source ~/connect-to-proxy.sh` first.
- [ ] Converting an existing checkout: `git status --porcelain --untracked-files=no` is empty in `~/scv2/git_clones/deployment-scripts`. The conversion refuses to overwrite modified tracked files (`scripts/release/fetch-release.sh:247-259`).
- [ ] mikefarah `yq` v4 for the `./build.sh` that follows ([Install yq](install-yq.md)).
- [ ] Optional: `<TAG>`, a release tag such as `v1.4.0` or `sha-<short>` to pin instead of `latest`.

## Steps

1. As the operating account, run the bootstrap. It never prompts; stdin is
   the script itself:

   ```bash
   curl -fsSL https://get.pacefactory.dev/install.sh | bash
   ```

   To pin a release, or install somewhere else, set variables before `bash`:

   ```bash
   curl -fsSL https://get.pacefactory.dev/install.sh | PF_RELEASE=<TAG> bash
   ```

   | Variable | Default | Effect |
   |---|---|---|
   | `PF_INSTALL_DIR` | `$HOME/scv2/git_clones/deployment-scripts` | Install root; keep the default so fleet tooling and docs keep working |
   | `PF_IMAGE` | `pacefactory/deployment-scripts` | Release image (`scripts/release/fetch-release.sh:52`) |
   | `PF_RELEASE` | `latest` | Tag to install (`scripts/release/fetch-release.sh:53`) |
   | `PF_REMOVE_GIT` | `false` | `true` deletes a converted checkout's `.git` after a successful sync (`scripts/release/fetch-release.sh:54,316-323`) |
   | `PF_OAT_FILE` | `$HOME/scv2/docker_oat.sh` | Token file (`scripts/common/dockerLogin.sh:32`) |
   | `DOCKER_OAT` | unset | Used if already exported; never pass the token as an argument |

   The bootstrap checks Docker, logs in to Docker Hub with the token file
   (`docker login -u pacefactory --password-stdin`, `scripts/common/dockerLogin.sh:81`),
   pulls the image, extracts it with `docker create` and `docker cp`, and hands
   off to the updater inside the image, `scripts/release/fetch-release.sh --from <tmp>`
   (`scripts/release/fetch-release.sh:14-15`).

2. Read the sync summary the updater prints: the release before and after,
   then one line per file added (`A`), updated (`U`) or removed (`D`)
   (`scripts/release/fetch-release.sh:280-287`). The rule is manifest-based
   (`scripts/release/fetch-release.sh:29-38`):

   - every file in the release manifest is copied, executable bits included;
   - a file is removed only if the previous manifest listed it and the new one
     does not. On a first conversion the previous manifest is `git ls-files`
     (`scripts/release/fetch-release.sh:189-196`), so paths that are not part
     of the release are removed from the server: `docs/`, `scv2_base_images/`,
     `CLAUDE.md`, `.claude/`, `.gitattributes`, `.gitignore`, `scripts/docs/`,
     `scripts/dev/` (`scripts/release/stage.sh:21-24,61-69`). Read the docs on
     GitHub from now on;
   - everything else is left alone: `.env`, `.settings`, `docker-compose.yml`,
     `credentials/*/credentials.ini`, SSL material, `scripts/remote/servers.txt`,
     `compose/docker-compose.custom.yml` and any other site fragment.

   `.git` stays unless `PF_REMOVE_GIT=true`; git commands in the directory are
   no longer meaningful after conversion.

3. Continue with the normal build and update, which the bootstrap does not
   run (`scripts/release/fetch-release.sh:326-332`):

   ```bash
   cd ~/scv2/git_clones/deployment-scripts
   ./build.sh
   ./update.sh
   ```

Routine updates afterwards do not use the bootstrap; see
[Update a deployment](update-a-deployment.md).

## Verify

```bash
cat ~/scv2/git_clones/deployment-scripts/.pf-release/VERSION
~/scv2/git_clones/deployment-scripts/scripts/release/fetch-release.sh --check
```

`VERSION` shows `TAG`, `COMMIT`, `BUILT_AT` and `IMAGE` (`scripts/release/stage.sh:90-95`).
`--check` prints `Up to date.` and exits 0 when the install matches the
published release; exit 3 means a newer release is available, 4 means a
conversion is blocked by modified tracked files (`scripts/release/fetch-release.sh:40-46`).

## Rollback

Fetch an older release; the sync removes files the older manifest does not
have and restores the older contents, and leaves site files alone:

```bash
cd ~/scv2/git_clones/deployment-scripts
PF_RELEASE=<TAG> ./scripts/release/fetch-release.sh
./build.sh -q && ./update.sh -q --pull true --logout false
```

Every build publishes an immutable `sha-<short>` tag and every release a
`vX.Y.Z` tag ([Publish a deployment-scripts release](publish-a-release.md)).
`latest` follows the default branch, so a server left on `latest` returns to
the newest release on its next fetch.

## Troubleshooting

- `docker info` fails: add the account to the `docker` group and log in again;
  the bootstrap prints the exact command.
- `could not pull pacefactory/deployment-scripts:<tag>`: the server's token may
  have been revoked or may lack image-pull scope on the repository, or the tag
  does not exist. Check `~/scv2/docker_oat.sh` against the Deployment Guide and
  re-run the one-liner (`scripts/release/fetch-release.sh:132-140`).
- `refusing to convert the git checkout`: commit, stash or revert the listed
  files, then re-run.
- The site forbids pipe-to-shell: download `install.sh` and
  `install.sh.sha256`, run `sha256sum -c install.sh.sha256`, then
  `bash install.sh` (documented in the
  [deploy repository README](https://github.com/pacefactory/deploy/blob/main/README.md)).

## Related

- [Update a deployment](update-a-deployment.md)
- [Publish a deployment-scripts release](publish-a-release.md)
- [Container registry egress](../architecture/integrations/registry-egress.md)
- [Upgrade notes](../upgrade-notes.md)
