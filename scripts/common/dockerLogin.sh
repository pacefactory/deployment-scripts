#!/usr/bin/env bash
#
# dockerLogin.sh - Docker Hub login helpers. Sourced, not executed.
#
# Production convention (documented in the Pacefactory Deployment Guide): every
# server has its own non-expiring Docker Organization Access Token with
# image-pull scope on the Pacefactory repositories, stored as
#
#   export DOCKER_OAT=dckr_oat_...
#
# in ~/scv2/docker_oat.sh (mode 700), and the server stays permanently logged
# in as the organization user 'pacefactory'. These helpers consume that
# convention. They never create the token file, never print the token, never
# enable tracing and never run 'docker logout' (a failed re-login would
# otherwise leave the server logged out).
#
# Variables (all optional):
#   PF_OAT_FILE     token file, default $HOME/scv2/docker_oat.sh
#   PF_DOCKER_USER  login user, default pacefactory
#   DOCKER_OAT      honoured when already exported in the environment
#
# Functions:
#   pf_docker_username             user the daemon reports as logged in ('' if none)
#   pf_docker_login_with_oat       docker login with $DOCKER_OAT from the environment
#   pf_docker_login_from_file <f>  source <f> in a subshell, login with the DOCKER_OAT it exports
#   pf_docker_login                full decision chain; 0 = proceed, 1 = stop (remediation printed)
#   pf_docker_login_remediation    print how to obtain and store a token
#
# The public bootstrap (pacefactory/deploy install.sh) implements the same chain
# standalone; keep the two in step.

PF_OAT_FILE="${PF_OAT_FILE:-$HOME/scv2/docker_oat.sh}"
PF_DOCKER_USER="${PF_DOCKER_USER:-pacefactory}"

pf_docker_username() {
  docker info --format '{{.Username}}' 2>/dev/null || true
}

pf_docker_login_remediation() {
  cat >&2 <<EOF

Docker Hub login as '$PF_DOCKER_USER' is required and no usable credential was found.
Remediation:
  1. Obtain a per-server Docker Organization Access Token (image-pull scope) for
     this server, following the Pacefactory Deployment Guide.
  2. Store it as $PF_OAT_FILE (mode 700) containing one line:
       export DOCKER_OAT=dckr_oat_...
  3. Re-run:  curl -fsSL https://get.pacefactory.dev/install.sh | bash
EOF
}

# Login with the token held in $DOCKER_OAT. stdout of 'docker login' only ever
# says "Login Succeeded" and is dropped; stderr carries the real error.
pf_docker_login_with_oat() {
  if [[ -z "${DOCKER_OAT:-}" ]]; then
    echo >&2 "docker login: DOCKER_OAT is empty"
    return 1
  fi
  printf '%s' "$DOCKER_OAT" | docker login -u "$PF_DOCKER_USER" --password-stdin >/dev/null
}

# Source the token file inside a subshell so the token never enters the
# caller's environment, tracing is forced off, and the file cannot change the
# caller's shell options or working directory.
pf_docker_login_from_file() {
  local file="$1"
  if [[ ! -r "$file" ]]; then
    echo >&2 "docker login: cannot read token file $file"
    return 1
  fi
  (
    set +x
    set +e
    # shellcheck disable=SC1090
    . "$file" >/dev/null 2>&1
    set -e
    if [[ -z "${DOCKER_OAT:-}" ]]; then
      echo >&2 "docker login: $file does not export DOCKER_OAT"
      exit 1
    fi
    printf '%s' "$DOCKER_OAT" | docker login -u "$PF_DOCKER_USER" --password-stdin >/dev/null
  )
}

# Decision chain:
#   1. token file present               -> login with it (do not logout first)
#   2. DOCKER_OAT in environment        -> login with it
#   3. already logged in as $PF_DOCKER_USER -> proceed
#   4. logged in as legacy 'pfclient'   -> warn, proceed
#   5. otherwise                        -> fail with remediation
pf_docker_login() {
  local user
  if [[ -f "$PF_OAT_FILE" ]]; then
    echo "docker login: using token file $PF_OAT_FILE as '$PF_DOCKER_USER'"
    if pf_docker_login_from_file "$PF_OAT_FILE"; then
      return 0
    fi
    echo >&2 "docker login with $PF_OAT_FILE failed: the token may have been revoked or lack image-pull scope."
    pf_docker_login_remediation
    return 1
  fi
  if [[ -n "${DOCKER_OAT:-}" ]]; then
    echo "docker login: using DOCKER_OAT from the environment as '$PF_DOCKER_USER'"
    if pf_docker_login_with_oat; then
      return 0
    fi
    echo >&2 "docker login with DOCKER_OAT failed: the token may have been revoked or lack image-pull scope."
    pf_docker_login_remediation
    return 1
  fi
  user="$(pf_docker_username)"
  case "$user" in
    "$PF_DOCKER_USER")
      echo "docker login: already logged in as '$user'"
      return 0
      ;;
    pfclient)
      echo >&2 "WARNING: this server is logged in to Docker Hub as the legacy user 'pfclient' (device-code login)."
      echo >&2 "         Move it to a per-server Organization Access Token in $PF_OAT_FILE (Pacefactory Deployment Guide)."
      return 0
      ;;
    "")
      echo >&2 "docker login: not logged in to Docker Hub and no token file at $PF_OAT_FILE"
      pf_docker_login_remediation
      return 1
      ;;
    *)
      echo >&2 "docker login: logged in as '$user', not '$PF_DOCKER_USER', and no token file at $PF_OAT_FILE"
      pf_docker_login_remediation
      return 1
      ;;
  esac
}
