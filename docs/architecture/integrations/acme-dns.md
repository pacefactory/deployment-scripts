---
title: "Let's Encrypt and DNS provider APIs"
type: reference
derived_from:
  - compose/docker-compose.https-digitalocean.yml
  - compose/docker-compose.https-godaddy.yml
  - compose/docker-compose.https-manual.yml
  - credentials/digitalocean/credentials.ini.example
  - credentials/godaddy/credentials.ini.example
  - scripts/docs/flows.tsv
last_verified: 2026-09-10
verified_against: ac43569
---

# Let's Encrypt (ACME) and DNS provider APIs

## What it connects to

- `ext_acme`: the Let's Encrypt certificate authority, via the ACME protocol.
- `ext_dns_api`: the DNS provider's API used to answer DNS-01 challenges:
  DigitalOcean (`https-digitalocean`) or GoDaddy (`https-godaddy`). The
  `https-manual` profile answers the challenge by hand instead.

## Which Pacefactory services participate, and via which profile(s)

- `certbot` (profiles `https-digitalocean`, `https-godaddy`, `https-manual`;
  on demand via a compose profile of the same name). Image differs per
  profile: `certbot/dns-digitalocean:latest`, `miigotu/certbot-dns-godaddy`,
  `certbot/certbot`.
- `apigateway` and `pf_mosquitto` consume the issued files from the `certbot`
  volume (read-only mounts at `/etc/nginx/ssl` and `/etc/mosquitto-tls`,
  `compose/docker-compose.https-digitalocean.yml:63`,
  `compose/docker-compose.https-godaddy.yml:62`,
  `compose/docker-compose.https-manual.yml:51`,
  `compose/docker-compose.mqtts-public.yml:22`). The flow table records the
  `vol_certbot -> pf_mosquitto` rows. TODO(source): the matching
  `vol_certbot -> apigateway` rows are missing from `scripts/docs/flows.tsv`;
  add them, with the payload the gateway reads, during the scv2_apigateway
  documentation bootstrap.

## Direction and protocol(s)

Outbound HTTPS from the deployment host to the ACME endpoint and to the DNS
API. Credentials: `credentials/digitalocean/credentials.ini`
(`dns_digitalocean_token`) or `credentials/godaddy/credentials.ini`
(`dns_godaddy_secret`, `dns_godaddy_key`), bind-mounted read-only into the
certbot container (`compose/docker-compose.https-digitalocean.yml:56`,
`compose/docker-compose.https-godaddy.yml:55`). Templates are committed as
`*.example`; real files are gitignored.

The certificate is issued for `<SERVER_NAME>.pacefactory.dev` (DigitalOcean),
`<SERVER_NAME>.pacefactory.com` (GoDaddy) or `<SERVER_NAME>` as given (manual),
with `LETSENCRYPT_EMAIL` as the account contact. Propagation waits are 60 s
(DigitalOcean) and 900 s (GoDaddy).

## Client-side network requirements

Egress from the host to Let's Encrypt and to the DNS provider API over 443,
possibly via the corporate proxy. Inbound 443 (`HTTPS_PORT`) for the web
clients. See [site requirements](../network/site-requirements.md).

## Payload summary

ACME order and DNS TXT record updates; issued `fullchain.pem` and `privkey.pem`
written to the `certbot` volume under `/etc/letsencrypt/live/<name>/`.

## Failure modes at the boundary

`certbot` is run on demand and exits; nothing in this repository schedules
renewal (`TODO(source)`: renewal procedure). While no certificate exists the
apigateway serves a temporary self-signed certificate
(`compose/docker-compose.https-no-certbot.yml:10-12` describes the same
behaviour for the file-based profile). Certbot run instructions:
[Enable HTTPS](../../how-to/enable-https.md).

## Variants

Per-provider certbot plugins: <https://certbot-dns-digitalocean.readthedocs.io/>,
<https://github.com/miigotu/certbot-dns-godaddy>.
