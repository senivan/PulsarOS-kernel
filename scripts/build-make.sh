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

rm -rf "$SOURCE_DIR"
tar xf /root/Kernel/linux-6.*.tar.xz -C /root/Kernel/
cd "$SOURCE_DIR"
sed -i 's/^EXTRAVERSION.*/EXTRAVERSION = -pulsaros/' Makefile        
make mrproper                                                       

mkdir -p "$BUILD_DIR"
cp /boot/config-$(uname -r) "$BUILD_DIR/.config"
cd "$BUILD_DIR"
KCONFIG_CONFIG="$BUILD_DIR/.config" \
  bash "$SOURCE_DIR/scripts/kconfig/merge_config.sh" -m \
    "$BUILD_DIR/.config" /root/Kernel/config/base.config             

KCONFIG_CONFIG="$BUILD_DIR/.config" \
  make -C "$SOURCE_DIR" O="$BUILD_DIR" olddefconfig                  
sed -ri '/CONFIG_SYSTEM_TRUSTED_KEYS/s/=.+/=""/g' "$BUILD_DIR/.config"
KCONFIG_CONFIG="$BUILD_DIR/.config" \
  make -C "$SOURCE_DIR" O="$BUILD_DIR" -j"$(nproc)"
KCONFIG_CONFIG="$BUILD_DIR/.config" \
  make -C "$SOURCE_DIR" O="$BUILD_DIR" modules_install

cp "$BUILD_DIR"/arch/x86/boot/bzImage /boot/vmlinuz-6.14.6-pulsaros
cp -v "$BUILD_DIR"/System.map /boot/System.map-6.14.6-pulsaros
kernel-install add 6.14.6-pulsaros /boot/vmlinuz-6.14.6-pulsaros

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


IRQ_DEC=$(( (1<<0) | (1<<1) ))                                      
IRQ_HEX=$(printf '%x' "$IRQ_DEC")
echo "Setting default IRQ affinity mask to 0x${IRQ_HEX} for cores ${OS_CORES_LIST}"
echo "${IRQ_HEX}" > /proc/irq/default_smp_affinity                  
for irq_dir in /proc/irq/[0-9]*; do
  echo "${IRQ_HEX}" > "${irq_dir}/smp_affinity"                    
done
echo "IRQ affinity pinned to CPU mask 0x${IRQ_HEX} (cores ${OS_CORES_LIST})"

echo "Build, CPU isolation, and IRQ affinity setup complete. Please reboot."
