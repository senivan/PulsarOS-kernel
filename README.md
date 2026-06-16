# PulsarOS Kernel

Custom PulsarOS kernel packaging with DPDK runtime profiles.

`VERSION` is the default kernel version. Set `KVER=...` or pass a version argument
to override it where supported.

## Build

```bash
scripts/fetch-upstream.sh
scripts/update-spec.sh
INSTALL_RPMS=0 scripts/build-rpm.sh
```

Install the generated RPM on the target host.

## Runtime Profile

```bash
scripts/render-cmdline.sh profiles/dpdk-bench.env
sudo scripts/install-dpdk-profile.sh profiles/dpdk-bench.env
sudo reboot
```

Profiles:

- `profiles/dpdk-small.env`: conservative development profile.
- `profiles/dpdk-bench.env`: benchmark profile with low-latency flags.
- `profiles/dpdk-vm.env`: VM/SR-IOV guest profile.

## Runtime Helpers

```bash
scripts/dpdk-status.sh
sudo scripts/bind-vfio.sh 0000:01:00.0
sudo scripts/unbind-vfio.sh --driver ixgbe 0000:01:00.0
sudo scripts/set-irqs.sh profiles/dpdk-bench.env
sudo scripts/set-performance-governor.sh
```
