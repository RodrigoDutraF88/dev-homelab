#!/usr/bin/env bash
# Install (or refresh) the systemd user timer that runs the Postgres backup daily.
#
# The unit files in infrastructure/systemd/ are the source of truth. They contain
# a __REPO_ROOT__ placeholder because a systemd unit cannot interpolate a path the
# way Compose interpolates .env, and hardcoding an absolute path into a committed
# file would break on any other machine. This script resolves it and writes the
# result into ~/.config/systemd/user/, so the installed copies are generated —
# edit the repo, re-run this.
#
# Why a user timer rather than a system one: it runs as the account that owns the
# repo, the .env it reads and the backup directory it writes to, so nothing needs
# root and no file ends up owned by it. The cost is that user units stop when the
# last session ends, which is what lingering below turns off.
#
# Usage:  make backup-timer      or      ./scripts/install-backup-timer.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/infrastructure/systemd"
DEST_DIR="$HOME/.config/systemd/user"
UNITS=(dev-homelab-backup.service dev-homelab-backup.timer)

for u in "${UNITS[@]}"; do
  [[ -f "$SRC_DIR/$u" ]] || { echo "missing unit file: $SRC_DIR/$u" >&2; exit 1; }
done

[[ -x "$REPO_ROOT/scripts/backup-postgres.sh" ]] \
  || { echo "scripts/backup-postgres.sh is not executable" >&2; exit 1; }

mkdir -p "$DEST_DIR"
for u in "${UNITS[@]}"; do
  sed "s|__REPO_ROOT__|$REPO_ROOT|g" "$SRC_DIR/$u" > "$DEST_DIR/$u"
  echo "installed $DEST_DIR/$u"
done

systemctl --user daemon-reload
systemctl --user enable --now dev-homelab-backup.timer

# Without lingering, every user unit is killed when the last session closes, so a
# timer on a machine nobody is logged into does nothing at all. This is the one
# step that needs elevation, and it is asked for explicitly rather than silently.
if [[ "$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null)" != "yes" ]]; then
  echo
  echo "Lingering is off for $USER, so this timer will not run while you are logged out."
  echo "Enable it with:"
  echo
  echo "    sudo loginctl enable-linger $USER"
  echo
fi

echo
systemctl --user list-timers dev-homelab-backup.timer --no-pager || true
