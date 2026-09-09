---
title: "Profile: https-godaddy"
type: reference
derived_from:
  - compose/docker-compose.https-godaddy.yml
  - build.sh
  - scripts/docs/flows.tsv
  - scripts/docs/services.tsv
last_verified: 2026-09-09
verified_against: def9139
---

# Profile: `https-godaddy`

**Display name:** HTTPS (GoDaddy)

Provision HTTPS certificate via letsencrypt. You MUST have already updated ./credentials/godaddy/credentials.ini with the appropriate secret and key. Clients that connect over plain HTTP are redirected to HTTPS. The mqtts-public sub-profile (default-enabled) reuses the cert to expose MQTTS on port 8883.

| Attribute | Value |
|---|---|
| Fragment | `compose/docker-compose.https-godaddy.yml` |
| Class | prompted, default off |
| Prompt | Enable HTTPS (via godaddy DNS, pacefactory.com domain) |
| Parent profile(s) | none |
| Sub-profiles | [`mqtts-public`](mqtts-public.md) |
| Requires (`required-profiles`) | none |
| Required by | none |
| Conflicts with (inferred) | `https-digitalocean` (same container name certbot; same host port 443)<br>`https-manual` (same container name certbot; same host port 443)<br>`https-no-certbot` (same host port 443) |

## Services added

| Service | Node ID | Image | Owning repo | Purpose |
|---|---|---|---|---|
| `certbot` | `certbot` | `miigotu/certbot-dns-godaddy` | [certbot](https://hub.docker.com/r/certbot/certbot) (third-party) | On-demand Let's Encrypt client (image varies by https-* profile) |

## Services modified from other profiles

| Service | Home profile | Keys this profile adds or overrides |
|---|---|---|
| `apigateway` | [`base`](base.md) | ports, volumes, environment |

## Networks and volumes added

- Networks: none
- Named volumes: certbot

## Settings (`x-pf-info.settings`)

| Variable | Default (as written) | Hidden | default_var | Description |
|---|---|---|---|---|
| `SERVER_NAME` | `""` | false |  | Final domain name will be SERVER_NAME.pacefactory.com |
| `LETSENCRYPT_EMAIL` | `""` | false |  | Email address to use for letsencrypt.com |
| `HTTPS_PORT` | `443` | false |  | (none in fragment) |
| `MQTTS_CERT_SOURCE` | `certbot` | true |  | (none in fragment) |
| `MQTTS_FQDN_SUFFIX` | `.pacefactory.com` | true |  | (none in fragment) |

See the [environment variable reference](../../reference/environment-variables.md) for where each value reaches.

## Inputs / Outputs

Flows this profile originates or terminates. Node IDs are defined in the [glossary](../glossary.md).

| From | To | Direction | Protocol | Port / endpoint / topic / table | Payload | Trigger | Profile | Details |
|---|---|---|---|---|---|---|---|---|
| `certbot` | `ext_acme` | out | HTTPS | acme-v02.api.letsencrypt.org TODO(source) | ACME certificate order | on demand | https-godaddy | source: `compose/docker-compose.https-godaddy.yml:32-50`; [link](https://eff-certbot.readthedocs.io/) |
| `certbot` | `ext_dns_api` | out | HTTPS | GoDaddy API (credentials/godaddy/credentials.ini) | DNS-01 TXT record | on demand | https-godaddy | source: `compose/docker-compose.https-godaddy.yml:36-41,55`; [link](https://github.com/miigotu/certbot-dns-godaddy) |
| `certbot` | `vol_certbot` | internal | file | /etc/letsencrypt | issued certificate and key | on demand | https-godaddy | source: `compose/docker-compose.https-godaddy.yml:56,62`; [link](https://eff-certbot.readthedocs.io/) |
| `ext_web_clients` | `apigateway` | in | HTTPS | host port HTTPS_PORT (default 443) | web UI and API traffic (TLS) | on demand | https-godaddy | source: `compose/docker-compose.https-godaddy.yml:59-60`; [link](https://github.com/pacefactory/scv2_apigateway/blob/main/docs/architecture/README.md) |

## Diagram

Source: [`https-godaddy.mmd`](https-godaddy.mmd). Dashed boxes are services from optional profiles; hexagons are external systems.

```mermaid
flowchart LR
  classDef optional stroke-dasharray: 5 5
  subgraph deployment["services touched by profile https-godaddy"]
    certbot["certbot (profile: https-digitalocean)"]
    vol_certbot[("volume: certbot")]
    apigateway["apigateway"]
  end
  ext_acme{{"Let's Encrypt (ACME)"}}
  ext_dns_api{{"DNS provider API (DigitalOcean, GoDaddy)"}}
  ext_web_clients{{"Web browsers and API clients"}}
  certbot -->|"HTTPS: ACME certificate order"| ext_acme
  certbot -->|"HTTPS: DNS-01 TXT record"| ext_dns_api
  certbot -->|"file: issued certificate and key"| vol_certbot
  ext_web_clients -->|"HTTPS: web UI and API traffic (TLS)"| apigateway
  class certbot optional
```
