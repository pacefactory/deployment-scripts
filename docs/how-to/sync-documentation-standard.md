---
title: "Sync the documentation standard to service repos"
type: how-to
derived_from:
  - scripts/docs/sync-standard.sh
  - docs/DOCUMENTATION_STANDARD.md
last_verified: 2026-09-09
verified_against: 3630e2f
---

# Sync the documentation standard to service repos

## Goal

Refresh the vendored copy of `docs/DOCUMENTATION_STANDARD.md` in one or more
service repositories after the canonical file changes, or verify that the
copies have not drifted.

## Prerequisites

- [ ] A checkout of this repository at the commit whose standard you want to distribute (usually `main` after the standard PR merged).
- [ ] Local checkouts of the target service repos (`<SERVICE_REPO_DIR>`), cloned with whatever credentials you have; the script does not clone.
- [ ] For `--commit`: a git identity configured in each target checkout, and a branch checked out there that you can push.

## Steps

1. From the deployment-scripts root, write the copies. One banner comment is
   inserted after the YAML header; the rest is byte-identical to the canonical
   file:

   ```bash
   ./scripts/docs/sync-standard.sh <SERVICE_REPO_DIR> [<SERVICE_REPO_DIR>...]
   ```

   Add `--commit` to commit the file in each target on its current branch
   (message `docs: sync documentation standard <sha>`). Nothing is pushed.

2. In each service repo, make sure `docs/README.md` lists
   `DOCUMENTATION_STANDARD.md` as "vendored copy of the Pacefactory
   documentation standard; do not edit". The script prints a reminder when the
   entry is missing.

3. Push each service repo branch and open its pull request.

## Verify

```bash
./scripts/docs/sync-standard.sh --check <SERVICE_REPO_DIR> [<SERVICE_REPO_DIR>...]
```

Prints `ok` per repo with the synced commit, exits 1 and shows a diff when a
copy is missing, lacks the banner, or differs from the canonical file. The same
command is suitable for a service repo's CI when the job has read access to
deployment-scripts.

## Rollback

`git checkout -- docs/DOCUMENTATION_STANDARD.md` in the target checkout, or
revert the sync commit.

## Related

- [Documentation standard §11](../DOCUMENTATION_STANDARD.md#11-vendored-copies-in-service-repos)
