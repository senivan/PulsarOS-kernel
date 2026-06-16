#!/usr/bin/env bash

die() {
  echo "ERROR: $*" >&2
  exit 1
}

repo_root() {
  local source_dir
  source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  cd -- "${source_dir}/.." && pwd
}

read_kernel_version() {
  local root="${1:-$(repo_root)}"
  local version_file="${root}/VERSION"
  [[ -r "${version_file}" ]] || die "VERSION file not found at ${version_file}"
  local version
  version="$(sed -n '1{s/[[:space:]]//g;p;q}' "${version_file}")"
  [[ -n "${version}" ]] || die "VERSION is empty"
  printf '%s\n' "${version}"
}

load_profile() {
  local profile="$1"
  [[ -r "${profile}" ]] || die "profile not readable: ${profile}"
  # shellcheck disable=SC1090
  set -a
  source "${profile}"
  set +a
  require_profile_var DPDK_CORES
  require_profile_var HOUSEKEEPING_CORES
  require_profile_var HUGEPAGE_SIZE
  require_profile_var HUGEPAGES
  require_profile_var IOMMU_VENDOR
  require_profile_var LOW_LATENCY
}

require_profile_var() {
  local name="$1"
  [[ -n "${!name:-}" ]] || die "profile is missing required variable ${name}"
}

detect_iommu_vendor() {
  if grep -qi 'vendor_id[[:space:]]*:[[:space:]]*GenuineIntel' /proc/cpuinfo 2>/dev/null; then
    printf 'intel\n'
  elif grep -qi 'vendor_id[[:space:]]*:[[:space:]]*AuthenticAMD' /proc/cpuinfo 2>/dev/null; then
    printf 'amd\n'
  else
    printf 'none\n'
  fi
}

normalize_iommu_vendor() {
  local vendor="$1"
  case "${vendor}" in
    auto) detect_iommu_vendor ;;
    intel|amd|none) printf '%s\n' "${vendor}" ;;
    *) die "IOMMU_VENDOR must be one of: auto, intel, amd, none" ;;
  esac
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

need_root() {
  [[ ${EUID} -eq 0 ]] || die "this command must run as root"
}

pci_sysfs_path() {
  local pci="$1"
  [[ "${pci}" == *:*.* ]] || die "PCI address must look like 0000:01:00.0 or 01:00.0"
  if [[ "${pci}" != *:*:*.* ]]; then
    pci="0000:${pci}"
  fi
  printf '/sys/bus/pci/devices/%s\n' "${pci}"
}

pci_driver_name() {
  local dev="$1"
  if [[ -L "${dev}/driver" ]]; then
    basename "$(readlink -f "${dev}/driver")"
  else
    printf 'unbound\n'
  fi
}

iommu_group_name() {
  local dev="$1"
  if [[ -L "${dev}/iommu_group" ]]; then
    basename "$(readlink -f "${dev}/iommu_group")"
  else
    printf 'none\n'
  fi
}

driver_override_supported() {
  [[ -w "$1/driver_override" ]]
}

cpu_list_to_hex_mask() {
  local list="$1"
  local mask=0
  local part start end cpu
  IFS=',' read -ra parts <<< "${list}"
  for part in "${parts[@]}"; do
    if [[ "${part}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      start="${BASH_REMATCH[1]}"
      end="${BASH_REMATCH[2]}"
      [[ "${start}" -le "${end}" ]] || die "invalid CPU range: ${part}"
      for ((cpu=start; cpu<=end; cpu++)); do
        mask=$((mask | (1 << cpu)))
      done
    elif [[ "${part}" =~ ^[0-9]+$ ]]; then
      mask=$((mask | (1 << part)))
    else
      die "invalid CPU list element: ${part}"
    fi
  done
  printf '%x\n' "${mask}"
}
