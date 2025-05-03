Name:           linux
Version:        6.14.5
Release:        1.pulsaros%{?dist}
Summary:        PulsarOS custom Linux kernel

License:        GPLv2
URL:            https://www.kernel.org/
Source0:        https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-%{version}.tar.xz
Source1:        config/base.config
# SHA256: 28207ec52bbeaa3507010aeff944f442f7d9f22b286b79caf45ec6df1b24f409
# SHA256: 
# SHA256: 
%define local_defconfig %{_sourcedir}/config/base.config

%description
Custom bleeding-edge kernel for PulsarOS with DPDK/eBPF optimizations.

%prep
%autosetup -p1               
%build
mkdir -p ../build

cp %{local_defconfig} ../build/.config

make O=../build olddefconfig
make -j$(nproc) O=../build bzImage modules

%install
make O=../build INSTALL_MOD_PATH=%{buildroot} modules_install

install -m 644 ../build/arch/x86/boot/bzImage \
    %{buildroot}/boot/vmlinuz-%{version}-pulsaros
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
* Sat May 03 2025 PulsarOS Kernel Team <kernels@pulsaros.org> - 6.14.5-1
- Updated to Linux 6.14.5
