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
- stores the project API key in `.env.local`
- discovers models through `codex-lb`
- optionally clones a repository into `repo/`

### Enter Droid

- starts the sandbox if needed
- opens the Droid CLI inside the `droid` container
- uses `/factory-config/settings.json` generated for that project

### Open sandbox shell

- opens an interactive shell inside the running sandbox
- useful for dependency installation, Git setup, and debugging

### Refresh models

- rereads `OPENAI_API_KEY` from `.env.local`
- calls `codex-lb` model discovery
- rewrites `.factory-container-settings.json`

### Validate connectivity

- checks that the sandbox can reach `http://codex-lb:2455/v1`
- should return success after proxy or network changes

### Rebuild project

- rebuilds the sandbox image for the selected project
- use after Dockerfile changes or CLI bootstrap changes

## Runtime conventions

- Host access: `http://127.0.0.1:2455`
- Sandbox access: `http://codex-lb:2455/v1`
- Shared network name: `codex-lb-shared` by default
- Sandbox image tag: `droidex-sandbox:bookworm`

## Safe cleanup

Deleting a sandbox project removes:

- local repository clone
- `.env.local`
- generated model settings
- project compose resources

Do not use project deletion if you need to preserve local repo state.
