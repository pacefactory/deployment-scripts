# Remote fleet updates (from Windows)

The documentation for this tooling lives in
[docs/how-to/update-fleet-from-windows.md](../../docs/how-to/update-fleet-from-windows.md).

| File | Purpose |
| --- | --- |
| `install-ssh-key.ps1` | One-time setup: create a key and install it on every server |
| `update-fleet.ps1` | Routine use: run the update payload on every server, report results (parses marker protocol v2, still accepts v1) |
| `update-server.sh` | The payload that runs on each server (streamed over ssh, never copied): fetches the release with `scripts/release/fetch-release.sh`, then `build.sh -q`, `update.sh -q`, health check |
| `servers.example.txt` | Template for your server list (copy to `servers.txt`, which is gitignored) |

Servers must already hold a release install of deployment-scripts (the payload
reports `NOT MIGRATED` otherwise); convert a server with the one-liner in
[docs/how-to/install-deployment-scripts.md](../../docs/how-to/install-deployment-scripts.md).
