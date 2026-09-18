#!/usr/bin/env bash
# Invoked by deploy-vm.sh on the Ubuntu VM; not intended for manual use.
set -euo pipefail
umask 077
[[ $EUID -eq 0 && $# -eq 2 ]] || { echo 'Root and staging/mode arguments required.' >&2; exit 1; }
stage=$1
mode=$2
[[ "$mode" == deploy || "$mode" == check ]] || exit 2
[[ "$stage" =~ ^/tmp/coreservices-deploy\.[a-zA-Z0-9]+$ && -d "$stage" ]] || exit 2
unset CORE_DOMAIN POSTGRES_PASSWORD KEYCLOAK_ADMIN KEYCLOAK_ADMIN_PASSWORD
unset MINIO_ROOT_USER MINIO_ROOT_PASSWORD MAILPIT_IMAGE MINIO_IMAGE

# Avoid concurrent releases racing Compose and the active configuration pointer.
exec 9>/run/lock/coreservices-deploy.lock
flock -n 9 || { echo 'Another deployment is in progress.' >&2; exit 1; }
docker compose version >/dev/null
docker info >/dev/null
docker compose --project-name coreservices-vm --env-file "$stage/.env" -f "$stage/compose.yaml" config --quiet
if [[ "$mode" == check ]]; then
  echo 'Remote Docker and Compose configuration checks passed. No containers changed.'
  exit 0
fi

base=/opt/coreservices
install -d -m 700 "$base" "$base/releases"
release=$(mktemp -d "$base/releases/release-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")
cp "$stage/compose.yaml" "$stage/.env" "$release/"
cp -R "$stage/caddy" "$stage/vault" "$release/"
chmod 600 "$release/.env"
compose=(docker compose --project-name coreservices-vm --env-file "$release/.env" -f "$release/compose.yaml")
"${compose[@]}" pull
"${compose[@]}" up -d --wait --wait-timeout 180
# Only publish the config pointer after Compose starts successfully. A failed up
# may still have partially changed containers: this is NOT transactional rollback.
link="$base/.current-$$"
ln -s "$release" "$link"
mv -Tf "$link" "$base/current"
"${compose[@]}" ps
echo "Deployed configuration: $release"
echo 'Vault still requires manual initialization/unseal; verify service readiness.'
