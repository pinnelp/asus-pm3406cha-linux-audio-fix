#!/usr/bin/env bash
set -euo pipefail
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }

systemctl disable --now pm3406cha-audio-fix.service 2>/dev/null || true
rm -f /etc/systemd/system/pm3406cha-audio-fix.service
rm -rf /usr/local/lib/pm3406cha-audio-fix
systemctl daemon-reload

echo "Removed PM3406CHA runtime audio workaround."
echo "Reboot to return the codec to the distribution's normal initialization state."
