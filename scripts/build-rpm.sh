#!/usr/bin/env bash
set -e
# rpmdev-setuptree        # does now work in Debian
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}         
cp linux-*.tar.xz ~/rpmbuild/SOURCES/
cp -r patches/* ~/rpmbuild/SOURCES/
cp  config/base.config ~/rpmbuild/SOURCES/
cp -r kernel.spec ~/rpmbuild/SPECS/
cd ~/rpmbuild/SPECS
rpmbuild -ba kernel.spec        
sudo dnf install -y ~/rpmbuild/RPMS/*/kernel-*.rpm
