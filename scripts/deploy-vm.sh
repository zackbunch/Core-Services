#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  echo "Usage: $0 SSH_HOST --env-file FILE [--check]" >&2
  exit 2
}
[[ $# -ge 3 ]] || usage
host=$1
shift
# Use an SSH alias, user@hostname, or IPv4 address; reject shell metacharacters.
[[ "$host" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.@-]*$ ]] || usage
env_file=
mode=deploy
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file) [[ $# -ge 2 ]] || usage; env_file=$2; shift 2 ;;
    --check) mode=check; shift ;;
    *) usage ;;
  esac
done
[[ -f "$env_file" ]] || { echo 'A populated VM env file is required.' >&2; exit 1; }
root=$(cd "$(dirname "$0")/.." && pwd)
bundle=$(mktemp -d)
stage=
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=10)
cleanup() {
  rm -rf "$bundle"
  if [[ -n "$stage" ]]; then
    # stage is a locally held, allowlisted remote path; expand it intentionally.
    # shellcheck disable=SC2029
    ssh "${ssh_opts[@]}" "$host" "rm -rf '$stage'" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# A fixed allowlist avoids copying the local stack, Git, state, volumes or .env.
cp "$root/deploy/vm/compose.yaml" "$bundle/compose.yaml"
cp "$env_file" "$bundle/.env"
cp -R "$root/deploy/vm/caddy" "$root/deploy/vm/vault" "$bundle/"
cp "$root/scripts/deploy-vm-remote.sh" "$bundle/deploy-vm-remote.sh"
chmod 600 "$bundle/.env"
# The supplied file, not unrelated local shell variables, controls deployment.
unset CORE_DOMAIN POSTGRES_PASSWORD KEYCLOAK_ADMIN KEYCLOAK_ADMIN_PASSWORD
unset MINIO_ROOT_USER MINIO_ROOT_PASSWORD MAILPIT_IMAGE MINIO_IMAGE

docker compose --env-file "$bundle/.env" -f "$bundle/compose.yaml" config --quiet
stage=$(ssh "${ssh_opts[@]}" "$host" 'umask 077; mktemp -d /tmp/coreservices-deploy.XXXXXXXX')
[[ "$stage" =~ ^/tmp/coreservices-deploy\.[a-zA-Z0-9]+$ ]] || { stage=; echo 'Unexpected remote staging path.' >&2; exit 1; }
tar -czf "$bundle/upload.tgz" -C "$bundle" compose.yaml .env caddy vault deploy-vm-remote.sh
scp -q -o BatchMode=yes -o ConnectTimeout=10 "$bundle/upload.tgz" "$host:$stage/upload.tgz"
# Both interpolated values are constrained above; no env-file contents enter SSH commands.
# shellcheck disable=SC2029
ssh "${ssh_opts[@]}" "$host" "tar -xzf '$stage/upload.tgz' -C '$stage' && sudo -n bash '$stage/deploy-vm-remote.sh' '$stage' '$mode'"
