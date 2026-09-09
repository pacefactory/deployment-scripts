---
title: Enable HTTPS
type: how-to
derived_from:
  - compose/docker-compose.https-digitalocean.yml
  - compose/docker-compose.https-godaddy.yml
  - compose/docker-compose.https-manual.yml
  - compose/docker-compose.https-no-certbot.yml
  - compose/docker-compose.mqtts-public.yml
  - credentials/digitalocean/credentials.ini.example
  - credentials/godaddy/credentials.ini.example
last_verified: 2026-09-09
verified_against: ccf3768
---

# Enable HTTPS

## Goal

Serve the web UI and APIs over TLS on port 443 (and MQTTS on 8883) using one
of the four `https-*` profiles.

## Prerequisites

- [ ] Choose a profile: `https-digitalocean` (Let's Encrypt via DigitalOcean DNS, `<SERVER_NAME>.pacefactory.dev`), `https-godaddy` (via GoDaddy DNS, `<SERVER_NAME>.pacefactory.com`), `https-manual` (Let's Encrypt with a manual DNS challenge, full `<SERVER_NAME>`), or `https-no-certbot` (a certificate file you provide).
- [ ] `<SERVER_NAME>` and, for the certbot profiles, `<LETSENCRYPT_EMAIL>`.
- [ ] Egress from the host to Let's Encrypt and to the DNS provider API (certbot profiles); via the corporate proxy where applicable.
- [ ] `https-digitalocean`: `credentials/digitalocean/credentials.ini` with `dns_digitalocean_token` (template `credentials.ini.example`).
- [ ] `https-godaddy`: `credentials/godaddy/credentials.ini` with `dns_godaddy_secret` and `dns_godaddy_key`.
- [ ] `https-no-certbot`: `credentials/ssl/live/<SERVER_NAME>/fullchain.pem` and `privkey.pem` (plus single-line `privkey.pass` if the key is encrypted); see [Import a TLS certificate](import-ssl-certificate.md).
- [ ] Only one `https-*` profile at a time: they all publish 443 and the certbot ones share a container name.

## Steps

1. Build with the profile, answering its prompts:

   ```bash
   ./build.sh --<HTTPS_PROFILE>
   ```

   Enter `SERVER_NAME`, `LETSENCRYPT_EMAIL` (certbot profiles) and keep
   `HTTPS_PORT` at 443 unless the site requires otherwise. The `mqtts-public`
   sub-profile is offered right after (default yes). On internet-facing sites
   also answer `n` to "Expose plain MQTT on port 1883?" under `base`.

2. Certbot profiles only: obtain the certificate. The `certbot` service is on
   demand (a compose profile) and exits when done:

   ```bash
   docker compose run --rm certbot
   ```

   `TODO(source)`: this is the invocation implied by the service definition
   (`command: certonly …`, `profiles: [<HTTPS_PROFILE>]`); no script in this
   repository wraps it, and no renewal schedule exists. For `https-manual`,
   follow certbot's prompts to create the DNS TXT record.

3. Launch or relaunch:

   ```bash
   ./update.sh
   ```

   Until a certificate exists the apigateway serves a temporary self-signed
   one; installing the real certificate and re-running `./update.sh` clears it.

## Verify

```bash
curl -sI http://<SERVER_NAME>/scv3/ | head -1        # HTTP/1.1 307 Temporary Redirect
curl -sI https://<SERVER_NAME>/scv3/ | head -1       # HTTP/2 200 (or HTTP/1.1 200)
openssl s_client -connect <SERVER_NAME>:8883 -servername <SERVER_NAME> </dev/null 2>/dev/null | openssl x509 -noout -subject
```

The redirect is a 307 so request method and body survive and browsers do not
cache the upgrade; if `HTTPS_PORT` is not 443 the redirect target carries the
port (`HTTPS_PUBLIC_PORT` reaches the apigateway).

## Rollback

Re-run `./build.sh`, answer `n` to the `https-*` prompt (or set it false in
`.settings`), then `./update.sh`. HTTP resumes on `HTTP_PORT` without a
redirect.

## Related

- [ACME and DNS APIs integration](../architecture/integrations/acme-dns.md)
- [MQTT broker listeners](../reference/mqtt-broker-listeners.md)
- Reference deployments [HTTPS via DigitalOcean](../architecture/reference-deployments/https-digitalocean/README.md) and [HTTPS via TLS cert file](../architecture/reference-deployments/https-cert-file/README.md)
