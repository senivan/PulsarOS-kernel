#!/usr/bin/env bash
set -e
rpmdev-setuptree                 
cp linux-*.tar.xz ~/rpmbuild/SOURCES/
cp -r patches config kernel.spec ~/rpmbuild/SPECS/
cd ~/rpmbuild/SPECS
rpmbuild -ba kernel.spec        
sudo dnf install -y ~/rpmbuild/RPMS/*/kernel-*.rpm
