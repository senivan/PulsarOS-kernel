#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dpdk-common.sh
source "${SCRIPT_DIR}/dpdk-common.sh"

usage() {
  echo "Usage: $0 PROFILE.env" >&2
}

[[ $# -eq 1 ]] || { usage; exit 2; }
load_profile "$1"

vendor="$(normalize_iommu_vendor "${IOMMU_VENDOR}")"
args=(
  "isolcpus=${DPDK_CORES}"
  "nohz_full=${DPDK_CORES}"
  "rcu_nocbs=${DPDK_CORES}"
  "irqaffinity=${HOUSEKEEPING_CORES}"
  "default_hugepagesz=${HUGEPAGE_SIZE}"
  "hugepagesz=${HUGEPAGE_SIZE}"
  "hugepages=${HUGEPAGES}"
)

case "${vendor}" in
  intel) args+=("intel_iommu=on" "iommu=pt") ;;
  amd) args+=("amd_iommu=on" "iommu=pt") ;;
  none) ;;
esac

if [[ "${LOW_LATENCY}" == "1" ]]; then
  args+=("audit=0" "processor.max_cstate=1")
elif [[ "${LOW_LATENCY}" != "0" ]]; then
  die "LOW_LATENCY must be 0 or 1"
fi

printf '%s\n' "${args[*]}"
