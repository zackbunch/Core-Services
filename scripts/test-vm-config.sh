#!/usr/bin/env bash
set -euo pipefail
umask 077
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset CORE_DOMAIN POSTGRES_PASSWORD KEYCLOAK_ADMIN KEYCLOAK_ADMIN_PASSWORD
unset MINIO_ROOT_USER MINIO_ROOT_PASSWORD MAILPIT_IMAGE MINIO_IMAGE

# Synthetic values only. This test never starts the service stack or uses SSH.
cat > "$tmp/.env" <<'ENV'
CORE_DOMAIN=dev.example.test
POSTGRES_PASSWORD=fixture-only-postgres
KEYCLOAK_ADMIN_PASSWORD=fixture-only-keycloak
MINIO_ROOT_USER=fixture-admin
MINIO_ROOT_PASSWORD=fixture-only-minio
ENV
compose=(docker compose --env-file "$tmp/.env" -f "$root/deploy/vm/compose.yaml")
"${compose[@]}" config --quiet
"${compose[@]}" config --format json > "$tmp/config.json"
python3 - "$tmp/config.json" <<'PY'
import json, sys
config = json.load(open(sys.argv[1]))
services = config['services']
assert config['name'] == 'coreservices-vm'
assert set(services) == {'caddy', 'postgres', 'keycloak', 'vault', 'mailpit', 'minio'}
for name, service in services.items():
    if name != 'caddy':
        assert not service.get('ports'), f'{name} unexpectedly publishes a port'
assert {str(p['published']) for p in services['caddy']['ports']} == {'80', '443'}
assert services['keycloak']['command'] == ['start']
assert services['keycloak']['environment']['KC_HOSTNAME'] == 'https://keycloak.dev.example.test'
assert services['vault']['command'] == ['server']
assert 'VAULT_DEV_ROOT_TOKEN_ID' not in services['vault']['environment']
assert any(v['target'] == '/vault/data' and v['type'] == 'volume' for v in services['vault']['volumes'])
assert services['vault']['environment']['VAULT_API_ADDR'] == 'https://vault.dev.example.test'
print('VM config checks passed: private backends, stable volumes, non-dev identity services.')
PY
if docker compose --env-file "$root/deploy/vm/.env.example" -f "$root/deploy/vm/compose.yaml" config --quiet >/dev/null 2>&1; then
  echo 'ERROR: unfilled example credentials were accepted' >&2
  exit 1
fi
bash -n "$root/scripts/deploy-vm.sh" "$root/scripts/deploy-vm-remote.sh"
echo 'Unfilled credentials rejected; deployment scripts pass Bash syntax checks.'
