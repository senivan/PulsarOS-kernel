#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dpdk-common.sh
source "${SCRIPT_DIR}/dpdk-common.sh"

usage() {
  echo "Usage: $0 [--driver DRIVER] PCI_ADDR [PCI_ADDR...]" >&2
}

target_driver=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --driver)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      target_driver="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      exit 2
      ;;
    *)
      break
      ;;
  esac
done
[[ $# -ge 1 ]] || { usage; exit 2; }
need_root

for pci in "$@"; do
  dev="$(pci_sysfs_path "${pci}")"
  [[ -e "${dev}" ]] || die "PCI device does not exist: ${pci}"
  if [[ "$(pci_driver_name "${dev}")" == "vfio-pci" ]]; then
    echo "$(basename "${dev}")" > "${dev}/driver/unbind"
  fi
  if driver_override_supported "${dev}"; then
    echo "${target_driver}" > "${dev}/driver_override"
  fi
  if [[ -n "${target_driver}" ]]; then
    modprobe "${target_driver}" || true
  fi
  echo "$(basename "${dev}")" > /sys/bus/pci/drivers_probe
  echo "${pci} driver: $(pci_driver_name "${dev}")"
done
