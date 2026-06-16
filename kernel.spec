Name:           kernel
Version:        7.0.9
Release:        1.pulsaros%{?dist}
Summary:        PulsarOS custom Linux kernel

License:        GPLv2
URL:            https://www.kernel.org/
Source0:        kernel-%{version}.tar.xz
Source1:        config/base.config

# Definitions
%{!?_unitdir:%global _unitdir /usr/lib/systemd/system}
%define debug_package %{nil}
%define local_defconfig %{_sourcedir}/config/base.config
%define krel           %{version}-pulsaros
%define helperdir      %{_libexecdir}/pulsaros-kernel

%description
Custom bleeding-edge kernel for PulsarOS with DPDK/eBPF optimizations.
Runtime DPDK behavior is selected through explicit host profiles after install.

%prep
%autosetup -n linux-%{version} -p1

%build
# Standard out-of-tree build
mkdir -p %{_builddir}/build
cp %{local_defconfig} %{_builddir}/build/.config
# Merge per-subsystem overlay configs (DPDK/RT optimizations)
for overlay in \
    %{_sourcedir}/config/01-cpu.config \
    %{_sourcedir}/config/02-memory.config \
    %{_sourcedir}/config/03-timers.config \
    %{_sourcedir}/config/04-fs.config \
    %{_sourcedir}/config/05-networking.config \
    %{_sourcedir}/config/06-io.config \
    %{_sourcedir}/config/07-numa.config \
    %{_sourcedir}/config/08-storage.config \
    %{_sourcedir}/config/09-userspace.config; do
  cat "$overlay" >> %{_builddir}/build/.config
done
make O=%{_builddir}/build olddefconfig
make O=%{_builddir}/build -j$(nproc) all

%install
# 1) Install modules into the buildroot
make O=%{_builddir}/build \
    INSTALL_MOD_PATH=%{buildroot} \
    modules_install

# 2) Rename modules directory to match our krel
moddir="$(find %{buildroot}/lib/modules -mindepth 1 -maxdepth 1 -type d | head -n1)"
if [ -z "${moddir}" ]; then
  echo "ERROR: modules_install did not produce a module directory under %{buildroot}/lib/modules"
  exit 1
fi
if [ "${moddir##*/}" != "%{krel}" ]; then
  mv "${moddir}" "%{buildroot}/lib/modules/%{krel}"
fi

# 3) Stage minimal dracut snippet (drop‑in)
install -d %{buildroot}/etc/dracut.conf.d
cat > %{buildroot}/etc/dracut.conf.d/90-minimal.conf << 'EOF'
# Minimal dracut config for PulsarOS kernel
hostonly="no"
install_items+=" /sbin/e2fsck /sbin/fsck.ext4 /etc/fstab "
EOF

# 4) Install the kernel image
install -d %{buildroot}/boot
install -m 644 \
  %{_builddir}/build/arch/x86/boot/bzImage \
  %{buildroot}/boot/vmlinuz-%{krel}
install -m 644 \
  %{_builddir}/build/.config \
  %{buildroot}/boot/config-%{krel}

# 5) Install DPDK runtime profiles and helper scripts
install -d %{buildroot}%{_datadir}/pulsaros-kernel/profiles
install -m 644 %{_sourcedir}/profiles/*.env %{buildroot}%{_datadir}/pulsaros-kernel/profiles/
install -d %{buildroot}%{helperdir}
install -m 755 %{_sourcedir}/scripts/dpdk-common.sh %{buildroot}%{helperdir}/
install -m 755 %{_sourcedir}/scripts/render-cmdline.sh %{buildroot}%{helperdir}/
install -m 755 %{_sourcedir}/scripts/install-dpdk-profile.sh %{buildroot}%{helperdir}/
install -m 755 %{_sourcedir}/scripts/dpdk-status.sh %{buildroot}%{helperdir}/
install -m 755 %{_sourcedir}/scripts/bind-vfio.sh %{buildroot}%{helperdir}/
install -m 755 %{_sourcedir}/scripts/unbind-vfio.sh %{buildroot}%{helperdir}/
install -m 755 %{_sourcedir}/scripts/set-irqs.sh %{buildroot}%{helperdir}/
install -m 755 %{_sourcedir}/scripts/set-performance-governor.sh %{buildroot}%{helperdir}/
install -d %{buildroot}%{_unitdir}
install -m 644 %{_sourcedir}/systemd/*.service %{buildroot}%{_unitdir}/
install -d %{buildroot}%{_sysconfdir}/pulsaros-kernel

# 6) Ensure dracut has a tempdir in the sysroot
mkdir -p %{buildroot}/var/tmp

# 7) Build the initramfs using host dracut, against buildroot
depmod -b %{buildroot} %{krel}
dracut_kmoddir="/var/tmp/pulsaros-kmods-%{krel}"
dracut_img="/var/tmp/initramfs-%{krel}.img"
rm -f "${dracut_kmoddir}" "${dracut_img}"
ln -s "%{buildroot}/lib/modules/%{krel}" "${dracut_kmoddir}"
DRACUT_KMODDIR_OVERRIDE=1 dracut \
  --kmoddir "${dracut_kmoddir}" \
  --tmpdir /var/tmp \
  --force --kver %{krel} \
  --modules "base kernel-modules rootfs-block fs-lib lvm" \
  --no-hostonly \
  --no-compress \
  --no-early-microcode \
  --no-hostonly-cmdline \
  "${dracut_img}"
install -m 644 "${dracut_img}" %{buildroot}/boot/initramfs-%{krel}.img
rm -f "${dracut_img}" "${dracut_kmoddir}"

%post
ROOT_UUID=$(findmnt -n -o UUID /)
if command -v grubby >/dev/null 2>&1; then
  /sbin/grubby --add-kernel=/boot/vmlinuz-%{krel} \
               --initrd=/boot/initramfs-%{krel}.img \
               --title="PulsarOS Kernel %{version}" \
               --args="root=UUID=${ROOT_UUID} rootfstype=ext4 rootwait"
else
  echo "WARNING: grubby not found; add /boot/vmlinuz-%{krel} to the bootloader manually."
fi
cat <<'EOF'
PulsarOS kernel installed.
Apply an explicit DPDK runtime profile after install, for example:
  /usr/libexec/pulsaros-kernel/install-dpdk-profile.sh /usr/share/pulsaros-kernel/profiles/dpdk-bench.env
EOF

%files
/boot/vmlinuz-%{krel}
/boot/config-%{krel}
/boot/initramfs-%{krel}.img
/lib/modules/%{krel}
/etc/dracut.conf.d/90-minimal.conf
%dir %{_sysconfdir}/pulsaros-kernel
%{_datadir}/pulsaros-kernel/profiles/*.env
%{helperdir}/*.sh
%{_unitdir}/pulsaros-dpdk-host.service
%{_unitdir}/pulsaros-vfio-bind@.service

%changelog
* Tue Jun 16 2026 PulsarOS Kernel Team <kernels@pulsaros.org> - 7.0.9-1
- Add explicit DPDK runtime profiles and host helper tooling
* Fri Apr 24 2026 PulsarOS Kernel Team <kernels@pulsaros.org> - 6.16-1
- Updated to Linux 6.16
* Sun Aug 03 2025 PulsarOS Kernel Team <kernels@pulsaros.org> - -1
- Updated to Linux 
* Sat May 31 2025 PulsarOS Kernel Team <kernels@pulsaros.org> - 6.15-1
- Updated to Linux 6.15
* Sat May 31 2025 PulsarOS Kernel Team <kernels@pulsaros.org> - -1
- Updated to Linux 
* Tue May 13 2025 PulsarOS Kernel Team <kernels@pulsaros.org> - 6.14.6-1
- Full install‑time dracut build against buildroot
