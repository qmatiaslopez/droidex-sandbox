# Setup

## Prerequisites

- Linux host with Docker available for the runtime user
- `bash`, `curl`, `git`, `jq`, `python3`
- Network access for the Droid CLI installation inside sandbox images
- a valid sandbox API key for `codex-lb`

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

Optional host smoke check:

```bash
curl -i http://127.0.0.1:2455/v1
```

The expected result is HTTP `404` on `/v1`, which confirms the service is reachable on localhost.

## 2. Create the first sandbox

Create the shared sandbox defaults file:

```bash
cp sandboxes/.env.example sandboxes/.env
```

Set `OPENAI_API_KEY` in `sandboxes/.env` to the default key you want all projects to use unless overridden.

Return to the repo root and open the menu:

```bash
cd ..
./manage.sh
```

Choose `Create project` and provide:

- sandbox name
- sandbox profile: `base`, `python`, or `npm`
- choose whether to use the default `OPENAI_API_KEY` from `sandboxes/.env`
- if needed, enter another `codex-lb` API key to store only for that project
- optional repository URL to clone

If `sandboxes/.env` has a default key, the menu offers to reuse it and defaults that answer to `Y`.
If you choose another key, it is written to `sandboxes/projects/<name>/.env.local` as a project-specific override.

The generator creates:

- `sandboxes/projects/<name>/Dockerfile`
- `sandboxes/projects/<name>/docker-compose.yml`
- `sandboxes/projects/<name>/.env`
- `sandboxes/projects/<name>/.env.local` when needed for an override
- `sandboxes/projects/<name>/.factory-container-settings.json`
- `sandboxes/projects/<name>/repo/`

New projects start from one of these runtime bases:

- `base`: minimal Debian-based sandbox with Droid and the common CLI tooling only
- `python`: Python runtime preinstalled in the image
- `npm`: Node.js and npm preinstalled in the image

Sandbox containers run as the non-root user `dev` and do not include `sudo`. Add system-level packages in the Dockerfile instead of installing them at runtime.
When the sandbox starts Droid access, it writes `/home/dev/.factory/AGENTS.md` inside the container so Droid has stable instructions about the sandbox environment.

## 3. Start and verify

From the menu you can:

- build and start the sandbox
- enter or resume Droid
- open a shell

When you choose Droid, the tool attaches to a persistent `tmux` session inside the sandbox container. Detach with `Ctrl+b` then `d` and return later through the same menu action.

Direct connectivity check:

```bash
./sandboxes/scripts/validate-sandbox.sh sandboxes/projects/<name>
```

Expected result: the sandbox reaches `http://codex-lb:2455/v1/models` with the project API key and receives a non-empty model list.
