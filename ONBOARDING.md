# Onboarding

One-time setup for a new machine (or a blank WSL2 distro) working on this repo with Claude Code.

## How Claude Code is contained here

Claude Code runs **without** its Bash sandbox in this repo (`.claude/settings.json`). The
boundary is the WSL distro itself: step 3 cuts it off from the Windows disk, so nothing
running in it, Claude Code included, can read or write Windows files. Inside the distro
Claude can run any command. Every command still goes through your permission mode
(prompts, or the auto-mode classifier).

That means Claude can read anything your Linux user can, including `~/.config/gh`, `.env`
and keys in `.tmp/`. Keep only credentials you are fine with it using in this distro, and
nothing else.

## 1. Clone under your Linux home directory

Not under `/mnt/c/...`: after step 3 the Windows drives are not mounted at all.

```bash
git clone <repo-url> ~/projects/vitlamdata_dbt_postgres
cd ~/projects/vitlamdata_dbt_postgres
```

## 2. Bootstrap the machine

```bash
./scripts/bootstrap-wsl.sh
```

Installs, in order: curl, Node.js, the Claude Code CLI, this repo's plugins (`caveman`, `ponytail`, `superpowers`), and `uv` plus the project's `.venv` (`uv sync`). Node.js is required because the `ponytail` plugin's hooks run through `/bin/sh` and call `node` directly — without it you'll see `UserPromptSubmit hook error ... node: not found` on every prompt. Plugin install doesn't need a login — only running `claude` interactively does.

If this is a fresh Claude Code install, log in once it finishes:

```bash
claude
```

## Python / dbt

Managed by `uv` (`pyproject.toml`, `uv.lock`, `.venv/`). Run `uv run dbt ...`, or `source .venv/bin/activate` once per shell and use `dbt ...` directly. Add deps with `uv add <pkg>`; commit `uv.lock`.

## 3. Cut the distro off from Windows

```bash
./scripts/harden-wsl.sh
```

Sets `[automount] enabled=false` and `[interop] enabled=false` in `/etc/wsl.conf`: no
Windows drive under `/mnt`, and no Windows `.exe` can start from WSL (a Windows process
would reach every drive). Then, from Windows PowerShell:

```powershell
wsl --shutdown
```

Reopen WSL and run `./scripts/harden-wsl.sh` again. It should end with `All OK.` It also
warns about the two ways around the boundary: a `NOPASSWD` sudo rule, and membership in
the `docker` group (both are root, and root can mount `C:` again).

After this, from WSL:

- `code .`, `explorer.exe` and `clip.exe` no longer work. Open the folder from VS Code on
  Windows with Remote - WSL.
- `claude`, `gh auth login` and `gcloud auth login` print a URL instead of opening the
  browser. Copy it.
- Clipboard:
  - Pasting text into the terminal and copying a mouse selection still work: the terminal
    app does both, on the Windows side.
  - Claude Code's own copy (fullscreen view, `/copy`) goes through the terminal's OSC 52
    support. Windows Terminal has it; check VS Code's terminal once. If it fails, select
    with the mouse instead (Shift+drag when the fullscreen view captures the mouse).
  - Pasting an image into Claude Code no longer works: it reads the Windows clipboard
    through `powershell.exe`. Save the image from Windows into the repo's git-ignored
    `.tmp/` (`\\wsl.localhost\<distro>\home\<user>\projects\vitlamdata_dbt_postgres\.tmp\`)
    and give Claude the path.

Run `sudo` only in your own terminal, never at Claude Code's `!` prompt: sudo remembers
your password for a few minutes, and Claude's next commands could reuse it.

## 4. Start Claude Code and trust the folder

```bash
claude
```

On first run in this repo, Claude Code will ask to trust the folder — accept it so the marketplaces declared in `.claude/settings.json` (`caveman`, `ponytail`) register automatically.

## 5. Verify

Ask Claude to run these. Each must fail:

```
ls /mnt/c
cmd.exe /c ver
```

The first fails with `No such file or directory`, the second with `command not found`.

Normal work should still run fine: `dbt debug`, `dbt parse`, `uv sync`, `git fetch`, `gh pr list`.

## What each script does

| Script | Purpose |
|---|---|
| `scripts/bootstrap-wsl.sh` | curl, Node.js, Claude Code CLI, this repo's plugins (caveman, ponytail, superpowers), uv + `.venv` |
| `scripts/harden-wsl.sh` | `/etc/wsl.conf`: no Windows drives, no Windows interop; checks sudo and docker |

Both are safe to re-run.
