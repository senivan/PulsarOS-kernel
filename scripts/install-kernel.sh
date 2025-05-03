#!/usr/bin/env bash
set -e
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
echo "Rebooting into PulsarOS Kernel..."
sudo reboot
