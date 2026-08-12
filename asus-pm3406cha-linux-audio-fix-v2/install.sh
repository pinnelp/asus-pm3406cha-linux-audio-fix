#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
require_root
require_hda_verb
require_codec

if [[ "${1:-}" != "--confirmed" ]]; then
  cat >&2 <<'MSG'
Installation is intentionally gated.

First test the live profile that matches the current jack state:
  sudo ./apply-profile.sh auto
  sudo ./verify-state.sh auto

Test speakers and 3.5 mm headphones before installing persistently.
Then run:
  sudo ./install.sh --confirmed
MSG
  exit 2
fi

PREFIX=/usr/local/lib/pm3406cha-audio-fix
install -d -m 0755 "$PREFIX"
install -m 0755 "$SCRIPT_DIR/lib.sh" "$PREFIX/lib.sh"
install -m 0755 "$SCRIPT_DIR/apply-profile.sh" "$PREFIX/apply-profile.sh"
install -m 0755 "$SCRIPT_DIR/verify-state.sh" "$PREFIX/verify-state.sh"
install -m 0755 "$SCRIPT_DIR/pm3406cha-audio-daemon.sh" "$PREFIX/pm3406cha-audio-daemon.sh"
install -m 0644 "$SCRIPT_DIR/pm3406cha-audio-fix.service" /etc/systemd/system/pm3406cha-audio-fix.service

systemctl daemon-reload
systemctl enable --now pm3406cha-audio-fix.service

echo "Installed PM3406CHA audio workaround."
echo "Status: systemctl status pm3406cha-audio-fix.service --no-pager"
echo "Logs:   journalctl -u pm3406cha-audio-fix.service -b"
