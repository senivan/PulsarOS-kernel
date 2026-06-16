#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dpdk-common.sh
source "${SCRIPT_DIR}/dpdk-common.sh"

KVER="${1:-${KVER:-$(read_kernel_version "$(repo_root)")}}"
KMAJOR="${KVER%%.*}"

curl -L \
     "https://cdn.kernel.org/pub/linux/kernel/v${KMAJOR}.x/linux-${KVER}.tar.xz" \
     -o "kernel-${KVER}.tar.xz"
echo "$KVER"
