#!/bin/bash
#
# import-ssl-cert.sh
#
# Convert an encrypted PKCS#12 bundle (.pfx / .p12) that contains the full
# certificate chain *and* the private key into the unencrypted
# `fullchain.pem` + `privkey.pem` pair that the apigateway expects for the
# `https-no-certbot` profile ("Enable HTTPS (via direct SSL)").
#
# The converted files are written to:
#
#     credentials/ssl/live/<FQDN>/fullchain.pem
#     credentials/ssl/live/<FQDN>/privkey.pem
#
# <FQDN> is the name end users browse to (https://<FQDN>) and the value you
# enter for SERVER_NAME during ./build.sh. By default it is taken from the
# .pfx file name, e.g.
#
#     serverhostname001.region.company.com.pfx
#         -> credentials/ssl/live/serverhostname001.region.company.com/
#
# Use --from-cn to read it from the certificate's Common Name instead, or
# --server-name to set it explicitly.
#
# The mqtts-public sub-profile reuses the very same files, so importing the
# cert once is enough for both HTTPS (443) and MQTTS (8883).
#
# Usage:
#     ./scripts/import-ssl-cert.sh [options] <path-to-cert.pfx>
#
# Run with --help for the full list of options.

set -euo pipefail

# --------------------------------------------------------------------------
# Resolve paths relative to this script so it works from any directory.
# --------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --------------------------------------------------------------------------
# Defaults / state
# --------------------------------------------------------------------------
PFX_PATH=""
PFX_PASS=""
PASS_SET=0
FQDN=""
FROM_CN=0
SSL_DIR="$REPO_ROOT/credentials/ssl"
FORCE=0
QUIET=0
LEGACY_FLAG=""
LEGACY_SUPPORTED=""
TMP_CHAIN=""
TMP_KEY=""

usage() {
  cat <<'EOF'
Convert a PKCS#12 (.pfx/.p12) bundle into the fullchain.pem + privkey.pem
pair used by the `https-no-certbot` profile, and place them under
credentials/ssl/live/<FQDN>/.

Usage:
  scripts/import-ssl-cert.sh [options] <path-to-cert.pfx>

Options:
  -s, --server-name FQDN  Domain to file the cert under and use as SERVER_NAME.
      --fqdn FQDN         Alias for --server-name.
  -c, --from-cn           Derive the FQDN from the certificate's Common Name
                          instead of the .pfx file name.
  -p, --password PASS     Password for the .pfx (INSECURE: visible to other
                          users via `ps`; prefer --password-file or the prompt).
  -P, --password-file F   Read the .pfx password from the first line of file F.
      --ssl-dir DIR       Base SSL directory (default: credentials/ssl).
  -f, --force             Overwrite existing fullchain.pem/privkey.pem without
                          prompting.
  -q, --quiet             Do not prompt (for automation). Requires the password
                          via --password/--password-file/$PFX_PASSWORD, or
                          assumes an empty password.
  -h, --help              Show this help and exit.

FQDN resolution order: --server-name > --from-cn > .pfx file name.
The password may also be supplied via the PFX_PASSWORD environment variable.

Example:
  scripts/import-ssl-cert.sh ~/certs/serverhostname001.region.company.com.pfx
EOF
}

die() { echo "Error: $*" >&2; exit 1; }

# Read the certificate's Common Name (long attribute name keeps this portable
# across OpenSSL 1.1.1 / 3.x and LibreSSL).
cert_cn() {
  openssl x509 -in "$1" -noout -subject -nameopt multiline 2>/dev/null \
    | sed -n 's/^[[:space:]]*commonName[[:space:]]*=[[:space:]]*//p' | head -n1
}

# First DNS Subject Alternative Name, used as a fallback for --from-cn.
cert_san1() {
  openssl x509 -in "$1" -noout -ext subjectAltName 2>/dev/null \
    | tr ',' '\n' | sed -n 's/.*DNS:[[:space:]]*//p' | head -n1
}

# Does an FQDN match a (possibly wildcard) certificate CN? Case-insensitive.
fqdn_matches_cn() {
  local fqdn=$1 cn=$2 rc=1
  shopt -s nocasematch
  if [[ "$cn" == "$fqdn" ]]; then
    rc=0
  elif [[ "$cn" == \*.* ]]; then
    # *.region.company.com matches host.region.company.com
    [[ "${fqdn#*.}" == "${cn#\*.}" ]] && rc=0
  fi
  shopt -u nocasematch
  return $rc
}

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--server-name|--fqdn) FQDN="${2:-}"; shift 2 ;;
    -c|--from-cn)            FROM_CN=1; shift ;;
    -p|--password)           PFX_PASS="${2:-}"; PASS_SET=1; shift 2 ;;
    -P|--password-file)
      [[ -n "${2:-}" && -r "$2" ]] || die "Cannot read password file: ${2:-<none>}"
      IFS= read -r PFX_PASS < "$2" || true
      PASS_SET=1; shift 2 ;;
    --ssl-dir)               SSL_DIR="${2:-}"; shift 2 ;;
    -f|--force)              FORCE=1; shift ;;
    -q|--quiet)              QUIET=1; shift ;;
    -h|--help)               usage; exit 0 ;;
    --)                      shift; break ;;
    -*)                      die "Unknown option: $1 (use --help)" ;;
    *)
      [[ -z "$PFX_PATH" ]] || die "Unexpected extra argument: $1"
      PFX_PATH="$1"; shift ;;
  esac
done
if [[ -z "$PFX_PATH" && $# -gt 0 ]]; then PFX_PATH="$1"; fi

# --------------------------------------------------------------------------
# Validate inputs
# --------------------------------------------------------------------------
[[ -n "$PFX_PATH" ]] || { usage; echo; die "No .pfx/.p12 file specified."; }
[[ -f "$PFX_PATH" && -r "$PFX_PATH" ]] || die "Certificate file not found or unreadable: $PFX_PATH"
command -v openssl >/dev/null 2>&1 || die "openssl is required but was not found in PATH."

# --------------------------------------------------------------------------
# Resolve the .pfx password (flag > file > env > prompt)
# --------------------------------------------------------------------------
if [[ $PASS_SET -eq 0 && -n "${PFX_PASSWORD:-}" ]]; then
  PFX_PASS="$PFX_PASSWORD"; PASS_SET=1
fi
if [[ $PASS_SET -eq 0 ]]; then
  if [[ $QUIET -eq 1 ]]; then
    PFX_PASS=""   # assume a password-less bundle in non-interactive mode
  else
    read -r -s -p "Enter password for $(basename "$PFX_PATH") (leave blank if none): " PFX_PASS
    echo
  fi
fi

# --------------------------------------------------------------------------
# Decide whether the legacy provider is needed.
#
# OpenSSL 3.x disables the old algorithms (RC2-40, 3DES, ...) that Windows /
# IIS commonly use for .pfx files; those bundles need `-legacy`. OpenSSL 1.1.1
# and LibreSSL neither need nor offer the flag. We feature-detect support, then
# probe: try modern first, fall back to legacy. This also validates the
# password up front so extraction below cannot half-succeed.
# --------------------------------------------------------------------------
help_text="$(openssl pkcs12 -help 2>&1 || true)"
[[ "$help_text" == *"-legacy"* ]] && LEGACY_SUPPORTED=1

probe() {
  # $1 = extra flag ("" or "-legacy")
  printf '%s\n' "$PFX_PASS" | openssl pkcs12 -in "$PFX_PATH" -nokeys $1 -passin stdin >/dev/null 2>&1
}

if probe ""; then
  LEGACY_FLAG=""
elif [[ -n "$LEGACY_SUPPORTED" ]] && probe "-legacy"; then
  LEGACY_FLAG="-legacy"
else
  err="$({ printf '%s\n' "$PFX_PASS" | openssl pkcs12 -in "$PFX_PATH" -nokeys ${LEGACY_SUPPORTED:+-legacy} -passin stdin >/dev/null; } 2>&1 || true)"
  echo "Error: could not read '$PFX_PATH' as a PKCS#12 bundle." >&2
  shopt -s nocasematch
  if [[ "$err" == *verify* || "$err" == *password* || "$err" == *mac* ]]; then
    echo "  -> The password may be incorrect." >&2
  fi
  shopt -u nocasematch
  [[ -n "$err" ]] && echo "  openssl: ${err##*$'\n'}" >&2
  exit 1
fi

# --------------------------------------------------------------------------
# Extract certificate material into temp files (created 0600 via umask).
# --------------------------------------------------------------------------
umask 077
TMP_CHAIN="$(mktemp "${TMPDIR:-/tmp}/fullchain.XXXXXX")"
TMP_KEY="$(mktemp "${TMPDIR:-/tmp}/privkey.XXXXXX")"
trap 'rm -f "${TMP_CHAIN:-}" "${TMP_KEY:-}" 2>/dev/null || true' EXIT

# Run openssl pkcs12 with the password on stdin (keeps it out of `ps`) and the
# previously determined legacy flag. `sed` strips the "Bag Attributes" noise
# that openssl prints around each PEM block.
extract() {
  printf '%s\n' "$PFX_PASS" | openssl pkcs12 -in "$PFX_PATH" "$@" $LEGACY_FLAG -passin stdin 2>/dev/null
}

# 1. Leaf (client) certificate first - nginx requires the server cert at the
#    top of fullchain.pem, followed by any intermediates.
extract -clcerts -nokeys \
  | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > "$TMP_CHAIN"
[[ -s "$TMP_CHAIN" ]] || die "No leaf certificate found in $PFX_PATH."

# --------------------------------------------------------------------------
# Determine the FQDN (server name / output directory).
# --------------------------------------------------------------------------
if [[ -n "$FQDN" ]]; then
  :  # explicit --server-name wins
elif [[ $FROM_CN -eq 1 ]]; then
  FQDN="$(cert_cn "$TMP_CHAIN")"
  [[ "$FQDN" == \*.* ]] && die "Certificate CN is a wildcard ('$FQDN'); choose a concrete host with --server-name."
  [[ -n "$FQDN" ]] || FQDN="$(cert_san1 "$TMP_CHAIN")"
  [[ -n "$FQDN" ]] || die "Could not read a Common Name or DNS SAN from the certificate; pass --server-name explicitly."
else
  # Default: strip the directory and the .pfx/.p12 extension from the file name.
  base="$(basename "$PFX_PATH")"
  FQDN="${base%.*}"
fi

# DNS is case-insensitive; normalise so the directory and SERVER_NAME line up.
FQDN="$(printf '%s' "$FQDN" | tr '[:upper:]' '[:lower:]')"

# The FQDN becomes a directory name, so reject anything unsafe.
[[ "$FQDN" =~ ^[a-z0-9._-]+$ && "$FQDN" != *..* ]] \
  || die "Refusing to use unsafe server name / directory: '$FQDN'"

# Sanity check the chosen name against the certificate CN (non-fatal).
cn="$(cert_cn "$TMP_CHAIN")"
if [[ -n "$cn" ]] && ! fqdn_matches_cn "$FQDN" "$cn"; then
  echo "Warning: server name '$FQDN' does not match certificate CN '$cn'." >&2
  echo "         Re-run with --from-cn or --server-name <fqdn> if that is wrong." >&2
fi

DEST_DIR="$SSL_DIR/live/$FQDN"

# --------------------------------------------------------------------------
# Guard against clobbering an existing cert without confirmation.
# --------------------------------------------------------------------------
if [[ -e "$DEST_DIR/fullchain.pem" || -e "$DEST_DIR/privkey.pem" ]] \
   && [[ $FORCE -ne 1 && $QUIET -ne 1 ]]; then
  echo "Existing certificate files found in $DEST_DIR"
  read -r -p "Overwrite them? (y/n): " ans
  case "${ans,,}" in
    y|yes) ;;
    *) die "Aborted; existing files left untouched." ;;
  esac
fi

# --------------------------------------------------------------------------
# Extract the private key (unencrypted) and append the CA chain.
# --------------------------------------------------------------------------
extract -nocerts -nodes \
  | sed -n '/-----BEGIN/,/-----END/p' > "$TMP_KEY"
[[ -s "$TMP_KEY" ]] || die "No private key found in $PFX_PATH."

# Intermediates / CA certs (may legitimately be empty for a self-contained cert).
{ extract -cacerts -nokeys || true; } \
  | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' >> "$TMP_CHAIN"

# --------------------------------------------------------------------------
# Validate the results before putting them in place.
# --------------------------------------------------------------------------
openssl pkey -in "$TMP_KEY" -noout 2>/dev/null   || die "Extracted private key is not valid."
openssl x509 -in "$TMP_CHAIN" -noout 2>/dev/null || die "Extracted certificate is not valid."

# The private key and the leaf certificate must share the same public key.
# Comparing public keys works for RSA, EC and Ed25519 alike.
key_pub="$(openssl pkey -in "$TMP_KEY" -pubout 2>/dev/null || true)"
crt_pub="$(openssl x509 -in "$TMP_CHAIN" -pubkey -noout 2>/dev/null || true)"
[[ -n "$key_pub" && "$key_pub" == "$crt_pub" ]] \
  || die "Private key does not match the leaf certificate in $PFX_PATH."

# --------------------------------------------------------------------------
# Move into place with appropriate permissions.
# --------------------------------------------------------------------------
mkdir -p "$DEST_DIR"
mv -f "$TMP_CHAIN" "$DEST_DIR/fullchain.pem"
mv -f "$TMP_KEY"   "$DEST_DIR/privkey.pem"
TMP_CHAIN=""; TMP_KEY=""   # handed off; stop the EXIT trap from deleting them
chmod 644 "$DEST_DIR/fullchain.pem"
chmod 600 "$DEST_DIR/privkey.pem"

# A stale password file would imply an encrypted key, which this script does
# not produce. Warn rather than delete (it is the user's file).
if [[ -e "$DEST_DIR/privkey.pass" ]]; then
  echo "Note: $DEST_DIR/privkey.pass exists, but privkey.pem is now UNENCRYPTED." >&2
  echo "      You can delete privkey.pass; it is no longer needed." >&2
fi

# --------------------------------------------------------------------------
# Summary + next steps.
# --------------------------------------------------------------------------
chain_count="$(grep -c -- '-----BEGIN CERTIFICATE-----' "$DEST_DIR/fullchain.pem" || true)"
rel_dir="${DEST_DIR#"$REPO_ROOT"/}"

cat <<EOF

Successfully imported certificate:

  $rel_dir/fullchain.pem   ($chain_count certificate(s))
  $rel_dir/privkey.pem     (unencrypted, mode 600)

Next steps:
  1. Run ./build.sh and enable "Enable HTTPS (via direct SSL)".
  2. When prompted, set SERVER_NAME to:  $FQDN
  3. Run ./update.sh to (re)launch the deployment.
EOF

if [[ "${chain_count:-0}" -lt 2 ]]; then
  cat <<'EOF'

Note: fullchain.pem contains only the leaf certificate (no intermediate CA
      certificates were present in the .pfx). If clients report an incomplete
      chain, obtain a .pfx that bundles the intermediates.
EOF
fi
