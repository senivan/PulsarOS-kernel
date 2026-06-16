#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dpdk-common.sh
source "${SCRIPT_DIR}/dpdk-common.sh"

ROOT="$(repo_root)"
KVER="${KVER:-$(read_kernel_version "${ROOT}")}"
SOURCE_ARCHIVE="${SOURCE_ARCHIVE:-${ROOT}/kernel-${KVER}.tar.xz}"
WORK_DIR="${WORK_DIR:-${ROOT}/.build/make}"
SOURCE_DIR="${SOURCE_DIR:-${WORK_DIR}/linux-${KVER}}"
BUILD_DIR="${BUILD_DIR:-${WORK_DIR}/build-${KVER}}"
JOBS="${JOBS:-$(nproc)}"

[[ -r "${SOURCE_ARCHIVE}" ]] || die "missing ${SOURCE_ARCHIVE}; run scripts/fetch-upstream.sh ${KVER}"

rm -rf "${SOURCE_DIR}"
mkdir -p "${WORK_DIR}" "${BUILD_DIR}"
tar xf "${SOURCE_ARCHIVE}" -C "${WORK_DIR}"

sed -i 's/^EXTRAVERSION.*/EXTRAVERSION = -pulsaros/' "${SOURCE_DIR}/Makefile"
make -C "${SOURCE_DIR}" O="${BUILD_DIR}" mrproper
cp "${ROOT}/config/base.config" "${BUILD_DIR}/.config"

KCONFIG_CONFIG="${BUILD_DIR}/.config" \
  bash "${SOURCE_DIR}/scripts/kconfig/merge_config.sh" -m \
    "${BUILD_DIR}/.config" \
    "${ROOT}/config/01-cpu.config" \
    "${ROOT}/config/02-memory.config" \
    "${ROOT}/config/03-timers.config" \
    "${ROOT}/config/04-fs.config" \
    "${ROOT}/config/05-networking.config" \
    "${ROOT}/config/06-io.config" \
    "${ROOT}/config/07-numa.config" \
    "${ROOT}/config/08-storage.config" \
    "${ROOT}/config/09-userspace.config"

KCONFIG_CONFIG="${BUILD_DIR}/.config" make -C "${SOURCE_DIR}" O="${BUILD_DIR}" olddefconfig
sed -ri '/CONFIG_SYSTEM_TRUSTED_KEYS/s/=.+/=""/g' "${BUILD_DIR}/.config"
KCONFIG_CONFIG="${BUILD_DIR}/.config" make -C "${SOURCE_DIR}" O="${BUILD_DIR}" -j "${JOBS}"

echo "Local make build complete:"
echo "  Kernel image: ${BUILD_DIR}/arch/x86/boot/bzImage"
echo "  Config:       ${BUILD_DIR}/.config"
echo
echo "Runtime setup is separate from compilation. Use:"
echo "  scripts/install-dpdk-profile.sh profiles/dpdk-bench.env"
echo "  scripts/set-irqs.sh profiles/dpdk-bench.env"
