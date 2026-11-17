# CoreServices

Local development infrastructure using Docker Compose.

> This stack is intended for local development only. Do not use these defaults for production.

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

## Local GitLab lab

GitLab CE and a runner container are available separately from the `core` profile:

```bash
docker compose --profile gitlab --profile caddy up -d caddy gitlab gitlab-runner
```

Open https://gitlab.localhost after GitLab finishes initializing. Caddy uses its local CA; trust the CA in your browser/OS using your normal certificate trust process. Caddy's HTTP and HTTPS ports are bound to localhost, including for the existing services. Retrieve the temporary initial root password locally with `docker compose exec gitlab grep 'Password:' /etc/gitlab/initial_root_password`; do not share it. GitLab removes this file after initial setup. Use HTTPS for Git; SSH is not exposed.

A project-scoped runner is registered to `root/pvaams-ci-sandbox`. Its Docker executor uses the Compose network, Caddy's local CA, and `https://gitlab.ci.internal` for job clones because `.localhost` resolves to the job container itself. The registration and runner configuration persist in the `gitlab_runner_config` volume; never commit runner tokens. The runner has access to the Docker socket so it can create job containers; compromise of the runner can give control of the Docker daemon and its containers. Use only trusted local test projects, not untrusted merge requests or production secrets.

GitLab runs as amd64 under emulation on Apple Silicon. Startup may take several minutes and Docker's 8 GiB memory allocation may be insufficient, especially during jobs. Data is stored in named volumes. Stop only these services with `docker compose --profile gitlab --profile caddy stop gitlab-runner gitlab caddy`; stopping Caddy also affects other CoreServices routes. Avoid `down -v` unless intentionally deleting all selected persistent data.

## GitLab infrastructure as code

Terraform configuration for managing GitLab groups is in [`terraform/gitlab`](terraform/gitlab/README.md). It supports the local GitLab lab and other GitLab instances.

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
