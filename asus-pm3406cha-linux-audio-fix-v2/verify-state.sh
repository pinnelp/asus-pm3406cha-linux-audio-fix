#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
require_root
require_hda_verb
require_codec

mode="${1:-auto}"
[[ "$mode" == auto ]] && mode=$(jack_mode)
[[ "$mode" == speaker || "$mode" == headphone ]] || fail "Usage: sudo ./verify-state.sh [speaker|headphone|auto]"

if [[ "$mode" == speaker ]]; then
  required_pairs=(06:6104 10:7f20 16:0e50 1b:0e4b 30:9004 35:8d6a 37:fe16 45:d089 46:0034 49:0049)
  exp_gpio=0x04; exp_hp=0x00
  ref18=0x003c; ref23=0x8804
else
  required_pairs=(06:6104 10:7f20 16:0c50 1b:0e6b 30:9007 35:8d6a 37:fe06 45:d489 46:00f4 49:0149)
  exp_gpio=0x00; exp_hp=0xc0
  ref18=0x0003; ref23=0x88f4
fi

failures=0
echo "Verifying required $mode state on $HDA_DEV"
for p in "${required_pairs[@]}"; do
  idx="0x${p%%:*}"; exp="0x${p##*:}"; got=$(get_coef "$idx")
  if hex_eq "$got" "$exp"; then
    printf 'PASS coef %-4s = %s\n' "$idx" "$got"
  else
    printf 'FAIL coef %-4s expected %s got %s\n' "$idx" "$exp" "$got"
    failures=1
  fi
done

for spec in \
  "GPIO_MASK 0x01 0x0f16 0x04" \
  "GPIO_DIR 0x01 0x0f17 0x04" \
  "GPIO_DATA 0x01 0x0f15 $exp_gpio" \
  "PIN14_CTRL 0x14 0x0f07 0x40" \
  "PIN21_SEL 0x21 0x0f01 0x01" \
  "PIN21_CTRL 0x21 0x0f07 $exp_hp"; do
  read -r label nid verb exp <<<"$spec"
  got=$(hda_get "$nid" "$verb" 0)
  if hex_eq "$got" "$exp"; then
    printf 'PASS %-11s = %s\n' "$label" "$got"
  else
    printf 'FAIL %-11s expected %s got %s\n' "$label" "$exp" "$got"
    failures=1
  fi
done

echo
echo "Dynamic/reference fields (informational only; do not affect exit status):"
for spec in \
  "COEF18 0x20 coef18 $ref18" \
  "COEF23 0x20 coef23 $ref23" \
  "PIN14_EAPD 0x14 0x0f0c 0x00" \
  "PIN21_EAPD 0x21 0x0f0c 0x00"; do
  read -r label nid verb ref <<<"$spec"
  if [[ "$verb" == coef18 ]]; then got=$(get_coef 0x18)
  elif [[ "$verb" == coef23 ]]; then got=$(get_coef 0x23)
  else got=$(hda_get "$nid" "$verb" 0)
  fi
  if hex_eq "$got" "$ref"; then
    printf 'INFO %-11s = %s (matches Windows reference)\n' "$label" "$got"
  else
    printf 'INFO %-11s = %s (Windows reference %s; Linux may manage this dynamically)\n' "$label" "$got" "$ref"
  fi
done

exit "$failures"
