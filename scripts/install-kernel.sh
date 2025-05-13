#!/usr/bin/env bash
KVER=$1
set -e
depmod -a "${KVER}-pulsaros"
dracut --kver ${KVER}-pulsaros --force
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
echo "Rebooting into PulsarOS Kernel..."
sudo reboot
