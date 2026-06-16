#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<USAGE
Usage: $0 PROFILE.env [--kernel KERNEL_PATH]

Applies rendered DPDK kernel arguments to the installed PulsarOS kernel.
USAGE
}

profile=""
kernel_path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kernel)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      kernel_path="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      usage
      exit 2
      ;;
    *)
      [[ -z "${profile}" ]] || { usage; exit 2; }
      profile="$1"
      shift
      ;;
  esac
done
[[ -n "${profile}" ]] || { usage; exit 2; }

cmdline="$("${SCRIPT_DIR}/render-cmdline.sh" "${profile}")"
remove_keys=(
  isolcpus
  nohz_full
  rcu_nocbs
  irqaffinity
  default_hugepagesz
  hugepagesz
  hugepages
  intel_iommu
  amd_iommu
  iommu
  audit
  processor.max_cstate
)
remove_args="${remove_keys[*]}"

if command -v grubby >/dev/null 2>&1; then
  if [[ -z "${kernel_path}" ]]; then
    kernel_path="$(grubby --info=ALL 2>/dev/null | awk -F= '/^kernel=/{gsub(/^"|"$/, "", $2); if ($2 ~ /pulsaros/) {print $2; exit}}')"
  fi
  [[ -n "${kernel_path}" ]] || { echo "ERROR: could not find a PulsarOS kernel entry; pass --kernel /boot/vmlinuz-..." >&2; exit 1; }
  [[ -e "${kernel_path}" ]] || { echo "ERROR: kernel path does not exist: ${kernel_path}" >&2; exit 1; }
  grubby --update-kernel="${kernel_path}" --remove-args="${remove_args}" >/dev/null 2>&1 || true
  grubby --update-kernel="${kernel_path}" --args="${cmdline}"
  echo "Updated ${kernel_path}"
  echo "Final kernel command line:"
  grubby --info="${kernel_path}" | awk -F= '/^args=/{gsub(/^"|"$/, "", $2); print $2}'
  exit 0
fi

grub_default="/etc/default/grub"
[[ -w "${grub_default}" ]] || { echo "ERROR: grubby not found and ${grub_default} is not writable" >&2; exit 1; }
backup="${grub_default}.pulsaros-dpdk.$(date +%Y%m%d%H%M%S).bak"
cp -a "${grub_default}" "${backup}"

python3 - "$grub_default" "$cmdline" <<'PY'
import re
import shlex
import sys

path, rendered = sys.argv[1], sys.argv[2]
new_args = shlex.split(rendered)
keys = {arg.split("=", 1)[0] for arg in new_args}
with open(path, encoding="utf-8") as fh:
    data = fh.read()

pattern = re.compile(r'^(GRUB_CMDLINE_LINUX=)(["\'])(.*?)(\2)$', re.M)
match = pattern.search(data)
if match:
    existing = shlex.split(match.group(3))
    kept = [arg for arg in existing if arg.split("=", 1)[0] not in keys]
    merged = " ".join(shlex.quote(arg) for arg in kept + new_args)
    data = pattern.sub(lambda m: f'{m.group(1)}"{merged}"', data)
else:
    merged = " ".join(shlex.quote(arg) for arg in new_args)
    data += f'\nGRUB_CMDLINE_LINUX="{merged}"\n'

with open(path, "w", encoding="utf-8") as fh:
    fh.write(data)
PY

if command -v update-grub >/dev/null 2>&1; then
  update-grub
elif command -v grub-mkconfig >/dev/null 2>&1; then
  if [[ -d /boot/grub2 ]]; then
    grub-mkconfig -o /boot/grub2/grub.cfg
  else
    grub-mkconfig -o /boot/grub/grub.cfg
  fi
else
  echo "WARNING: no grub config generator found; run grub-mkconfig manually." >&2
fi

echo "Backed up ${grub_default} to ${backup}"
echo "Final kernel command line:"
echo "${cmdline}"
