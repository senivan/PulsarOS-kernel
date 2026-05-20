#!/usr/bin/env bash
set -euo pipefail

KVER="${1:-${KVER:-7.0.9}}"
KMAJOR="${KVER%%.*}"

curl -L \
     "https://cdn.kernel.org/pub/linux/kernel/v${KMAJOR}.x/linux-${KVER}.tar.xz" \
     -o "kernel-${KVER}.tar.xz"
echo "$KVER"
