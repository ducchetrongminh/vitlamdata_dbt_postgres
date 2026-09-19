#!/usr/bin/env bash
# One-time, per-machine bootstrap for a blank WSL2 distro to run this repo's
# Claude Code setup end to end. Assumes nothing is installed yet.
#
# Steps:
#   1. curl (prerequisite for the installers below, in case this is a truly
#      bare distro image).
#   2. Node.js, via the NodeSource apt repo. Needed for Claude Code plugin
#      hooks (e.g. ponytail's UserPromptSubmit hook, which runs through
#      /bin/sh and calls `node` directly). NodeSource + apt (not nvm) puts
#      `node` in /usr/bin, available to every shell including non-interactive
#      ones — nvm requires sourcing shell rc files, which non-interactive
#      hook shells skip.
#   3. The Claude Code CLI itself, via the official native installer.
#   4. The plugins this repo's .claude/settings.json declares under
#      `enabledPlugins`/`extraKnownMarketplaces` (caveman, ponytail).
#      Registering a marketplace in settings.json auto-registers it once you
#      trust the folder, but does NOT install a plugin that comes from an
#      external source (a GitHub repo, here) — Claude Code shows it as "not
#      installed" until `claude plugin install` runs. Installing doesn't
#      require being logged in — only running `claude` interactively does.
#      See: https://code.claude.com/docs/en/discover-plugins#configure-team-marketplaces
#
#   5. uv (Python env manager), then `uv sync` to build .venv from
#      pyproject.toml/uv.lock (dbt-core + dbt-postgres). Run dbt with
#      `uv run dbt ...` or `source .venv/bin/activate`.
#
# For the OS-level sandbox (bubblewrap/socat/AppArmor), see
# scripts/setup-claude-sandbox.sh — run it too if you want sandboxing.
#
# Safe to re-run; every step is skipped if already satisfied.
set -euo pipefail

NODE_MAJOR="${NODE_MAJOR:-22}" # LTS as of 2026

echo "== Step 1: curl =="
if command -v curl >/dev/null 2>&1; then
  echo "curl already installed"
elif command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y curl ca-certificates
else
  echo "No apt-get found and no curl. Install curl with your distro's package manager, then re-run." >&2
  exit 1
fi

echo
echo "== Step 2: Node.js =="
if command -v node >/dev/null 2>&1; then
  echo "node already installed: $(node --version) at $(command -v node)"
elif command -v apt-get >/dev/null 2>&1; then
  echo "Adding NodeSource apt repo for Node.js ${NODE_MAJOR}.x"
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
  echo "Installing nodejs"
  sudo apt-get install -y nodejs
  node --version
  npm --version
else
  echo "No apt-get found. Install Node.js ${NODE_MAJOR}.x with your distro's package manager instead." >&2
  exit 1
fi

echo
echo "== Step 3: Claude Code CLI =="
if command -v claude >/dev/null 2>&1; then
  echo "claude already installed: $(claude --version)"
else
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  if ! command -v claude >/dev/null 2>&1; then
    echo "claude was installed but isn't on PATH yet. Open a new shell and re-run this script" >&2
    echo "to finish Step 4, or run the two plugin-install lines below yourself." >&2
    exit 1
  fi
  claude --version
fi

echo
echo "== Step 4: Claude Code plugins (caveman, ponytail) =="
claude plugin install caveman@caveman
claude plugin install ponytail@ponytail

echo
echo "== Step 5: uv + Python env =="
export PATH="$HOME/.local/bin:$PATH"
if command -v uv >/dev/null 2>&1; then
  echo "uv already installed: $(uv --version)"
else
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
(cd "$(dirname "$0")/.." && uv sync)

echo
echo "Done. Log in with 'claude' if this is a fresh install, then start a new"
echo "session so hook shells pick up the new PATH and plugins take effect."
