# Remote fleet updates (from Windows)

The documentation for this tooling lives in
[docs/how-to/update-fleet-from-windows.md](../../docs/how-to/update-fleet-from-windows.md).

| File | Purpose |
| --- | --- |
| `install-ssh-key.ps1` | One-time setup: create a key and install it on every server |
| `update-fleet.ps1` | Routine use: run the update payload on every server, report results |
| `update-server.sh` | The payload that runs on each server (streamed over ssh, never copied) |
| `servers.example.txt` | Template for your server list (copy to `servers.txt`, which is gitignored) |
