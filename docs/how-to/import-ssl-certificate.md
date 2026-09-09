---
title: "Import a TLS certificate from a PKCS#12 bundle"
type: how-to
derived_from:
  - scripts/import-ssl-cert.sh
  - compose/docker-compose.https-no-certbot.yml
  - .gitignore
last_verified: 2026-09-09
verified_against: ccf3768
---

# Import a TLS certificate from a PKCS#12 bundle

## Goal

Convert a `.pfx`/`.p12` bundle into the `fullchain.pem` and `privkey.pem` pair
the `https-no-certbot` profile serves, filed under
`credentials/ssl/live/<FQDN>/`.

## Prerequisites

- [ ] `openssl` on the host.
- [ ] The bundle `<BUNDLE>.pfx` containing the full chain and the private key, and its password.
- [ ] `<FQDN>`: the name users browse to; also the value you will enter for `SERVER_NAME`.

## Steps

1. Run the importer. The FQDN is taken from the file name by default:

   ```bash
   ./scripts/import-ssl-cert.sh ~/certs/<FQDN>.pfx
   ```

   Alternatives: `--from-cn` reads the FQDN from the certificate's Common
   Name; `--server-name <FQDN>` sets it explicitly. Supply the password at the
   prompt, via `--password-file <FILE>`, or via `PFX_PASSWORD`; avoid
   `--password` (visible in `ps`). Use `--force` to overwrite existing files
   and `--quiet` for automation. `--help` lists all options.

2. The script runs the `openssl pkcs12` conversions (with the `-legacy`
   fallback needed for Windows/IIS exports under OpenSSL 3), verifies the key
   matches the certificate, and writes `fullchain.pem` (leaf first) and an
   unencrypted `privkey.pem` (mode 0600). Real key material and `*.pfx` files
   are gitignored (`.gitignore:16-20`).

3. Continue with [Enable HTTPS](enable-https.md), profile
   `https-no-certbot`, `SERVER_NAME=<FQDN>`.

## Verify

```bash
openssl x509 -in credentials/ssl/live/<FQDN>/fullchain.pem -noout -subject -dates
openssl rsa -in credentials/ssl/live/<FQDN>/privkey.pem -check -noout
```

## Rollback

Delete `credentials/ssl/live/<FQDN>/`; the apigateway falls back to a
temporary self-signed certificate on the next `./update.sh`.

## Related

- [Enable HTTPS](enable-https.md)
- [`https-no-certbot` profile](../architecture/profiles/https-no-certbot.md)
