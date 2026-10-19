#!/usr/bin/env bash
# Runs once per container create/rebuild (see devcontainer.json postCreateCommand).
set -euo pipefail

# Hand the claude-config-dbt and gcloud-config-dbt volumes to vscode. A new named
# volume is root-owned unless the image already has the folder; only chown when needed.
[ -O /home/vscode/.claude ] || sudo chown -R vscode:vscode /home/vscode/.claude
[ -O /home/vscode/.config/gcloud ] || sudo chown -R vscode:vscode /home/vscode/.config/gcloud

# gcloud: local dev opens the SSH tunnel to the warehouse with `gcloud compute ssh`
# (docs/architecture.md).
sudo apt-get update
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
sudo apt-get update && sudo apt-get install -y google-cloud-cli

# uv and the project's .venv. uv fetches the Python in .python-version itself.
curl -LsSf https://astral.sh/uv/install.sh | sh
"$HOME/.local/bin/uv" sync

# gh: the github-cli feature installs the binary but leaves it logged out, while
# git already works — the Dev Containers extension injects a credential helper
# that forwards the host's GitHub token. Borrow that same token so `gh pr create`
# works without a second, interactive login. Best-effort: with no credential,
# leave gh logged out rather than failing the whole postCreate.
if ! gh auth status >/dev/null 2>&1; then
	gh_token="$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | sed -n 's/^password=//p' || true)"
	if [ -n "${gh_token:-}" ] && printf '%s' "$gh_token" | gh auth login --with-token 2>/dev/null; then
		echo "gh: authenticated via the git credential helper"
	else
		echo "gh: no git credential available — run 'gh auth login' by hand if you need it"
	fi
	unset gh_token
fi

# Claude Code plugins: every enabledPlugins entry in .claude/settings.json.
# Add each extraKnownMarketplaces entry first: declaring it in settings.json does
# not clone it, and install then reports the plugin "not found in marketplace".
node -e 'for (const m of Object.values(require(process.argv[1]).extraKnownMarketplaces || {})) console.log(m.source.repo)' \
	"$PWD/.claude/settings.json" |
	while read -r repo; do claude plugin marketplace add "$repo"; done
node -e 'for (const [k, v] of Object.entries(require(process.argv[1]).enabledPlugins || {})) if (v) console.log(k)' \
	"$PWD/.claude/settings.json" |
	while read -r plugin; do claude plugin install "$plugin"; done
