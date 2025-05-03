# Pulsar OS kernel repo

This repo contains kernel.spec, configs and patches optimized for usage in Pulsar OS

It is assumed that fedora server is used as base os.
To use this kernel run the next sequence of scripts:
1. Run `fetch-upstream.sh` to fetch the latest 6.x linux kernel
2. Run `update-spec.sh` to bump the version and update checksums for sources
3. Run `build-rpm.sh` to build and install RPMs
4. Run `install-kernel.sh` to regenerate GRUB config and reboot
