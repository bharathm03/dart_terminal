#!/usr/bin/env bash

set -euo pipefail

# Verifies an Android 64-bit .so is linked with >= 16 KB ELF LOAD-segment
# alignment, the Android 15 / Google Play page-size requirement. 32-bit
# armeabi-v7a is exempt (16 KB pages are a 64-bit-only feature) and should
# not be passed to this script.

MIN_ALIGN=16384

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <path-to-libportable_pty_rs.so>" >&2
  exit 64
fi

if ! command -v readelf >/dev/null 2>&1; then
  echo "readelf is required but was not found on PATH." >&2
  exit 69
fi

LIB_INPUT="$1"
LIB_PATH="$(readlink -f "$LIB_INPUT" 2>/dev/null || realpath "$LIB_INPUT" 2>/dev/null || printf '%s' "$LIB_INPUT")"

if [[ ! -f "$LIB_PATH" ]]; then
  echo "Shared library not found: $LIB_INPUT" >&2
  exit 66
fi

echo "Inspecting Android library: $LIB_PATH"
file "$LIB_PATH"

program_headers="$(readelf -lW "$LIB_PATH")"
printf '%s\n' "$program_headers"

# The widest LOAD-segment alignment is the effective page alignment. readelf
# prints alignment in hex (e.g. 0x4000); compare numerically in bash (which
# parses the 0x prefix) rather than sorting the hex strings, which would order
# them lexicographically (0x10000 < 0x4000) and pick the wrong maximum.
max_align=0
while read -r seg_align; do
  (( seg_align > max_align )) && max_align=$seg_align
done < <(awk '$1 == "LOAD" { print $NF }' <<<"$program_headers")

if (( max_align == 0 )); then
  echo "::error::No LOAD segments found in $LIB_PATH" >&2
  exit 1
fi

if (( max_align < MIN_ALIGN )); then
  echo "::error::$LIB_PATH has ${max_align}-byte LOAD alignment (< $MIN_ALIGN); fails the Android 15 16 KB page-size gate" >&2
  exit 1
fi

echo "Verified: $LIB_PATH is ${max_align}-byte aligned (>= $MIN_ALIGN)"
