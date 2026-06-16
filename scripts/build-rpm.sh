#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command '$cmd' is not installed."
    exit 1
  fi
}

run_as_root() {
  if [[ ${EUID} -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    if sudo -n true >/dev/null 2>&1; then
      sudo -n "$@"
    else
      echo "ERROR: root privileges are required to install missing dependencies."
      echo "Run the script as root or install dependencies manually first."
      exit 1
    fi
  else
    echo "ERROR: '$1' requires root privileges (run as root or install sudo)."
    exit 1
  fi
}

ensure_build_deps() {
  local missing=()
  local cmd
  for cmd in rpmbuild make gcc bison flex dracut; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return
  fi

  echo "INFO: Installing missing build dependencies: ${missing[*]}"
  if command -v dnf >/dev/null 2>&1; then
    run_as_root dnf -y install \
      rpm-build gcc make bc bison flex dracut \
      elfutils-libelf-devel ncurses-devel openssl-devel dwarves
  elif command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
      rpm build-essential bc bison flex dracut \
      libelf-dev libncurses-dev libssl-dev dwarves
  else
    echo "ERROR: unsupported package manager; install rpmbuild make gcc bison flex dracut manually."
    exit 1
  fi

  for cmd in rpmbuild make gcc bison flex dracut; do
    require_cmd "$cmd"
  done
}

ensure_build_deps

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dpdk-common.sh
source "${SCRIPT_DIR}/dpdk-common.sh"
ROOT="$(repo_root)"
KVER="${KVER:-$(read_kernel_version "${ROOT}")}"

if ! grep -q "^Version:[[:space:]]*${KVER}$" "${ROOT}/kernel.spec"; then
  echo "ERROR: kernel.spec version does not match VERSION/KVER (${KVER})."
  echo "Run scripts/update-spec.sh ${KVER} first."
  exit 1
fi
[[ -r "${ROOT}/kernel-${KVER}.tar.xz" ]] || {
  echo "ERROR: missing ${ROOT}/kernel-${KVER}.tar.xz. Run scripts/fetch-upstream.sh ${KVER} first."
  exit 1
}

RPMBUILD_TOPDIR="${RPMBUILD_TOPDIR:-$HOME/rpmbuild}"
mkdir -p "${RPMBUILD_TOPDIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cp "${ROOT}/kernel-${KVER}.tar.xz" "${RPMBUILD_TOPDIR}/SOURCES/"
mkdir -p "${RPMBUILD_TOPDIR}/SOURCES/config"
mkdir -p "${RPMBUILD_TOPDIR}/SOURCES/scripts" "${RPMBUILD_TOPDIR}/SOURCES/profiles" "${RPMBUILD_TOPDIR}/SOURCES/systemd"
shopt -s nullglob
patch_files=("${ROOT}"/patches/*)
if [[ ${#patch_files[@]} -gt 0 ]]; then
  cp -r "${patch_files[@]}" "${RPMBUILD_TOPDIR}/SOURCES/"
fi
cp "${ROOT}"/config/*.config "${RPMBUILD_TOPDIR}/SOURCES/config"
cp "${ROOT}"/scripts/*.sh "${RPMBUILD_TOPDIR}/SOURCES/scripts"
cp "${ROOT}"/profiles/*.env "${RPMBUILD_TOPDIR}/SOURCES/profiles"
cp "${ROOT}"/systemd/*.service "${RPMBUILD_TOPDIR}/SOURCES/systemd"
cp -r "${ROOT}/kernel.spec" "${RPMBUILD_TOPDIR}/SPECS/"
cd "${RPMBUILD_TOPDIR}/SPECS"
rpmbuild --define "_topdir ${RPMBUILD_TOPDIR}" -ba kernel.spec

rpms=("${RPMBUILD_TOPDIR}"/RPMS/*/kernel-*.rpm)
if [[ ${#rpms[@]} -eq 0 ]]; then
  echo "ERROR: rpmbuild completed but no kernel RPMs were produced."
  exit 1
fi

if [[ "${INSTALL_RPMS:-1}" == "0" ]]; then
  echo "INFO: built RPMs successfully; skipping install because INSTALL_RPMS=0."
  printf 'Built RPMs:\n%s\n' "${rpms[@]}"
  exit 0
fi

if command -v dnf >/dev/null 2>&1; then
  if [[ ${EUID} -eq 0 ]]; then
    dnf reinstall -y "${rpms[@]}" || dnf install -y "${rpms[@]}"
  elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    sudo -n dnf reinstall -y "${rpms[@]}" || sudo -n dnf install -y "${rpms[@]}"
  else
    echo "INFO: built RPMs successfully; skipping install (requires root privileges)."
    printf 'Built RPMs:\n%s\n' "${rpms[@]}"
  fi
else
  echo "INFO: dnf not found; skipping local install."
  printf 'Built RPMs:\n%s\n' "${rpms[@]}"
fi
