# Deploy CoreServices to the Ubuntu VM

This is a **standalone shared-development stack**, not an override of the Mac's
`docker-compose.yml`. The local stack and Caddy configuration are left unchanged.
Only Caddy publishes host ports (80/443). PostgreSQL, Keycloak, Vault, MinIO and
Mailpit communicate over the private Compose network. SMTP is `mailpit:1025`
inside that network; there is no LAN SMTP port by default.

## Before deploying

1. Prepare an Ubuntu Server 24.04 LTS VM and install Docker Engine and the Compose
   plugin. Confirm `sudo docker compose version` works. VM provisioning is managed
   separately from this project.
2. Set up an SSH alias, e.g. `coreservices`, and verify its host key. Deployment
   uses noninteractive SSH and passwordless `sudo`; it does not disable host-key
   checking or request passwords. Configure the deployment user for passwordless sudo.
3. Restrict the VM to a trusted LAN/VPN/VLAN. Permit SSH only from administrators,
   and HTTPS/HTTP only from intended users. This module installs no firewall rules.
   Mailpit's web UI has **no authentication**: do not expose this stack publicly.
4. Choose an internal DNS zone and create records pointing at the VM:

   ```text
   keycloak.<zone>
   vault.<zone>
   mailpit.<zone>
   minio.<zone>
   s3.<zone>
   ```

   These must resolve from your workstation, devbox and any other clients.
   Do not use `.localhost`, which always refers to the client's own machine.
5. Disable swap on the Vault host (and its persistent swap configuration), or
   review an appropriate encrypted-swap/mlock configuration with your operators.
   This Raft configuration follows the no-mlock model; unencrypted swap can leak
   sensitive memory. The deploy script does not change host swap settings.

## Set credentials

On your workstation:

```bash
cd /Users/zack/Developer/CoreServices
umask 077
cp deploy/vm/.env.example deploy/vm/.env
```

Edit `deploy/vm/.env` with the real DNS suffix and fresh, unique credentials.
Required secrets are deliberately blank; unedited configuration fails validation.
Use single quotes around dotenv values containing `$` or `#`. Do not reuse local
root/dev defaults. A password manager is recommended. This file is ignored by Git.

The deployment configuration keeps existing major image versions for compatibility;
Mailpit/MinIO default to moving tags. Pin tested image digests for a repeatable,
long-lived environment and review security updates before workplace use.

## Check, then deploy

Requires local Bash, SSH/scp, tar and Docker Compose v2.20+ (or v5); the VM needs
Docker Compose, Bash, `flock` and noninteractive sudo. Install these prerequisites
on the VM before deploying.

```bash
./scripts/deploy-vm.sh coreservices --env-file deploy/vm/.env --check
./scripts/deploy-vm.sh coreservices --env-file deploy/vm/.env
```

`--check` validates Compose locally and on the VM and checks Docker access, without
pulling images or changing containers. It temporarily transfers the env file over
SSH to a private staging directory and removes it afterward.

A deployment:

- Transfers only the VM Compose/Caddy/Vault configuration, selected env file and
  remote deployment helper. It never uploads local volumes, Git, or the root
  project's `.env`.
- Uses mode-0700 staging/release directories and mode-0600 env files.
- Serializes deployments with a remote lock.
- Creates `/opt/coreservices/releases/<release>` as root, validates configuration,
  pulls images, and runs Compose with the fixed project name `coreservices-vm`.
- Updates `/opt/coreservices/current` only after `up --wait` succeeds.
- Preserves existing named volumes. It never runs `down -v`, initializes Vault,
  unseals Vault, prints credentials, or migrates data.

`--wait` confirms containers are running and PostgreSQL passes its health check;
it is not an application acceptance test. Vault can be running but sealed, and
Keycloak may still be starting. An unsuccessful `up` can partially change containers:
this is **not automatic transactional rollback**. Previous root-only release
folders remain for review/rollback and contain secrets; manage their retention.
A killed SSH session may leave a private staging directory requiring manual cleanup.

## First deployment: trust HTTPS and initialize Vault

Caddy uses its **internal CA**. Retrieve only its public root certificate and
install it into the trust store on your Mac, devbox and other clients. Do not
export the CA private key. Existing trust in your Mac's local Caddy CA does not
cover this new VM's CA.

For management on the VM:

```bash
sudo -i
cd /opt/coreservices/current
docker compose ps
docker compose logs --tail=100 keycloak caddy
# Export the PUBLIC certificate only:
docker compose cp caddy:/data/caddy/pki/authorities/local/root.crt /tmp/coreservices-root.crt
chmod 644 /tmp/coreservices-root.crt
exit
```

Copy that public certificate to clients and verify its fingerprint through your
trusted SSH connection before adding trust. Alternatively, replace `tls internal`
with an appropriately configured company/public certificate issuer. DNS and network
access must meet that issuer's requirements; public issuance is not configured here.

Vault now uses persistent **single-node Raft**, not dev mode. It begins uninitialized
and sealed. On the VM, in a private administrative session:

```bash
sudo -i
cd /opt/coreservices/current
docker compose exec vault vault status
docker compose exec vault vault operator init
# Run unseal as many times as needed with distinct shares; enter keys at the prompt:
docker compose exec vault vault operator unseal
exit
```

Initialize only once. Initialization displays highly sensitive unseal shares and
an initial root token: store them in approved secure locations, preferably use
PGP-encrypted output/separate custodians, and never commit, paste into shared logs,
or leave them in this env file. Configure least-privilege access and retire the
initial root token after setup. Without auto-unseal, Vault needs unsealing after
each restart. Do not initialize again to recover lost keys.

`VAULT_DEV_ROOT_TOKEN_ID` is intentionally absent. Existing dev tokens, CLI sessions,
Keycloak clients and Vault policies are not recreated automatically. Configure the
`arsenal` Keycloak client, issuer/audiences, and required Vault auth/policies separately.
Changing bootstrap env passwords later does not rotate passwords already stored
in an initialized PostgreSQL database or Keycloak realm; use supported rotation.

## Verify and operate

After DNS, trust, startup and Vault unseal:

- Open `https://keycloak.<zone>` and `https://vault.<zone>`.
- Check `https://mailpit.<zone>` and `https://minio.<zone>`.
- Verify Keycloak's realm discovery document advertises the new HTTPS issuer.
- Set `ARSENAL_ISSUER=https://keycloak.<zone>/realms/<realm>` on clients.
- Set `ARSENAL_VAULT_ADDR=https://vault.<zone>` if using the Vault integration.

Use the root management session above for `docker compose ps`, logs, stop or up.
Do not run `docker compose down -v` unless deliberately deleting all service data.
Use application-consistent database dumps, Vault Raft snapshots and appropriate
MinIO backups. Protect Caddy's CA volume as well. A VM snapshot alone is not a
substitute for tested application backups and unseal-key custody.

Rollback is a deliberate operation: review database/image compatibility, run Compose
against a retained release, then update the current symlink after verification.
Restoring old images does not undo schema migrations or data changes.

## Local validation

```bash
./scripts/test-vm-config.sh
```

This uses synthetic secrets to validate Compose, verifies only Caddy publishes
ports and Vault uses a persistent volume, rejects an unfilled env template, and
syntax-checks both deploy scripts. It does not use SSH or start the stack.
Caddy validation and an isolated, network-disabled Vault startup were also checked
during implementation. A complete VM deployment and live Keycloak login still
require your actual VM, DNS, credentials, and certificate trust.

## Not included

- Data migration from the Mac or automatic backup scheduling.
- Jira/Confluence mocks. They live in a separate project; no `host.docker.internal`
  upstreams or routes to them are shipped here. Deploy them separately and add
  explicit shared-network routes if needed.
- Production HA, certificate distribution, employee access policies, or host firewall
  management. This is still a shared **development** environment.
- A browser/credential keyring on devbox or device authorization in Arsenal.
