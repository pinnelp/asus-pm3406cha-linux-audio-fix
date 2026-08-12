#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
require_root
require_hda_verb
require_codec

mode="${1:-auto}"
case "$mode" in
  auto) mode=$(jack_mode) ;;
  speaker|headphone) ;;
  *) fail "Usage: sudo ./apply-profile.sh [speaker|headphone|auto]" ;;
esac

log "Target: $HDA_DEV ($TARGET_VENDOR / $TARGET_SUBSYS)"
log "Applying PM3406CHA $mode profile..."
apply_mode "$mode"
log "Profile writes completed."

if required_state_ok "$mode"; then
  log "Required state: PASS"
else
  warn "Required state did not fully match after the write. Run ./verify-state.sh $mode for details."
fi

log "Jack sense:       $(hda_get 0x21 0x0f09 0 || echo unavailable)"
log "GPIO data:        $(hda_get 0x01 0x0f15 0 || echo unavailable)"
log "Pin 0x14 control: $(hda_get 0x14 0x0f07 0 || echo unavailable), EAPD=$(hda_get 0x14 0x0f0c 0 || echo unavailable)"
log "Pin 0x21 control: $(hda_get 0x21 0x0f07 0 || echo unavailable), EAPD=$(hda_get 0x21 0x0f0c 0 || echo unavailable), sel=$(hda_get 0x21 0x0f01 0 || echo unavailable)"
