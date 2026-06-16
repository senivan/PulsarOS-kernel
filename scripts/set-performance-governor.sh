#!/usr/bin/env bash
set -euo pipefail

changed=0

if command -v cpupower >/dev/null 2>&1; then
  cpupower frequency-set -g performance || true
fi

for governor in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  [[ -e "${governor}" ]] || continue
  if [[ -w "${governor}" ]]; then
    echo performance > "${governor}" || true
    changed=$((changed + 1))
  fi
done

echo "CPU governor state:"
for governor in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  [[ -r "${governor}" ]] || continue
  printf '%s: %s\n' "$(basename "$(dirname "$(dirname "${governor}")")")" "$(cat "${governor}")"
done

if [[ ${changed} -eq 0 ]] && ! command -v cpupower >/dev/null 2>&1; then
  echo "No writable cpufreq governors found and cpupower is unavailable."
fi
