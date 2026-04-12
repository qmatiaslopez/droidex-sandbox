# Setup

## Prerequisites

- Linux host with Docker available for the runtime user
- `bash`, `curl`, `git`, `jq`, `python3`
- Network access for the Droid CLI installation inside sandbox images
- An upstream API key for model discovery and proxy requests

## 1. Configure `codex-lb`

Create the private runtime file:

```bash
cp codex-lb/.env.example codex-lb/.env
```

Fill in:

- `CODEX_LB_DASHBOARD_BOOTSTRAP_TOKEN`
- `CODEX_LB_CONTAINER_NAME` if you need a non-default container name
- `CODEX_LB_PORT` if `2455` is already in use
- `CODEX_LB_NETWORK` if your shared Docker network already exists with another name
- `CODEX_LB_VOLUME` if you need to reuse an existing persistent volume

Start the proxy:

```bash
cd codex-lb
docker compose --env-file .env up -d
```

Validate from the host:

```bash
./scripts/validate-host.sh
```

The expected result is HTTP `404` on `/v1`, which confirms the service is reachable.

## 2. Create the first sandbox

Return to the repo root and open the menu:

```bash
cd ..
./manage.sh
```

Choose `Create project` and provide:

- sandbox name
- upstream `OPENAI_API_KEY`
- optional repository URL to clone

The generator creates:

- `sandboxes/projects/<name>/Dockerfile`
- `sandboxes/projects/<name>/docker-compose.yml`
- `sandboxes/projects/<name>/.env`
- `sandboxes/projects/<name>/.env.local`
- `sandboxes/projects/<name>/.factory-container-settings.json`
- `sandboxes/projects/<name>/repo/`

## 3. Start and verify

From the menu you can:

- build and start the sandbox
- enter Droid
- open a shell
- refresh models
- validate connectivity

Direct connectivity check:

```bash
./sandboxes/scripts/validate-sandbox.sh sandboxes/projects/<name>
```

Expected result: the sandbox reaches `http://codex-lb:2455/v1` successfully.
