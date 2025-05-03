#!/usr/bin/env bash
set -euo pipefail
KVER=$(curl -s https://www.kernel.org/releases.json | jq -r '.latest_stable.version')
curl -LO https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KVER}.tar.xz
echo "$KVER"
