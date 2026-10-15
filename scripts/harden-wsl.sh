#!/usr/bin/env bash
# One-time, per-distro: keep everything that runs in this WSL distro, Claude Code
# included, away from the Windows disk. Claude Code runs without its Bash sandbox
# in this repo (.claude/settings.json), so this distro is the boundary.
#
# /etc/wsl.conf:
#   [automount] enabled=false   C:, D:, ... are not mounted under /mnt.
#   [interop]   enabled=false   No Windows .exe starts from WSL. A Windows process
#                               runs as your Windows user and reaches every drive,
#                               mounted here or not (cmd.exe, powershell.exe, ...).
#
# Two things still get around it, so this script checks them:
#   - root: `mount -t drvfs C: /mnt/c` works with automount off, and root can
#     edit /etc/wsl.conf back. Keep sudo behind your password (no NOPASSWD).
#   - the docker group: `docker run --privileged -v /:/host ...` is root.
#
# Side effects: `code .`, `explorer.exe`, `clip.exe` and browser auto-open no
# longer work from WSL. Open the folder from VS Code (Remote - WSL) instead, and
# copy login URLs (claude, gh, gcloud) into the browser by hand.
#
# Run it, then `wsl --shutdown` from Windows PowerShell, reopen WSL, run it again:
# the second run should report everything OK. Safe to re-run.
set -euo pipefail

[[ "$(uname -r)" == *WSL2* ]] || { echo "Not WSL2 (uname -r: $(uname -r))." >&2; exit 1; }

echo "== /etc/wsl.conf =="
# configparser keeps the other sections ([boot], [user], ...) but drops comments.
sudo cp /etc/wsl.conf "/etc/wsl.conf.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
sudo python3 -I - <<'EOF'
import configparser
c = configparser.ConfigParser()
c.optionxform = str  # keep key case (appendWindowsPath)
c.read("/etc/wsl.conf")
want = {"automount": {"enabled": "false"},
        "interop": {"enabled": "false", "appendWindowsPath": "false"}}
changed = False
for section, keys in want.items():
    if not c.has_section(section):
        c.add_section(section)
    for k, v in keys.items():
        if c.get(section, k, fallback=None) != v:
            c.set(section, k, v)
            changed = True
if changed:
    with open("/etc/wsl.conf", "w") as f:
        c.write(f)
print("updated" if changed else "already set")
EOF
cat /etc/wsl.conf

echo
echo "== Current state =="
ok=1
if mount | grep -qE ' type (9p|drvfs) .*aname=drvfs'; then
  echo "NOT YET: Windows drives are mounted. Run 'wsl --shutdown' in Windows PowerShell, reopen WSL, re-run."
  ok=0
else
  echo "OK: no Windows drive mounted"
fi
# WSL registers WSLInterop (or WSLInterop-late) as a binfmt handler only while interop is on.
if grep -qs '^enabled' /proc/sys/fs/binfmt_misc/WSLInterop*; then
  echo "NOT YET: Windows interop is on. Run 'wsl --shutdown' in Windows PowerShell, reopen WSL, re-run."
  ok=0
else
  echo "OK: Windows interop off"
fi
if sudo grep -rqs NOPASSWD /etc/sudoers /etc/sudoers.d; then
  echo "WARN: a NOPASSWD sudo rule exists; anything running as you can become root:"
  sudo grep -rs NOPASSWD /etc/sudoers /etc/sudoers.d
  ok=0
else
  echo "OK: sudo asks for your password"
fi
if id -nG | tr ' ' '\n' | grep -qx docker; then
  echo "WARN: $USER is in the docker group, which is root. Remove it with"
  echo "      'sudo gpasswd -d $USER docker' if you don't need Docker here."
  ok=0
else
  echo "OK: not in the docker group"
fi

echo
[[ $ok == 1 ]] && echo "All OK." || echo "Fix the items above."
