# Security

## Sensitive files

These files contain runtime secrets or generated credentials and must stay local:

- `codex-lb/.env`
- `sandboxes/projects/<name>/.env.local`
- `sandboxes/projects/<name>/.factory-container-settings.json`

## Persistent state

`codex-lb` stores its state in the Docker volume defined by `CODEX_LB_VOLUME`.
Do not replace that volume with an empty one unless you intentionally want a fresh proxy state.

## Network exposure

- publish only `127.0.0.1:${CODEX_LB_PORT}:2455`
- sandboxes should reach the proxy through the shared Docker network alias `codex-lb`
- do not expose additional ports unless there is a documented operational need

## Publishing hygiene

Before every push:

- review `git diff --cached`
- confirm no `.env` file is staged
- confirm no generated sandbox project is staged
- confirm documentation does not mention personal paths or local-only runtime details
