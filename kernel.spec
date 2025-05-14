Name:           kernel
Version:        6.14.6
Release:        1.pulsaros%{?dist}
Summary:        PulsarOS custom Linux kernel

License:        GPLv2
URL:            https://www.kernel.org/
Source0:        kernel-%{version}.tar.xz
Source1:        config/base.config

# Definitions
%define debug_package %{nil}
%define local_defconfig %{_sourcedir}/config/base.config
%define builddir       %{_builddir}/linux-%{version}
%define krel           %{version}-pulsaros

%description
Custom bleeding-edge kernel for PulsarOS with DPDK/eBPF optimizations.

%prep
%autosetup -n linux-%{version} -p1

%build
# Standard out-of-tree build
mkdir -p %{_builddir}/build
cp %{local_defconfig} %{_builddir}/build/.config
make -C %{builddir} O=%{_builddir}/build olddefconfig
make -C %{builddir} O=%{_builddir}/build -j$(nproc) all

%install
# 1) Install modules into the buildroot
make -C %{builddir} \
     O=%{_builddir}/build \
     INSTALL_MOD_PATH=%{buildroot} \
     modules_install

# 2) Rename modules directory to match our krel
mv %{buildroot}/lib/modules/%{version} \
   %{buildroot}/lib/modules/%{krel}

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

# 5) Ensure dracut has a tempdir in the sysroot
mkdir -p %{buildroot}/var/tmp

# 6) Build the initramfs using host dracut, against buildroot
dracut \
  --kmoddir %{buildroot}/lib/modules/%{krel} \
  --tmpdir /var/tmp \
  --force --kver %{krel} \
  --filesystems ext4 \
  --add-drivers "virtio_net virtio_blk virtio_pci" \
  --add "base kernel-modules rootfs-block fs-lib" \
  --no-hostonly \
  --no-compress \
  --verbose \
  --no-early-microcode \
  --no-hostonly-cmdline \
  %{buildroot}/boot/initramfs-%{krel}.img
%post
ROOT_UUID=$(findmnt -n -o UUID /)
/sbin/grubby --add-kernel=/boot/vmlinuz-%{krel} \
             --initrd=/boot/initramfs-%{krel}.img \
             --title="PulsarOS Kernel %{version}" \
             --args="hugepagesz=2M default_hugepagesz=2M root=UUID=${ROOT_UUID} rootfstype=ext4 rootwait"

%files
/boot/vmlinuz-%{krel}
/boot/initramfs-%{krel}.img
/lib/modules/%{krel}
/etc/dracut.conf.d/90-minimal.conf
%exclude /root/rpmbuild/BUILD/linux-6.14.6

%changelog
* Tue May 13 2025 PulsarOS Kernel Team <kernels@pulsaros.org> - 6.14.6-1
- Full install‑time dracut build against buildroot  
