#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dpdk-common.sh
source "${SCRIPT_DIR}/dpdk-common.sh"

printf '%-14s %-18s %-10s %-6s %-10s %s\n' "PCI" "CLASS" "DRIVER" "NUMA" "IOMMU" "DEVICE"
for dev in /sys/bus/pci/devices/*; do
  [[ -e "${dev}" ]] || continue
  pci="$(basename "${dev}")"
  class="$(cat "${dev}/class" 2>/dev/null || echo unknown)"
  case "${class}" in
    0x020000|0x020700|0x028000|0x0b4000) ;;
    *) continue ;;
  esac
  driver="$(pci_driver_name "${dev}")"
  numa="$(cat "${dev}/numa_node" 2>/dev/null || echo unknown)"
  group="$(iommu_group_name "${dev}")"
  device=""
  if cmd_exists lspci; then
    device="$(lspci -s "${pci}" 2>/dev/null | sed 's/^[^ ]* //')"
  fi
  printf '%-14s %-18s %-10s %-6s %-10s %s\n' "${pci}" "${class}" "${driver}" "${numa}" "${group}" "${device}"
done
