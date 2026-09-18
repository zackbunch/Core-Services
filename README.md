# CoreServices

Local development infrastructure using Docker Compose.

> This stack is intended for local development only. Do not use these defaults for production.

## Proxmox development VM

Terraform configuration in [`terraform/proxmox`](terraform/proxmox/README.md)
provisions Ubuntu Server 24.04 LTS with **4 vCPU, 8 GiB RAM, an 80 GiB disk**,
SSH public-key access, Docker Engine, and the Compose plugin. Supply your Proxmox
endpoint/node, storage/network settings, and SSH public key before deployment.

It provisions the VM only; it does not migrate this stack or make the development
credentials/Vault configuration production-ready. See the linked deployment guide.

## Services

| Service | URL | Notes |
| --- | --- | --- |
| Caddy | https://*.localhost | Reverse proxy for local services |
| Vault | https://vault.localhost | Dev-mode Vault, token defaults to `root` |
| Postgres | localhost:5432 | Default DB/user/password: `dev` / `dev` / `dev` |
| Keycloak | https://keycloak.localhost | Admin defaults to `admin` / `admin` |
| Mailpit | https://mailpit.localhost | SMTP on `localhost:1025` |
| MinIO | https://minio.localhost | S3-compatible storage UI |
| MinIO S3 API | https://s3.localhost | S3-compatible API through Caddy |

## Quick start

```bash
docker compose --profile core up -d
```

Stop the stack:

```bash
docker compose --profile core down
```

Stop and delete named volumes/data:

```bash
docker compose --profile core down -v
```

## Environment

The compose file has local-dev defaults built in. To override them:

```bash
cp .env.example .env
```

Then edit `.env`.

`.env` is intentionally gitignored.

## Profiles

You can start the full core stack:

```bash
docker compose --profile core up -d
```

Or start selected services:

```bash
docker compose --profile vault up -d
docker compose --profile keycloak up -d
docker compose --profile mail up -d
docker compose --profile minio up -d
```

Useful profile groups:

- `core` - common local dev stack
- `security` - Vault
- `identity` - Keycloak
- `database` - Postgres
- `devtools` - Mailpit
- `storage` - MinIO

## Credentials

Defaults are intentionally simple and for local use only:

| Service | Username | Password / Token |
| --- | --- | --- |
| Vault | n/a | `root` |
| Postgres | `dev` | `dev` |
| Keycloak | `admin` | `admin` |
| MinIO | `developer` | `developer123` |

## Notes

- Vault is running in dev mode, so Vault data/config is disposable.
- Keycloak data persists in the Postgres named volume.
- Caddy stores its local CA/certs in named volumes.
- MinIO object data persists in the `minio_data` named volume.
