#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dpdk-common.sh
source "${SCRIPT_DIR}/dpdk-common.sh"

[[ $# -eq 1 ]] || die "Usage: $0 PROFILE.env"
load_profile "$1"
need_root

moved=0
skipped=0
mask="$(cpu_list_to_hex_mask "${HOUSEKEEPING_CORES}")"

if [[ -w /proc/irq/default_smp_affinity ]]; then
  echo "${mask}" > /proc/irq/default_smp_affinity 2>/dev/null || true
fi

for irq_dir in /proc/irq/[0-9]*; do
  [[ -d "${irq_dir}" ]] || continue
  if [[ -w "${irq_dir}/smp_affinity_list" ]]; then
    if echo "${HOUSEKEEPING_CORES}" > "${irq_dir}/smp_affinity_list" 2>/dev/null; then
      moved=$((moved + 1))
    else
      skipped=$((skipped + 1))
    fi
  elif [[ -w "${irq_dir}/smp_affinity" ]]; then
    if echo "${mask}" > "${irq_dir}/smp_affinity" 2>/dev/null; then
      moved=$((moved + 1))
    else
      skipped=$((skipped + 1))
    fi
  else
    skipped=$((skipped + 1))
  fi
done

echo "IRQ housekeeping CPUs: ${HOUSEKEEPING_CORES}"
echo "IRQ housekeeping mask: ${mask}"
echo "IRQs moved: ${moved}"
echo "IRQs skipped: ${skipped}"
