#!/usr/bin/env bash
set -euo pipefail
PREFIX="${PM3406CHA_PREFIX:-/usr/local/lib/pm3406cha-audio-fix}"
# shellcheck source=lib.sh
source "$PREFIX/lib.sh"
require_root
require_hda_verb

last_mode=""
last_candidate=""
stable_reads=0
codec_was_present=0

while true; do
  if ! find_codec >/dev/null 2>&1; then
    codec_was_present=0
    last_mode=""
    last_candidate=""
    stable_reads=0
    sleep 1
    continue
  fi

  # Codec appearing again after suspend/resume counts as a fresh initialization.
  if (( codec_was_present == 0 )); then
    codec_was_present=1
    mode=$(jack_mode) || { sleep 0.25; continue; }
    if apply_mode "$mode"; then
      logger -t pm3406cha-audio-fix "initialized $mode profile on $HDA_DEV"
      last_mode="$mode"
    else
      logger -t pm3406cha-audio-fix "failed to initialize $mode profile on $HDA_DEV"
    fi
    last_candidate="$mode"
    stable_reads=1
    sleep 0.25
    continue
  fi

  mode=$(jack_mode) || { sleep 0.25; continue; }

  if [[ "$mode" == "$last_candidate" ]]; then
    (( stable_reads += 1 ))
  else
    last_candidate="$mode"
    stable_reads=1
  fi

  # Two identical reads (~250 ms apart) debounce the physical jack event.
  if [[ "$mode" != "$last_mode" && $stable_reads -ge 2 ]]; then
    if apply_mode "$mode"; then
      logger -t pm3406cha-audio-fix "jack transition: applied $mode profile on $HDA_DEV"
      last_mode="$mode"
    else
      logger -t pm3406cha-audio-fix "jack transition: failed to apply $mode profile on $HDA_DEV"
    fi
  fi

  sleep 0.25
done
