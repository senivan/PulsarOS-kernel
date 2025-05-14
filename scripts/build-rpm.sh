#!/usr/bin/env bash
set -e
# rpmdev-setuptree        # does now work in Debian
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}         
cp kernel-*.tar.xz ~/rpmbuild/SOURCES/
mkdir -p ~/rpmbuild/SOURCES/config
cp -r patches/* ~/rpmbuild/SOURCES/
cp -r dracut/ ~/rpmbuild/SOURCES/
cp  config/base.config ~/rpmbuild/SOURCES/config
cp  config/base.config ~/rpmbuild/SOURCES
cp -r kernel.spec ~/rpmbuild/SPECS/
cd ~/rpmbuild/SPECS
rpmbuild -ba kernel.spec        
dnf reinstall -y ~/rpmbuild/RPMS/*/kernel-*.rpm \
  || dnf install -y ~/rpmbuild/RPMS/*/kernel-*.rpm