Name:           kernel
Version:        6.14.6
Release:        1.pulsaros%{?dist}
Summary:        PulsarOS custom Linux kernel

License:        GPLv2
URL:            https://www.kernel.org/
Source0:        kernel-%{version}.tar.xz
Source1:        config/base.config

%define local_defconfig %{_sourcedir}/config/base.config
%define _debugsource_template %{nil}
%define builddir %{_builddir}/linux-%{version}
%define krel %{version}-pulsaros

%description
Custom bleeding-edge kernel for PulsarOS with DPDK/eBPF optimizations.

%prep
%autosetup -n linux-%{version} -p1

%build
mkdir -p %{_builddir}/build
cp %{local_defconfig} %{_builddir}/build/.config
make -C %{builddir} O=%{_builddir}/build olddefconfig
make -C %{builddir} O=%{_builddir}/build -j$(nproc) all

%install
# 1) Install modules into buildroot
make -C %{builddir} \
     O=%{_builddir}/build \
     INSTALL_MOD_PATH=%{buildroot} \
     modules_install

# 2) Stage dracut snippet for virtio _before_ initramfs build
install -d %{buildroot}/etc/dracut.conf.d
install -m 644 %{_sourcedir}/dracut/virtio.conf \
              %{buildroot}/etc/dracut.conf.d/virtio.conf

# 3) Install the kernel image
install -d %{buildroot}/boot
install -m 644 %{_builddir}/build/arch/x86/boot/bzImage \
              %{buildroot}/boot/vmlinuz-%{krel}

# 4) Rename modules directory to match krel
mv %{buildroot}/lib/modules/%{version} \
   %{buildroot}/lib/modules/%{krel}

# 5) Build initramfs **inside** the buildroot
pushd %{buildroot} >/dev/null
  # Debug output
  echo "Available modules in %{buildroot}/lib/modules/%{krel}:"
  find lib/modules/%{krel} -name "*.ko*" | grep -E '(virtio|ext)' || true
  
  # Create directories
  mkdir -p var/tmp boot
  
  # Create minimal dracut configs
  mkdir -p etc/dracut.conf.d/
  cat > etc/dracut.conf.d/90-minimal.conf << EOF
hostonly="no"
filesystems="ext4"
omit_drivers+=" ext4 "
add_drivers+=" virtio_pci virtio_net "
install_items+=" /sbin/e2fsck /sbin/fsck.ext4 /etc/fstab "
EOF

  # IMPORTANT: Create empty file first as fallback
  touch boot/initramfs-%{krel}.img
  
  # Run dracut with RELATIVE path (no leading slash)
  dracut --force --kver %{krel} \
         --add "base kernel-modules rootfs-block fs-lib" \
         --tmpdir var/tmp \
         --no-hostonly \
         --no-compress \
         --verbose \
         --no-early-microcode \
         --no-hostonly-cmdline \
         boot/initramfs-%{krel}.img
popd >/dev/null

%post
ROOT_UUID=$(findmnt -n -o UUID /)
/sbin/grubby --add-kernel=/boot/vmlinuz-%{krel} \
             --title="PulsarOS Kernel %{version}" \
             --args="hugepagesz=2M default_hugepagesz=2M root=UUID=${ROOT_UUID} rootfstype=ext4 rootwait"
%files
/boot/vmlinuz-%{krel}
/boot/initramfs-%{krel}.img
/lib/modules/%{krel}
/etc/dracut.conf.d/90-minimal.conf
/etc/dracut.conf.d/virtio.conf

%changelog
* Tue May 13 2025 PulsarOS Kernel Team <kernels@pulsaros.org> - 6.14.6-1
- Stage virtio.conf before dracut runs  
