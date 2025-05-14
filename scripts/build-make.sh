#!/usr/bin/env bash
set -euo pipefail

dnf -y groupinstall "Development Tools"
dnf -y install bc bison flex elfutils-libelf-devel \
               ncurses-devel openssl-devel pesign rpmdevtools \
               dwarves

TOTAL_CPUS=$(nproc --all)                                           
ISOL_CPUS="2-$((TOTAL_CPUS - 1))"                                    
OS_CORES_LIST="0-1"                                                  
echo "DPDK will use cores: ${ISOL_CPUS}; OS/IRQ cores: ${OS_CORES_LIST}"

SOURCE_DIR="/root/Kernel/linux-6.14.6"
BUILD_DIR="/root/build/kernel"
BASE_CONFIG="/boot/config-5.14.0-503.40.1.el9_5.x86_64"

rm -rf "$SOURCE_DIR"
tar xf /root/Kernel/linux-6.*.tar.xz -C /root/Kernel/
cd "$SOURCE_DIR"
sed -i 's/^EXTRAVERSION.*/EXTRAVERSION = -pulsaros/' Makefile        
make mrproper                                                       

mkdir -p "$BUILD_DIR"
cp "$BASE_CONFIG" "$BUILD_DIR/.config"
cd "$BUILD_DIR"
KCONFIG_CONFIG="$BUILD_DIR/.config" \
  bash "$SOURCE_DIR/scripts/kconfig/merge_config.sh" -m \
    "$BUILD_DIR/.config" \
    /root/Kernel/config/01-cpu.config \
    /root/Kernel/config/02-memory.config \
    /root/Kernel/config/03-timers.config \
    /root/Kernel/config/04-fs.config \
    /root/Kernel/config/05-networking.config \
    /root/Kernel/config/06-io.config \
    /root/Kernel/config/07-numa.config \
    /root/Kernel/config/08-storage.config \

KCONFIG_CONFIG="$BUILD_DIR/.config" \
  make -C "$SOURCE_DIR" O="$BUILD_DIR" olddefconfig                  
sed -ri '/CONFIG_SYSTEM_TRUSTED_KEYS/s/=.+/=""/g' "$BUILD_DIR/.config"
KCONFIG_CONFIG="$BUILD_DIR/.config" \
  make -C "$SOURCE_DIR" O="$BUILD_DIR" -j"$(nproc)"
KCONFIG_CONFIG="$BUILD_DIR/.config" \
  make -C "$SOURCE_DIR" O="$BUILD_DIR" modules_install

cp -v "$BUILD_DIR"/arch/x86/boot/bzImage /boot/vmlinuz-6.14.6-pulsaros
cp -v "$BUILD_DIR"/System.map /boot/System.map-6.14.6-pulsaros
echo "Starting kernel installation..."
dracut --force --kver 6.14.6-pulsaros \
       --tmpdir /root/dracut-tmp \
       --lzma \
       --strip \
       --aggresive-strip \
       --hostonly \
       --add " dm lvm " \
       --kernel-cmdline " rootfstype=ext4 rootwait audit=1 rd.auto rd.lvm=1 rd.lvm.vg=rl root=/dev/mapper/rl-root ro " \
       /boot/initramfs-6.14.6-pulsaros.img

GRUB_CFG="/etc/default/grub"
cp "${GRUB_CFG}" "${GRUB_CFG}.dpdkbak"
if grep -q "isolcpus=" "${GRUB_CFG}"; then
  sed -ri "s/isolcpus=[^ ]*/isolcpus=${ISOL_CPUS}/" "${GRUB_CFG}"
else
  sed -ri "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"isolcpus=${ISOL_CPUS} /" "${GRUB_CFG}"
fi
if grep -q "nohz_full=" "${GRUB_CFG}"; then
  sed -ri "s/nohz_full=[^ ]*/nohz_full=${ISOL_CPUS}/" "${GRUB_CFG}"
else
  sed -ri "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"nohz_full=${ISOL_CPUS} /" "${GRUB_CFG}"
fi
grub2-mkconfig -o /boot/grub2/grub.cfg
echo "Updated GRUB with isolcpus=${ISOL_CPUS} and nohz_full=${ISOL_CPUS}; reboot to apply."

cp -v "${BUILD_DIR}"/.config /root/kernel-config-6.14.6-pulsaros
echo "Kernel config saved to /root/kernel-config-6.14.6-pulsaros"

IRQ_DEC=0
IFS=',' read -ra PARTS <<< "$OS_CORES_LIST"
for part in "${PARTS[@]}"; do
  if [[ $part =~ ^([0-9]+)-([0-9]+)$ ]]; then
    start=${BASH_REMATCH[1]}; end=${BASH_REMATCH[2]}
    for ((cpu=start; cpu<=end; cpu++)); do
      IRQ_DEC=$(( IRQ_DEC | (1 << cpu) ))
    done
  else
    IRQ_DEC=$(( IRQ_DEC | (1 << part) ))
  fi
done

# 2) Determine how many hex digits we need (4 bits per digit)
MAX_CPU=$(( ${PARTS[-1]/*-/} + 1 ))          # approximate highest CPU +1
HEX_DIGITS=$(( (MAX_CPU + 3) / 4 ))         # ceil division
IRQ_HEX=$(printf "%0${HEX_DIGITS}x" "$IRQ_DEC")

echo "Setting default IRQ affinity mask to 0x${IRQ_HEX} for cores ${OS_CORES_LIST}"

# 3) Write to default affinity
if [ -w /proc/irq/default_smp_affinity ]; then
  echo "${IRQ_HEX}" > /proc/irq/default_smp_affinity
else
  echo "Warning: cannot write default_smp_affinity"
fi

# 4) Iterate each numbered IRQ
for irq_dir in /proc/irq/[0-9]*; do
  # pick the “list” interface if present
  for f in smp_affinity_list smp_affinity; do
    AFF_FILE="$irq_dir/$f"
    if [ -w "$AFF_FILE" ]; then
      echo "${IRQ_HEX}" > "$AFF_FILE" || \
        echo "Failed to write $AFF_FILE"
      break
    fi
  done
done

echo "IRQ affinity pinned to CPU mask 0x${IRQ_HEX} (cores ${OS_CORES_LIST})"
echo "Build, CPU isolation, and IRQ affinity setup complete. Please reboot."