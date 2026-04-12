# Droidex Sandbox

Minimal stack to run `codex-lb` and isolated Droid sandboxes from one repository.

## What it includes

- `manage.sh`: main operator entrypoint
- `codex-lb/`: Docker Compose stack for the shared proxy
- `sandboxes/base/`: sandbox image, compose template, and project scaffolding
- `sandboxes/scripts/`: project lifecycle, model refresh, and connectivity checks
- `docs/`: setup, operations, publishing, and security notes

## Requirements

- Linux
- Docker available for the runtime user
- `bash`, `curl`, `git`, `jq`, `python3`
- Access to the Droid CLI
- An OpenAI-compatible API key that `codex-lb` can use upstream

## Quick start

1. Copy the codex-lb runtime template:

```bash
cp codex-lb/.env.example codex-lb/.env
```

2. Edit `codex-lb/.env` with your real runtime values.

3. Start the shared proxy:

```bash
cd codex-lb
docker compose --env-file .env up -d
```

4. Return to the repo root and open the menu:

```bash
cd ..
./manage.sh
```

5. Create a sandbox project from the menu and validate connectivity.

## Runtime model

- `codex-lb` is exposed on `127.0.0.1:2455` on the host.
- Sandboxes reach it through the shared Docker network at `http://codex-lb:2455/v1`.
- Generated sandbox projects live under `sandboxes/projects/<name>/`.
- Per-project secrets and generated settings stay local and are ignored by Git.

## Daily workflow

- Start from `./manage.sh`
- Create a sandbox project
- Clone or initialize the repo inside `sandboxes/projects/<name>/repo/`
- Build and start the sandbox when prompted
- Enter Droid or open a shell
- Refresh models after changing the upstream API key or available models
- Run connectivity validation when changing `codex-lb` or Docker networking

## Files that must stay out of Git

- `codex-lb/.env`
- `sandboxes/projects/*`
- `.env.local` files with API keys
- generated `.factory-container-settings.json` files
- local caches and runtime artifacts

## Documentation

- [Setup](docs/setup.md)
- [Operations](docs/operations.md)
- [Publishing](docs/publishing.md)
- [Security](docs/security.md)
