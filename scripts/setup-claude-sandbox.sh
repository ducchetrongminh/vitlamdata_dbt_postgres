#!/usr/bin/env bash
# One-time, per-clone setup for Claude Code's OS-level sandbox (bubblewrap).
#
# Most of the sandbox config lives in the repo's committed .claude/settings.json
# and applies automatically to every clone. One thing can't live there and
# must be set up locally on each machine: bubblewrap/socat (OS packages) and,
# if required, an AppArmor profile for bwrap's userns capability.
#
# Note: this repo's settings.json does not set sandbox.network.allowedDomains,
# so websites aren't restricted to a fixed list — Claude will just prompt the
# first time it needs a new site. Filesystem access (reading/writing outside
# this project folder) is still locked down.
#
# Safe to re-run: package install is idempotent.
set -euo pipefail

echo "== Preconditions =="
if [[ "$(uname -r)" != *WSL2* ]]; then
  echo "Note: not running under WSL2 (uname -r: $(uname -r)). Continuing anyway —"
  echo "the sandbox also works on native Linux — but AppArmor/WSL-specific notes below may not apply."
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
case "$REPO_ROOT" in
  /mnt/*)
    echo "ERROR: repo is at $REPO_ROOT, under a Windows-mounted path (9p/drvfs)." >&2
    echo "Move the clone under your Linux home directory (e.g. ~/projects/...) and re-run." >&2
    exit 1
    ;;
esac
echo "Repo root: $REPO_ROOT"

echo
echo "== Installing bubblewrap + socat =="
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get install -y bubblewrap socat
else
  echo "No apt-get found. Install 'bubblewrap' and 'socat' with your distro's package manager, then re-run." >&2
  exit 1
fi

echo
echo "== Checking AppArmor userns restriction =="
SYSCTL_KEY="kernel.apparmor_restrict_unprivileged_userns"
SYSCTL_VAL="$(sysctl -n "$SYSCTL_KEY" 2>/dev/null || true)"
if [[ "$SYSCTL_VAL" == "1" ]]; then
  echo "AppArmor restricts unprivileged userns; installing a profile granting bwrap the userns capability."
  if [[ -e /etc/apparmor.d/bwrap ]]; then
    sudo cp /etc/apparmor.d/bwrap "/etc/apparmor.d/bwrap.bak.$(date +%Y%m%d%H%M%S)"
  fi
  sudo tee /etc/apparmor.d/bwrap > /dev/null <<'EOF'
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
  include if exists <local/bwrap>
}
EOF
  sudo systemctl reload apparmor
  echo "AppArmor profile installed and reloaded."
else
  echo "Sysctl '$SYSCTL_KEY' is '${SYSCTL_VAL:-<absent>}' (not '1') — no AppArmor profile needed."
fi

cat <<'EOF'

== Next: verify ==
Run in Claude Code:
  /sandbox                                   # should show active

Then, inside a Claude Code session in this repo, confirm these are denied
(filesystem checks only — websites aren't restricted, so there's no network
deny test to run):
  echo x > ~/FAIL1
  python3 -c "open('/home/'+__import__('os').environ['USER']+'/FAIL2','w').write('x')"
  cat ~/.dbt/profiles.yml

If FAIL2 gets created, stop and report — the sandbox isn't enforcing.

Then confirm normal work still runs: dbt debug, dbt parse, uv sync, git fetch,
and a write inside the repo. dbt debug is also the first real test of whether
a raw Postgres TCP connection works fine inside the sandbox — this hasn't
been verified against the docs, only against how the proxy is documented to
work for HTTP(S).
EOF
