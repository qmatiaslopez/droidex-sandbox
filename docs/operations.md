# Operations

## Main entrypoint

Run:

```bash
./manage.sh
```

The menu is the intended operator interface for day-to-day use.

## Common tasks

### Create project

- scaffolds a new sandbox under `sandboxes/projects/<name>/`
- offers the shared default API key from `sandboxes/.env`
- writes `.env.local` only when you choose a project override
- discovers models through `codex-lb`
- optionally clones a repository into `repo/`

### Enter Droid

- starts the sandbox if needed
- opens the Droid CLI inside the `droid` container
- uses `/factory-config/settings.json` generated for that project

### Open sandbox shell

- opens an interactive shell inside the running sandbox
- useful for dependency installation, Git setup, and debugging

### Delete project

- removes the selected sandbox after explicit confirmation
- stops compose resources and removes local project data

## Advanced operations

These are still supported, but they are no longer shown in the interactive menu.

### Refresh models

- rereads `OPENAI_API_KEY` from `.env.local`, then project `.env`, then `sandboxes/.env`
- calls `codex-lb` model discovery
- rewrites `.factory-container-settings.json`

```bash
./sandboxes/scripts/refresh-models.sh <project>
```

### Validate connectivity

- checks that the sandbox can call `http://codex-lb:2455/v1/models`
- reuses `OPENAI_API_KEY` from `.env.local`, project `.env`, or `sandboxes/.env`
- use after proxy or network changes

```bash
./sandboxes/scripts/validate-sandbox.sh sandboxes/projects/<project>
```

### Rebuild project

- rebuilds the sandbox image for the selected project
- use after Dockerfile changes or CLI bootstrap changes

```bash
cd sandboxes/projects/<project>
docker compose build
```

## Runtime conventions

- Host access: `http://127.0.0.1:2455`
- Sandbox access: `http://codex-lb:2455/v1`
- Shared network name: `codex-lb-shared` by default
- Sandbox image tag: `droidex-sandbox:bookworm`

## Safe cleanup

Deleting a sandbox project removes:

- local repository clone
- project `.env.local`
- generated model settings
- project compose resources

Do not use project deletion if you need to preserve local repo state.
