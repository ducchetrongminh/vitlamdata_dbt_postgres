# Onboarding

One-time setup for a new machine (or a blank WSL2 distro) working on this repo with Claude Code.

## 1. Clone under your Linux home directory

Not under `/mnt/c/...` (a Windows-mounted path) — the sandbox setup in step 3 refuses to run from there.

```bash
git clone <repo-url> ~/projects/vitlamdata_dbt_postgres
cd ~/projects/vitlamdata_dbt_postgres
```

## 2. Bootstrap the machine

```bash
./scripts/bootstrap-wsl.sh
```

Installs, in order: curl, Node.js, the Claude Code CLI, and this repo's plugins (`caveman`, `ponytail`). Node.js is required because the `ponytail` plugin's hooks run through `/bin/sh` and call `node` directly — without it you'll see `UserPromptSubmit hook error ... node: not found` on every prompt. Plugin install doesn't need a login — only running `claude` interactively does.

If this is a fresh Claude Code install, log in once it finishes:

```bash
claude
```

## 3. Set up the sandbox (optional but recommended, separate script)

```bash
./scripts/setup-claude-sandbox.sh
```

Installs `bubblewrap`/`socat` and, if your distro's AppArmor policy requires it, a profile granting `bwrap` userns capability. This repo's `.claude/settings.json` already configures sandbox behavior (filesystem restrictions, credential-file denies, open network egress) — this script only handles the OS-level dependencies that can't live in a committed settings file.

## 4. Start Claude Code and trust the folder

```bash
claude
```

On first run in this repo, Claude Code will ask to trust the folder — accept it so the marketplaces declared in `.claude/settings.json` (`caveman`, `ponytail`) register automatically.

## 5. Verify

Run `/sandbox` inside a session — it should show the sandbox active.

Filesystem checks (should be denied):

```
echo x > ~/FAIL1
python3 -c "open('/home/'+__import__('os').environ['USER']+'/FAIL2','w').write('x')"
cat ~/.dbt/profiles.yml
```

If `FAIL2` gets created, stop and report — the sandbox isn't enforcing.

Normal work should still run fine: `dbt debug`, `dbt parse`, `uv sync`, `git fetch`, and writes inside the repo.

## What each script does

| Script | Purpose |
|---|---|
| `scripts/bootstrap-wsl.sh` | curl, Node.js, Claude Code CLI, this repo's plugins (caveman, ponytail) |
| `scripts/setup-claude-sandbox.sh` | OS-level sandbox dependencies: bubblewrap, socat, AppArmor profile |

Both are safe to re-run.
