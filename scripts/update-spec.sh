#!/usr/bin/env bash
set -e
KVER=$1
SPECFILE=kernel.spec
sed -i "s/^Version:.*/Version:        ${KVER}/" $SPECFILE
CHECKSUM=$(sha256sum linux-${KVER}.tar.xz | cut -d' ' -f1)
sed -i "/Source0:/a # SHA256: ${CHECKSUM}" $SPECFILE
cat <<EOF >>$SPECFILE
* $(date '+%a %b %d %Y') PulsarOS Kernel Team <kernels@pulsaros.org> - ${KVER}-1
- Updated to Linux ${KVER}
EOF
