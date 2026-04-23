#!/usr/bin/env bash
set -e

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
dnf reinstall -y ~/rpmbuild/RPMS/*/kernel-*.rpm \
  || dnf install -y ~/rpmbuild/RPMS/*/kernel-*.rpm