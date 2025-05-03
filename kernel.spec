Name:           kernel
Version:        %{kernel_version}      # set by update-spec.sh
Release:        1.pulsaros%{?dist}
Summary:        PulsarOS custom Linux kernel

License:        GPLv2
URL:            https://www.kernel.org/
Source0:        https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-%{version}.tar.xz
Patch0:         patches/fix-dpdk-bind.patch
%define local_defconfig config/base.config

%description
Custom bleeding-edge kernel for PulsarOS with DPDK/eBPF optimizations.

%prep
%autosetup -p1               

%build
export KBUILD_OUTPUT=$(pwd)/build
cp %{local_defconfig} build/.config
# Overlay fragments
for frag in config/conf.d/*.config; do
  scripts/kconfig/merge_config.sh build/.config $frag
done
make -C build olddefconfig
make -C build -j$(nproc) bzImage modules

%install
make -C build INSTALL_MOD_PATH=%{buildroot} modules_install
install -m 644 build/arch/x86/boot/bzImage %{buildroot}/boot/vmlinuz-%{version}-pulsaros

%post
/sbin/dracut --regenerate-cmdline --force   

%posttrans
/sbin/grubby --add-kernel=/boot/vmlinuz-%{version}-pulsaros \
             --title="PulsarOS Kernel %{version}" \
             --args="hugepagesz=2M default_hugepagesz=2M"

%files
/boot/vmlinuz-%{version}-pulsaros
/boot/initramfs-*-%{version}-pulsaros.img
/lib/modules/%{version}-pulsaros

%changelog   # filled by update-spec.sh
