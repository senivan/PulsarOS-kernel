#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dpdk-common.sh
source "${SCRIPT_DIR}/dpdk-common.sh"

ROOT="$(repo_root)"
KVER="${1:-${KVER:-$(read_kernel_version "${ROOT}")}}"
SPECFILE="${ROOT}/kernel.spec"
TARBALL="${ROOT}/kernel-${KVER}.tar.xz"

sed -i "s/^Version:.*/Version:        ${KVER}/" "${SPECFILE}"

if [[ -r "${TARBALL}" ]]; then
  CHECKSUM="$(sha256sum "${TARBALL}" | cut -d' ' -f1)"
  sed -i '/^# SHA256:/d' "${SPECFILE}"
  sed -i "/^Source0:/a # SHA256: ${CHECKSUM}" "${SPECFILE}"
else
  echo "WARNING: ${TARBALL} not found; leaving checksum comments unchanged." >&2
fi

if ! grep -q -- "- ${KVER}-1$" "${SPECFILE}"; then
  cat <<EOF >>"${SPECFILE}"
* $(date '+%a %b %d %Y') PulsarOS Kernel Team <kernels@pulsaros.org> - ${KVER}-1
- Updated to Linux ${KVER}
EOF
fi
