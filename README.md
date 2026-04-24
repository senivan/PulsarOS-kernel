# Pulsar OS kernel repo

This repo contains kernel.spec, configs and patches optimized for usage in Pulsar OS
This kernel config is optimized for use with [DPDK](https://dpdk.org)

It is assumed that Debian 12 Bookworm is used as base os.
To use this kernel run the next sequence of scripts:
1. Run `fetch-upstream.sh` to fetch the latest 6.x linux kernel
2. Run `update-spec.sh` to bump the version and update checksums for sources
3. Run `build-rpm.sh` to build and install RPMs or run `build-make.sh` to build in more conventional way. Build scripts are made for RHEL systems.
## Known issues
1. `scripts/build-rpm.sh` needs root privileges (or passwordless sudo) when required build dependencies are missing.
