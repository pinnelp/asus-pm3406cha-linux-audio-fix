#!/usr/bin/env bash
set -euo pipefail
LC_ALL=C

TARGET_VENDOR="0x10ec0256"
TARGET_SUBSYS="0x10433541"

fail() { echo "ERROR: $*" >&2; exit 1; }
log() { [[ "${QUIET:-0}" == 1 ]] || echo "$*"; }
warn() { echo "WARN: $*" >&2; }

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || fail "Run as root (use sudo)."
}

require_hda_verb() {
  command -v hda-verb >/dev/null 2>&1 || fail "hda-verb not found. Install it with: sudo apt install alsa-tools"
}

find_codec() {
  local d vendor subsys name
  CODEC_SYS="" HDA_DEV="" CARD_NUM="" CODEC_ADDR=""
  for d in /sys/class/sound/hwC*D*; do
    [[ -r "$d/vendor_id" && -r "$d/subsystem_id" ]] || continue
    vendor=$(tr '[:upper:]' '[:lower:]' < "$d/vendor_id" | tr -d '\n')
    subsys=$(tr '[:upper:]' '[:lower:]' < "$d/subsystem_id" | tr -d '\n')
    if [[ "$vendor" == "$TARGET_VENDOR" && "$subsys" == "$TARGET_SUBSYS" ]]; then
      CODEC_SYS="$d"
      name=${d##*/}
      HDA_DEV="/dev/snd/$name"
      if [[ "$name" =~ ^hwC([0-9]+)D([0-9]+)$ ]]; then
        CARD_NUM="${BASH_REMATCH[1]}"
        CODEC_ADDR="${BASH_REMATCH[2]}"
      fi
      [[ -e "$HDA_DEV" ]] || return 1
      export CODEC_SYS HDA_DEV CARD_NUM CODEC_ADDR
      return 0
    fi
  done
  return 1
}

require_codec() {
  find_codec || fail "Target codec $TARGET_VENDOR / $TARGET_SUBSYS not found."
}

hda_get() {
  local nid="$1" verb="$2" param="${3:-0}" out val
  out=$(hda-verb "$HDA_DEV" "$nid" "$verb" "$param" 2>&1) || {
    echo "$out" >&2
    return 1
  }
  val=$(sed -n 's/.*value = \(0x[0-9A-Fa-f]\+\).*/\1/p' <<<"$out" | tail -n1)
  [[ -n "$val" ]] || return 1
  printf '%s\n' "$val"
}

hda_set() {
  local nid="$1" verb="$2" param="$3" out
  out=$(hda-verb "$HDA_DEV" "$nid" "$verb" "$param" 2>&1) || {
    echo "$out" >&2
    return 1
  }
  if [[ "${VERBOSE:-0}" == 1 ]]; then
    echo "$out"
  fi
  return 0
}

get_coef() {
  local idx="$1"
  hda_set 0x20 0x500 "$idx" || return 1       # SET_COEF_INDEX
  hda_get 0x20 0x0c00 0                         # GET_PROC_COEF
}

set_coef() {
  local idx="$1" value="$2"
  hda_set 0x20 0x500 "$idx" || return 1       # SET_COEF_INDEX
  hda_set 0x20 0x400 "$value" || return 1     # SET_PROC_COEF
}

hex_eq() {
  local a="$1" b="$2"
  (( a == b ))
}

# Windows-reference values that proved writable/relevant in the successful Linux test.
# 0x18 is deliberately NOT written: on this Linux codec state it reads 0x003c even in
# working headphone mode and rejected the 0x0003 Windows reference value.
# 0x23 is still issued best-effort because it was part of the known-good tested sequence,
# but is not used as a success/failure condition; Linux may keep 0x8804.
apply_common_prefix() {
  local gpio_data="$1"
  hda_set 0x01 0x716 0x04 || return 1  # SET_GPIO_MASK: GPIO2
  hda_set 0x01 0x717 0x04 || return 1  # SET_GPIO_DIRECTION: GPIO2 output
  hda_set 0x01 0x715 "$gpio_data" || return 1
}

apply_speaker_profile() {
  # Hold speaker amp low while changing codec state, then enable it last.
  apply_common_prefix 0x00 || return 1

  set_coef 0x06 0x6104 || return 1
  set_coef 0x10 0x7f20 || return 1
  set_coef 0x16 0x0e50 || return 1
  set_coef 0x1b 0x0e4b || return 1
  set_coef 0x23 0x8804 || return 1  # best-effort readback / dynamic on Linux
  set_coef 0x30 0x9004 || return 1
  set_coef 0x35 0x8d6a || return 1
  set_coef 0x37 0xfe16 || return 1
  set_coef 0x45 0xd089 || return 1
  set_coef 0x46 0x0034 || return 1
  set_coef 0x49 0x0049 || return 1

  # Windows speaker pin state observed on PM3406CHA.
  hda_set 0x14 0x70c 0x00 || return 1  # EAPD off
  hda_set 0x14 0x707 0x40 || return 1  # speaker OUT
  hda_set 0x21 0x701 0x01 || return 1  # HP selects DAC3 / connection 1
  hda_set 0x21 0x70c 0x00 || return 1  # EAPD off
  hda_set 0x21 0x707 0x00 || return 1  # HP pin disabled

  hda_set 0x01 0x715 0x04 || return 1  # speaker amp enable via GPIO2
}

apply_headphone_profile() {
  apply_common_prefix 0x00 || return 1  # speaker amp disabled in headphone mode

  set_coef 0x06 0x6104 || return 1
  set_coef 0x10 0x7f20 || return 1
  set_coef 0x16 0x0c50 || return 1
  set_coef 0x1b 0x0e6b || return 1
  set_coef 0x23 0x88f4 || return 1  # best-effort readback / dynamic on Linux
  set_coef 0x30 0x9007 || return 1
  set_coef 0x35 0x8d6a || return 1
  set_coef 0x37 0xfe06 || return 1
  set_coef 0x45 0xd489 || return 1
  set_coef 0x46 0x00f4 || return 1
  set_coef 0x49 0x0149 || return 1

  # Windows headphone pin state observed on PM3406CHA.
  hda_set 0x14 0x70c 0x00 || return 1
  hda_set 0x14 0x707 0x40 || return 1
  hda_set 0x21 0x701 0x01 || return 1
  hda_set 0x21 0x70c 0x00 || return 1
  hda_set 0x21 0x707 0xc0 || return 1  # OUT | HP
}

jack_mode() {
  local sense
  sense=$(hda_get 0x21 0x0f09 0) || return 1
  if (( sense & 0x80000000 )); then
    echo headphone
  else
    echo speaker
  fi
}

apply_mode() {
  case "$1" in
    speaker) apply_speaker_profile ;;
    headphone) apply_headphone_profile ;;
    *) return 2 ;;
  esac
}

# Required signature intentionally excludes coef 0x18, coef 0x23 and EAPD readback.
# Those fields were observed to be dynamic / asynchronously rewritten under Linux while
# audio still worked correctly.
required_state_ok() {
  local mode="$1" gpio hp_ctrl
  [[ "$mode" == headphone ]] && { gpio=0x00; hp_ctrl=0xc0; } || { gpio=0x04; hp_ctrl=0x00; }

  local idx exp got
  if [[ "$mode" == headphone ]]; then
    local -a pairs=(06:6104 10:7f20 16:0c50 1b:0e6b 30:9007 35:8d6a 37:fe06 45:d489 46:00f4 49:0149)
  else
    local -a pairs=(06:6104 10:7f20 16:0e50 1b:0e4b 30:9004 35:8d6a 37:fe16 45:d089 46:0034 49:0049)
  fi

  for item in "${pairs[@]}"; do
    idx="0x${item%%:*}"; exp="0x${item##*:}"
    got=$(get_coef "$idx") || return 1
    hex_eq "$got" "$exp" || return 1
  done

  got=$(hda_get 0x01 0x0f16 0) || return 1; hex_eq "$got" 0x04 || return 1
  got=$(hda_get 0x01 0x0f17 0) || return 1; hex_eq "$got" 0x04 || return 1
  got=$(hda_get 0x01 0x0f15 0) || return 1; hex_eq "$got" "$gpio" || return 1
  got=$(hda_get 0x14 0x0f07 0) || return 1; hex_eq "$got" 0x40 || return 1
  got=$(hda_get 0x21 0x0f01 0) || return 1; hex_eq "$got" 0x01 || return 1
  got=$(hda_get 0x21 0x0f07 0) || return 1; hex_eq "$got" "$hp_ctrl" || return 1
  return 0
}
