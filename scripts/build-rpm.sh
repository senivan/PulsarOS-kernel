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

# Preflight: ensure kernel.spec has a version set
if ! grep -q '^Version:[[:space:]]\+[0-9]' kernel.spec; then
  echo "ERROR: kernel.spec has no version set. Run update-spec.sh <kver> first."
  exit 1
fi

# rpmdev-setuptree        # does now work in Debian
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}         
cp kernel-*.tar.xz ~/rpmbuild/SOURCES/
mkdir -p ~/rpmbuild/SOURCES/config
cp -r patches/* ~/rpmbuild/SOURCES/
cp  config/base.config ~/rpmbuild/SOURCES/config
cp  config/base.config ~/rpmbuild/SOURCES
cp  config/01-cpu.config ~/rpmbuild/SOURCES/config
cp  config/02-memory.config ~/rpmbuild/SOURCES/config
cp  config/03-timers.config ~/rpmbuild/SOURCES/config
cp  config/04-fs.config ~/rpmbuild/SOURCES/config
cp  config/05-networking.config ~/rpmbuild/SOURCES/config
cp  config/06-io.config ~/rpmbuild/SOURCES/config
cp  config/07-numa.config ~/rpmbuild/SOURCES/config
cp  config/08-storage.config ~/rpmbuild/SOURCES/config
cp -r kernel.spec ~/rpmbuild/SPECS/
cd ~/rpmbuild/SPECS
rpmbuild -ba kernel.spec

shopt -s nullglob
rpms=(~/rpmbuild/RPMS/*/kernel-*.rpm)
if [[ ${#rpms[@]} -eq 0 ]]; then
  echo "ERROR: rpmbuild completed but no kernel RPMs were produced."
  exit 1
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
