#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dpdk-common.sh
source "${SCRIPT_DIR}/dpdk-common.sh"

KVER="${1:-${KVER:-$(read_kernel_version "$(repo_root)")}}"
depmod -a "${KVER}-pulsaros"
dracut --kver "${KVER}-pulsaros" --force
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
echo "Rebooting into PulsarOS Kernel..."
sudo reboot
