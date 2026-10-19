# Onboarding

Work on this repo inside its devcontainer (`.devcontainer/`), with Claude Code
running in the container.

## How Claude Code is contained here

The container is the boundary. It sees no host folder and has no Docker socket, so
nothing in it, Claude Code included, can read or write your Windows or WSL files.
Claude Code's own sandbox is off: Docker blocks the user namespaces its bubblewrap
sandbox needs. Every command still goes through your permission mode (prompts, or
the auto-mode classifier).

Inside the container Claude can read anything the `vscode` user can: the `gh`
token, your gcloud login, `.env` and keys in `.tmp/`. Keep only credentials you
are fine with it using.

## 1. Open the container

On Windows, first turn off the VS Code setting **Dev › Containers: Execute In WSL**
(`dev.containers.executeInWSL`); with it on, the command below does not open the
container in Docker.

Run **Dev Containers: Clone Repository in Container Volume** and pick this repo.
The repo lives in a Docker volume.

`.devcontainer/postCreate.sh` installs gcloud, uv and the `.venv`, and the plugins
in `.claude/settings.json`, and logs `gh` in with the GitHub token VS Code already
forwards.

## 2. Log in

```bash
claude
gcloud auth login
```

`claude` and `gcloud` print a URL to open in your browser. The logins live in the
Docker volumes `claude-config-dbt` and `gcloud-config-dbt`, so they survive
container rebuilds.

## Python / dbt

Managed by `uv` (`pyproject.toml`, `uv.lock`, `.venv/`). Run `uv run dbt ...`, or `source .venv/bin/activate` once per shell and use `dbt ...` directly. Add deps with `uv add <pkg>`; commit `uv.lock`.

## Verify

Normal work should run fine: `uv run dbt debug`, `uv run dbt parse`, `uv sync`,
`git fetch`, `gh pr list`.
