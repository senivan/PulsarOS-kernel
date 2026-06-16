#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dpdk-common.sh
source "${SCRIPT_DIR}/dpdk-common.sh"

[[ $# -ge 1 ]] || die "Usage: $0 PCI_ADDR [PCI_ADDR...]"
need_root
modprobe vfio-pci

for pci in "$@"; do
  dev="$(pci_sysfs_path "${pci}")"
  [[ -e "${dev}" ]] || die "PCI device does not exist: ${pci}"
  group_path="$(readlink -f "${dev}/iommu_group" 2>/dev/null || true)"
  [[ -n "${group_path}" && -d "${group_path}" ]] || die "${pci} has no IOMMU group"
  for peer in "${group_path}"/devices/*; do
    [[ -e "${peer}" ]] || continue
    if [[ "$(basename "${peer}")" != "$(basename "${dev}")" ]]; then
      peer_driver="$(pci_driver_name "${peer}")"
      [[ "${peer_driver}" == "vfio-pci" || "${peer_driver}" == "unbound" ]] || die "${pci} shares IOMMU group $(basename "${group_path}") with $(basename "${peer}") bound to ${peer_driver}"
    fi
  done
  vendor="$(cat "${dev}/vendor")"
  device="$(cat "${dev}/device")"
  current="$(pci_driver_name "${dev}")"
  if [[ "${current}" == "vfio-pci" ]]; then
    echo "${pci} is already bound to vfio-pci"
    continue
  fi
  if driver_override_supported "${dev}"; then
    echo vfio-pci > "${dev}/driver_override"
  else
    echo "${vendor} ${device}" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
  fi
  if [[ -L "${dev}/driver" ]]; then
    echo "$(basename "${dev}")" > "${dev}/driver/unbind"
  fi
  echo "$(basename "${dev}")" > /sys/bus/pci/drivers_probe
  [[ "$(pci_driver_name "${dev}")" == "vfio-pci" ]] || die "failed to bind ${pci} to vfio-pci"
  echo "${pci} bound to vfio-pci"
done
